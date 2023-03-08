pragma solidity ^0.8.13;

import 'forge-std/Script.sol';

import {ERC20} from 'solmate/tokens/ERC20.sol';
import {IPool} from '../src/providers/aaveV3/external/IPool.sol';
import {IRewardsController} from '../src/providers/aaveV3/external/IRewardsController.sol';
import {AaveV3VaultFactory} from '../src/providers/aaveV3/AaveV3VaultFactory.sol';

contract DeployScript is Script {
    function deployForAsset(
        string memory name,
        address asset,
        AaveV3VaultFactory deployed
    ) public payable {
        ERC20 want = ERC20(asset);
        deployed.createERC4626(want);
        console2.log(
            name,
            ' - ',
            address(deployed.computeERC4626Address(want))
        );
    }

    function run() public payable returns (AaveV3VaultFactory deployed) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32('PRIVATE_KEY'));
        IPool lendingPool = IPool(vm.envAddress('AAVE_V3_LENDING_POOL_FANTOM'));
        address rewardRecipient = vm.envAddress(
            'AAVE_V3_REWARDS_RECIPIENT_FANTOM'
        );
        IRewardsController rewardsController = IRewardsController(
            vm.envAddress('AAVE_V3_REWARDS_CONTROLLER_FANTOM')
        );

        vm.startBroadcast(deployerPrivateKey);

        console2.log('broadcaster', vm.addr(deployerPrivateKey));
        deployed = new AaveV3VaultFactory(
            lendingPool,
            rewardRecipient,
            rewardsController
        );
        // deployed = AaveV3VaultFactory(address(0xA618c7a92243C33E74c9157359D0BDFa66D4e2CD));
        // Investments deploy

        vm.stopBroadcast();
    }
}
