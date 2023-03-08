pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";
import "forge-std/interfaces/IERC20.sol";
import "../src/providers/stargate/external/IStargateLPStaking.sol";
import "../src/providers/stargate/external/IStargateRouter.sol";
import "../src/providers/stargate/external/IStargatePool.sol";
import "../src/providers/stargate/external/IStargateFactory.sol";
import "../src/periphery/FeesController.sol";
import {ISwapper} from "../src/Swapper.sol";
import {StargateVaultFactory} from "../src/providers/stargate/StargateVaultFactory.sol";
import {StargateVault} from "../src/providers/stargate/StargateVault.sol";

contract DeployScript is Script {
    IERC20 public USDC = IERC20(address(0x04068DA6C83AFCFA0e13ba15A6696662335D5B75));
    IERC20 public STG = IERC20(address(0x2F6F07CDcf3588944Bf4C42aC74ff24bF56e7590));
    address public ADMIN = address(0x777BcC85d91EcE0C641a6F03F35a2A98F4049777);

    function deployForPool(
        string memory name,
        uint256 poolId,
        uint256 stakingId,
        IERC20 reward,
        StargateVaultFactory deployed
    ) public payable returns (address vault) {
        deployed.createERC4626_(poolId, stakingId, reward);
        vault = address(deployed.computeERC4626Address_(poolId, stakingId, reward));

        USDC.approve(vault, 10 ** 6);
        require(StargateVault(vault).owner() == ADMIN);
        console2.log("USDC balance", USDC.balanceOf(ADMIN));
        uint256 shares = StargateVault(vault).deposit(10 ** 6, ADMIN);
        IERC20(vault).approve(vault, shares / 10);
        StargateVault(vault).withdraw(shares / 10, ADMIN, ADMIN);
        console2.log(name, "-", vault);
    }

    function run() public payable returns (StargateVaultFactory deployed) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);
        address broadcaster = vm.addr(deployerPrivateKey);
        console2.log("broadcaster", broadcaster);

        deployed = new StargateVaultFactory(
          IStargateFactory(address(0x9d1B1669c73b033DFe47ae5a0164Ab96df25B944)),
          IStargateRouter(address(0xAf5191B0De278C7286d6C7CC6ab6BB8A73bA2Cd6)),
          IStargateLPStaking(address(0x224D8Fd7aB6AD4c6eb4611Ce56EF35Dec2277F03)),
          FeesController(address(0x9D2AcB1D33eb6936650Dafd6e56c9B2ab0Dd680c)),
          ISwapper(address(0x8eaE291df7aDe0B868d4495673FC595483a9Cc24)),
          ADMIN
        );
        // deployed = StargateVaultFactory(address());
        // Investments deploy

        deployForPool("USDC", 1, 0, STG, deployed);

        vm.stopBroadcast();
    }
}
