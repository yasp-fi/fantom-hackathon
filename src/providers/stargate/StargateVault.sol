// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC4626, ERC20, IERC20 as ZeppelinERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "forge-std/interfaces/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./external/IStargateLPStaking.sol";
import "./external/IStargateRouter.sol";
import "./external/IStargatePool.sol";
import "../../periphery/FeesController.sol";
import {ISwapper} from "../../Swapper.sol";

contract StargateVault is ERC4626, Ownable, Pausable {
    /// -----------------------------------------------------------------------
    /// Params
    /// -----------------------------------------------------------------------

    /// @notice want asset
    IERC20 public want;
    /// @notice The stargate bridge router contract
    IStargateRouter public stargateRouter;
    /// @notice The stargate bridge router contract
    IStargatePool public stargatePool;
    /// @notice The stargate lp staking contract
    IStargateLPStaking public stargateLPStaking;
    /// @notice The stargate pool staking id
    uint256 public poolStakingId;
    /// @notice The stargate lp asset
    IERC20 public lpToken;
    /// @notice The stargate expected reward token (prob. STG or OP)
    IERC20 public reward;
    /// @notice Swapper contract
    ISwapper public swapper;
    /// @notice someone who can harvest/tend in that vault
    address public keeper;
    /// @notice fees controller
    FeesController public feesController;

    event Harvest(address indexed executor, uint256 amountReward, uint256 amountWant);
    event Tend(address indexed executor, uint256 amountWant, uint256 amountShares);
    event KeeperUpdated(address newKeeper);
    event SwapperUpdated(address newSwapper);
    event FeesControllerUpdated(address feesController);

    modifier onlyKeeper() {
        require(msg.sender == keeper, "Only keeper can call that function");
        _;
    }

    /// -----------------------------------------------------------------------
    /// Initialize
    /// -----------------------------------------------------------------------

    constructor(
        IERC20 asset_,
        IStargatePool pool_,
        IStargateRouter router_,
        IStargateLPStaking staking_,
        uint256 poolStakingId_,
        IERC20 lpToken_,
        IERC20 reward_,
        ISwapper swapper_,
        FeesController feesController_,
        address admin
    ) ERC20(_vaultName(asset_), _vaultSymbol(asset_)) ERC4626(ZeppelinERC20(address(asset_))) Ownable() Pausable() {
        want = asset_;
        stargatePool = pool_;
        stargateRouter = router_;
        stargateLPStaking = staking_;
        poolStakingId = poolStakingId_;
        lpToken = lpToken_;
        reward = reward_;
        swapper = swapper_;
        keeper = admin; // owner is keeper by default
        feesController = feesController_;

        _transferOwnership(admin);
    }

    function setSwapper(ISwapper nextSwapper) public onlyOwner {
        uint256 expectedSwap = nextSwapper.previewSwap(reward, want, 10 ** reward.decimals());
        require(expectedSwap > 0, "This swapper doesn't supports swaps");
        swapper = nextSwapper;
        emit SwapperUpdated(address(swapper));
    }

    function setKeeper(address nextKeeper) public onlyOwner {
        require(nextKeeper != address(0), "Zero address");
        keeper = nextKeeper;
        emit KeeperUpdated(keeper);
    }

    function setFeesController(address nextFeesController) public onlyOwner {
        require(nextFeesController != address(0), "Zero address");
        feesController = FeesController(nextFeesController);
        emit FeesControllerUpdated(nextFeesController);
    }

    function toggleVault() public onlyOwner {
        if (paused()) _unpause();
        else _pause();
    }

    /// -----------------------------------------------------------------------
    /// ERC4626 overrides
    /// -----------------------------------------------------------------------

    function totalAssets() public view virtual override returns (uint256) {
        IStargateLPStaking.UserInfo memory info = stargateLPStaking.userInfo(poolStakingId, address(this));
        return stargatePool.amountLPtoLD(info.amount);
    }

    function harvest() public onlyKeeper returns (uint256 wantAmount) {
        stargateLPStaking.withdraw(poolStakingId, 0);
        uint256 rewardAmount = reward.balanceOf(address(this));
        wantAmount = swapper.swap(reward, want, rewardAmount);

        emit Harvest(msg.sender, rewardAmount, wantAmount);
    }

    function previewHarvest() public view returns (uint256) {
        uint256 pendingReward = stargateLPStaking.pendingStargate(poolStakingId, address(this));

        return swapper.previewSwap(reward, want, pendingReward);
    }

    function tend() public onlyKeeper returns (uint256 sharesAdded) {
        uint256 wantAmount = want.balanceOf(address(this));
        uint256 feesAmount = feesController.onHarvest(wantAmount);
        uint256 assets = wantAmount - feesAmount;

        sharesAdded = this.convertToShares(assets);

        stargateRouter.addLiquidity(stargatePool.poolId(), assets, address(this));

        uint256 lpTokens = lpToken.balanceOf(address(this));

        stargateLPStaking.deposit(poolStakingId, lpTokens);

        emit Tend(msg.sender, assets, sharesAdded);
    }

    function previewTend() public view returns (uint256) {
        uint256 harvested = previewHarvest();
        return getStargateLP(harvested);
    }

    function deposit(uint256 assets, address receiver) public virtual override whenNotPaused returns (uint256) {
        require(assets <= maxDeposit(receiver), "ERC4626: deposit more than max");

        uint256 shares = previewDeposit(assets);

        _deposit(_msgSender(), receiver, assets, shares);

        afterDeposit(assets, shares);

        return shares;
    }

    function mint(uint256 shares, address receiver) public virtual override whenNotPaused returns (uint256) {
        require(shares <= maxMint(receiver), "ERC4626: mint more than max");

        uint256 assets = previewMint(shares);

        _deposit(_msgSender(), receiver, assets, shares);

        afterDeposit(assets, shares);

        return assets;
    }

    function withdraw(uint256 assets, address receiver, address owner) public virtual override returns (uint256) {
        require(assets <= maxWithdraw(owner), "ERC4626: withdraw more than max");

        uint256 shares = previewWithdraw(assets);

         uint256 wantAmount = beforeWithdraw(assets, shares);

        _withdraw(_msgSender(), receiver, owner, wantAmount, shares);

        return shares;
    }

    function redeem(uint256 shares, address receiver, address owner) public virtual override returns (uint256) {
        require(shares <= maxRedeem(owner), "ERC4626: redeem more than max");

        uint256 assets = previewRedeem(shares);

        uint256 wantAmount = beforeWithdraw(assets, shares);

        _withdraw(_msgSender(), receiver, owner, wantAmount, shares);

        return wantAmount;
    }

    function beforeWithdraw(uint256 assets, uint256 /*shares*/ ) internal virtual returns (uint256) {
        /// -----------------------------------------------------------------------
        /// Withdraw assets from Stargate
        /// -----------------------------------------------------------------------
        uint256 feesAmount = feesController.onWithdraw(assets);
        uint256 wantAmount = assets - feesAmount;

        uint256 lpTokens = getStargateLP(wantAmount);

        stargateLPStaking.withdraw(poolStakingId, lpTokens);

        lpToken.approve(address(stargateRouter), lpTokens);

        return stargateRouter.instantRedeemLocal(uint16(stargatePool.poolId()), lpTokens, address(this));
    }

    function afterDeposit(uint256 assets, uint256 /*shares*/ ) internal virtual {
        /// -----------------------------------------------------------------------
        /// Deposit assets into Stargate
        /// -----------------------------------------------------------------------
        uint256 feesAmount = feesController.onDeposit(assets);
        uint256 wantAmount = assets - feesAmount;

        want.approve(address(stargateRouter), wantAmount);

        uint256 lpTokensBefore = lpToken.balanceOf(address(this));

        stargateRouter.addLiquidity(stargatePool.poolId(), wantAmount, address(this));

        uint256 lpTokensAfter = lpToken.balanceOf(address(this));

        uint256 lpTokens = lpTokensAfter - lpTokensBefore;

        lpToken.approve(address(stargateLPStaking), lpTokens);

        stargateLPStaking.deposit(poolStakingId, lpTokens);
    }

    function maxDeposit(address) public view override returns (uint256) {
        return paused() ? 0 : type(uint256).max;
    }

    function maxMint(address) public view override returns (uint256) {
        return paused() ? 0 : type(uint256).max;
    }

    function maxWithdraw(address owner) public view override returns (uint256) {
        uint256 cash = want.balanceOf(address(stargatePool));

        uint256 assetsBalance = convertToAssets(this.balanceOf(owner));

        return cash < assetsBalance ? cash : assetsBalance;
    }

    function maxRedeem(address owner) public view override returns (uint256) {
        uint256 cash = want.balanceOf(address(stargatePool));

        uint256 cashInShares = convertToShares(cash);

        uint256 shareBalance = this.balanceOf(owner);

        return cashInShares < shareBalance ? cashInShares : shareBalance;
    }

    /// -----------------------------------------------------------------------
    /// Internal stargate fuctions
    /// -----------------------------------------------------------------------

    function getStargateLP(uint256 amount_) internal view returns (uint256 lpTokens) {
        if (amount_ == 0) {
            return 0;
        }
        uint256 totalSupply = stargatePool.totalSupply();
        uint256 totalLiquidity = stargatePool.totalLiquidity();
        uint256 convertRate = stargatePool.convertRate();

        require(totalLiquidity > 0, "Stargate: cant convert SDtoLP when totalLiq == 0");

        uint256 LDToSD = amount_ / convertRate;

        lpTokens = LDToSD * totalSupply / totalLiquidity;
    }

    /// -----------------------------------------------------------------------
    /// ERC20 metadata generation
    /// -----------------------------------------------------------------------

    function _vaultName(IERC20 asset_) internal view virtual returns (string memory vaultName) {
        vaultName = string.concat("Yasp Stargate Vault ", asset_.symbol());
    }

    function _vaultSymbol(IERC20 asset_) internal view virtual returns (string memory vaultSymbol) {
        vaultSymbol = string.concat("ystg", asset_.symbol());
    }
}
