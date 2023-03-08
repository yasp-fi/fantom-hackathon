pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";
import "forge-std/interfaces/IERC20.sol";
import {SpookySwapper, IUniswapV2Router01} from "../src/swappers/SpookySwapper.sol";

contract DeployScript is Script {
    function run() public payable returns (SpookySwapper deployed) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        IERC20 STG = IERC20(address(0x2F6F07CDcf3588944Bf4C42aC74ff24bF56e7590));
        IERC20 USDC = IERC20(address(0x04068DA6C83AFCFA0e13ba15A6696662335D5B75));
        IUniswapV2Router01 router = IUniswapV2Router01(address(0xF491e7B69E4244ad4002BC14e878a34207E38c29));

        vm.startBroadcast(deployerPrivateKey);

        console2.log("broadcaster", vm.addr(deployerPrivateKey));

        deployed = new SpookySwapper(router);
        // deployed = SpookySwapper(address(0xDobf7876C13e765694A7aCf8Ac01284c3eF3aC810));
        address[] memory path = new address[](2);
        path[0] = address(STG);
        path[1] = address(USDC);

        uint256[] memory amountsOut = router.getAmountsOut(10 ** 12, path);
        console2.log("expect STG -> USDC", amountsOut[0], amountsOut[1]);

        console2.log("preview STG -> USDC", deployed.previewSwap(STG, USDC, 10 ** 12));
        STG.approve(address(deployed), 10 ** 12);
        console2.log("swap STG -> USDC", deployed.swap(STG, USDC, 10 ** 12));

        vm.stopBroadcast();
    }
}
