// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {ERC4626, ERC20} from "solmate/mixins/ERC4626.sol";
import {StargateVault} from "./StargateVault.sol";
import {ERC4626Factory} from "../../ERC4626Factory.sol";
import "./external/IStargateLPStaking.sol";
import "./external/IStargateRouter.sol";
import "./external/IStargatePool.sol";
import "./external/IStargateFactory.sol";
import "../../periphery/FeesController.sol";
import {ISwapper} from "../../Swapper.sol";

/// @title StargateVaultFactory
/// @notice Factory for creating StargateVault contracts
contract StargateVaultFactory is ERC4626Factory {
    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error StargateVaultFactory__PoolNonexistent();
    error StargateVaultFactory__StakingNonexistent();
    error StargateVaultFactory__Deprecated();

    /// @notice The stargate pool factory contract
    IStargateFactory public immutable stargateFactory;
    /// @notice The stargate bridge router contract
    IStargateRouter public immutable stargateRouter;
    /// @notice The stargate lp staking contract
    IStargateLPStaking public immutable stargateLPStaking;
    /// @notice Swapper contract
    ISwapper public immutable swapper;
    /// @notice fees controller
    FeesController public immutable feesController;

    address public admin;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(
        IStargateFactory factory_,
        IStargateRouter router_,
        IStargateLPStaking staking_,
        FeesController feesController_,
        ISwapper swapper_,
        address admin_
    ) {
        stargateFactory = factory_;
        stargateRouter = router_;
        stargateLPStaking = staking_;
        swapper = swapper_;
        feesController = feesController_;
        admin = admin_;
    }

    /// -----------------------------------------------------------------------
    /// External functions
    /// -----------------------------------------------------------------------
    function createERC4626(ERC20 asset) external override returns (ERC4626 vault) {
        revert StargateVaultFactory__Deprecated();
    }

    function computeERC4626Address(ERC20 asset) external view override returns (ERC4626 vault) {
        revert StargateVaultFactory__Deprecated();
    }

    function createERC4626_(uint256 poolId, uint256 stakingId, IERC20 reward) external returns (ERC4626 vault) {
        IStargatePool pool = stargateFactory.getPool(poolId);
        IERC20 asset = IERC20(pool.token());
        IERC20 lpToken = IERC20(address(pool));

        if (address(asset) == address(0)) {
            revert StargateVaultFactory__PoolNonexistent();
        }

        if (lpToken != stargateLPStaking.poolInfo(stakingId).lpToken) {
            revert StargateVaultFactory__StakingNonexistent();
        }

        StargateVault deployed = new StargateVault{salt: bytes32(0)}(
          asset,
          pool,
          stargateRouter,
          stargateLPStaking,
          stakingId,
          lpToken,
          reward,
          swapper,
          feesController,
          admin
        );

        vault = ERC4626(address(deployed));

        emit CreateERC4626(ERC20(address(asset)), vault);
    }

    function computeERC4626Address_(uint256 poolId, uint256 stakingId, IERC20 reward)
        external
        view
        returns (ERC4626 vault)
    {
        IStargatePool pool = stargateFactory.getPool(poolId);
        IERC20 asset = IERC20(pool.token());
        IERC20 lpToken = IERC20(address(pool));

        if (address(asset) == address(0)) {
            revert StargateVaultFactory__PoolNonexistent();
        }

        if (lpToken != stargateLPStaking.poolInfo(stakingId).lpToken) {
            revert StargateVaultFactory__StakingNonexistent();
        }

        vault = ERC4626(
            _computeCreate2Address(
                keccak256(
                    abi.encodePacked(
                        // Deployment bytecode:
                        type(StargateVault).creationCode,
                        // Constructor arguments:
                        abi.encode(
                            asset,
                            pool,
                            stargateRouter,
                            stargateLPStaking,
                            stakingId,
                            lpToken,
                            reward,
                            swapper,
                            feesController,
                            admin
                        )
                    )
                )
            )
        );
    }
}
