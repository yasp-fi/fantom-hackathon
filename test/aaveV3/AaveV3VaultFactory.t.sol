pragma solidity ^0.8.4;

import "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";
import {IRewardsController} from "../../src/providers/aaveV3/external/IRewardsController.sol";
import {IPool} from "../../src/providers/aaveV3/external/IPool.sol";

import {PoolMock} from "./mocks/Pool.m.sol";
import {ERC20Mock} from "../mocks/ERC20.m.sol";
import {RewardsControllerMock} from "./mocks/RewardsController.m.sol";
import {AaveV3Vault} from "../../src/providers/aaveV3/AaveV3Vault.sol";
import {AaveV3VaultFactory} from "../../src/providers/aaveV3/AaveV3VaultFactory.sol";

contract AaveV3VaultFactoryTest is Test {
    address public constant rewardRecipient = address(0x01);

    ERC20Mock public aave;
    ERC20Mock public aToken;
    ERC20Mock public underlying;
    PoolMock public lendingPool;
    AaveV3VaultFactory public factory;
    IRewardsController public rewardsController;

    function setUp() public {
        aave = new ERC20Mock();
        aToken = new ERC20Mock();
        underlying = new ERC20Mock();
        lendingPool = new PoolMock();
        rewardsController = new RewardsControllerMock(address(aave));
        factory = new AaveV3VaultFactory(lendingPool, rewardRecipient, rewardsController);

        lendingPool.setReserveAToken(address(underlying), address(aToken));
    }

    function test_createERC4626() public {
        AaveV3Vault vault = AaveV3Vault(address(factory.createERC4626(underlying)));

        assertEq(address(vault.aToken()), address(aToken), "aToken incorrect");
        assertEq(address(vault.lendingPool()), address(lendingPool), "lendingPool incorrect");
        assertEq(address(vault.rewardsController()), address(rewardsController), "rewardsController incorrect");
        assertEq(address(vault.rewardRecipient()), address(rewardRecipient), "rewardRecipient incorrect");
    }

    function test_computeERC4626Address() public {
        AaveV3Vault vault = AaveV3Vault(address(factory.createERC4626(underlying)));
        assertEq(address(factory.computeERC4626Address(underlying)), address(vault), "computed vault address incorrect");
    }

    function test_fail_createERC4626ForAssetWithoutAToken() public {
        ERC20Mock fakeAsset = new ERC20Mock();
        vm.expectRevert(abi.encodeWithSignature("AaveV3VaultFactory__ATokenNonexistent()"));
        factory.createERC4626(fakeAsset);
    }
}