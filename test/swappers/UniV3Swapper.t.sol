// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../src/swappers/UniV3Swapper.sol";
import {console2} from "forge-std/console2.sol";
import {IQuoter} from "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IPeripheryImmutableState} from "@uniswap/v3-periphery/contracts/interfaces/IPeripheryImmutableState.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "forge-std/interfaces/IERC20.sol";

abstract contract UniswapV3Helper {
    IUniswapV3Factory public immutable swapFactory;
    IUniswapV3Router public immutable swapRouter;
    IQuoter public immutable swapQuoter;
    uint24 public fee = 1000;

    constructor() {
        swapFactory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
        swapRouter = IUniswapV3Router(0xE592427A0AEce92De3Edee1F18E0157C05861564);
        swapQuoter = IQuoter(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);
    }

    function getQuote(IERC20 assetFrom, IERC20 assetTo, uint256 amountIn) public returns (uint256 amountOut) {
        bytes memory path = abi.encodePacked(address(assetFrom), fee, address(assetTo));
        amountOut = swapQuoter.quoteExactInput(path, amountIn);
    }

    function getDoubleHop(IERC20 assetFrom, IERC20 assetVia, IERC20 assetTo, uint256 amountIn)
        public
        returns (uint256 amountOut)
    {
        bytes memory path = abi.encodePacked(address(assetFrom), fee, address(assetVia), fee, address(assetTo));
        amountOut = swapQuoter.quoteExactInput(path, amountIn);
    }
}

contract UniV3SwapperTest is Test, UniswapV3Helper {
    IERC20 public immutable DAI = IERC20(address(0x6B175474E89094C44Da98b954EedeAC495271d0F));
    IERC20 public immutable WETH = IERC20(address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
    IERC20 public immutable USDC = IERC20(address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48));
    IERC20 public immutable USDT = IERC20(address(0xdAC17F958D2ee523a2206206994597C13D831ec7));

    IERC20 public immutable STG = IERC20(address(0xAf5191B0De278C7286d6C7CC6ab6BB8A73bA2Cd6));

    UniV3Swapper public swapper;

    function setUp() public {
        swapper = new UniV3Swapper(swapFactory, swapRouter);
    }

    function test_swapSTG_ETH() public {
        uint256 amountIn = 10 ** 12;
        deal(address(STG), msg.sender, amountIn);
        console.log("STG Balance", STG.balanceOf(msg.sender));
        STG.approve(address(swapper), amountIn);

        uint256 expected = swapper.previewSwap(STG, WETH, amountIn);
        uint256 actual = swapper.swap(STG, WETH, amountIn);
        uint256 balance = STG.balanceOf(msg.sender);

        assertEq(expected, actual);
        assertEq(actual, balance);

        swapper.swap(WETH, STG, balance);

        assertEq(STG.balanceOf(msg.sender), amountIn);
    }

    function test_previewSwapSTG_ETH() public {
        uint256 amountIn = 10 ** 12;

        assertEq(swapper.previewSwap(STG, WETH, amountIn), getQuote(STG, WETH, amountIn));
        assertEq(swapper.previewSwap(WETH, STG, amountIn), getQuote(WETH, STG, amountIn));
    }
}
