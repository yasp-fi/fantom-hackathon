// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Path} from "@uniswap/v3-periphery/contracts/libraries/Path.sol";
import {IQuoter} from "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IPeripheryImmutableState} from "@uniswap/v3-periphery/contracts/interfaces/IPeripheryImmutableState.sol";
import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "forge-std/interfaces/IERC20.sol";
import {Swapper} from "../Swapper.sol";

interface IUniswapV3Router is ISwapRouter, IPeripheryImmutableState {}

/// Uniswap V3 Swapper
contract UniV3Swapper is Swapper {
    using Path for bytes;

    IUniswapV3Factory public immutable swapFactory;
    IUniswapV3Router public immutable swapRouter;

    uint24 public constant POOL_FEE = 3000;

    constructor(IUniswapV3Factory swapFactory_, IUniswapV3Router swapRouter_) Swapper() {
        swapFactory = swapFactory_;
        swapRouter = swapRouter_;
    }

    function previewSwap(IERC20 assetFrom, IERC20 assetTo, uint256 amountIn)
        public
        view
        override
        returns (uint256 amountOut)
    {
        address poolAddress = swapFactory.getPool(address(assetFrom), address(assetTo), POOL_FEE);
        IUniswapV3Pool singlePool = IUniswapV3Pool(poolAddress);

        if (singlePool.factory() == address(swapFactory)) {
            amountOut = _quoteSingleSwap(singlePool, assetFrom, assetTo, amountIn);
        } else {
            address WETH = swapRouter.WETH9();
            address pool1Address = swapFactory.getPool(address(assetFrom), WETH, POOL_FEE);
            IUniswapV3Pool pool1 = IUniswapV3Pool(pool1Address);

            address pool2Address = swapFactory.getPool(WETH, address(assetTo), POOL_FEE);
            IUniswapV3Pool pool2 = IUniswapV3Pool(pool2Address);

            uint256 firstHop = _quoteSingleSwap(pool1, assetFrom, IERC20(WETH), amountIn);
            amountOut = _quoteSingleSwap(pool2, IERC20(WETH), assetTo, firstHop);
        }
    }

    function _quoteSingleSwap(IUniswapV3Pool pool, IERC20 assetFrom, IERC20 assetTo, uint256 amountIn)
        internal
        view
        returns (uint256 amountOut)
    {
        (uint160 sqrtPriceX96,,,,,,) = pool.slot0();
        bool aToB = pool.token0() == address(assetFrom);

        uint8 decimals0 = aToB ? assetFrom.decimals() : assetTo.decimals();
        uint8 decimals1 = aToB ? assetTo.decimals() : assetFrom.decimals();
        uint256 q192 = 2 ** 192;
        
        if (decimals1 > decimals0) {
            uint256 decimals = 10 ** (decimals1 - decimals0);
            amountOut = aToB 
              ? amountIn * sqrtPriceX96 / q192 * sqrtPriceX96 * decimals
              : amountIn * q192 / sqrtPriceX96 / sqrtPriceX96 / decimals;
        } else {
            uint256 decimals = 10 ** (decimals0 - decimals1);
            amountOut = aToB 
              ? amountIn * sqrtPriceX96 / q192 * sqrtPriceX96 / decimals
              : amountIn * q192 / sqrtPriceX96 / sqrtPriceX96 / decimals;
        }
    }

    function _previewSwap(uint256, bytes memory) internal pure override returns (uint256) {
        return 0;
    }

    function _swap(uint256 amountIn, uint256 minAmountOut, bytes memory payload) internal override returns (uint256 amountOut) {
        (address tokenA,,) = payload.decodeFirstPool();

        TransferHelper.safeTransferFrom(tokenA, msg.sender, address(this), amountIn);

        TransferHelper.safeApprove(tokenA, address(swapRouter), amountIn);

        ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
            path: payload,
            recipient: msg.sender,
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: minAmountOut
        });

        amountOut = swapRouter.exactInput(params);
    }

    function _buildPayload(IERC20 assetFrom, IERC20 assetTo) internal view override returns (bytes memory path) {
        address poolAddress = swapFactory.getPool(address(assetFrom), address(assetTo), POOL_FEE);

        IUniswapV3Pool singlePool = IUniswapV3Pool(poolAddress);

        if (singlePool.factory() == address(swapFactory)) {
            path = abi.encodePacked(address(assetFrom), POOL_FEE, address(assetTo));
        } else {
            // optimisticly expect that pool with WETH is already exists
            path = abi.encodePacked(address(assetFrom), POOL_FEE, swapRouter.WETH9, POOL_FEE, address(assetTo));
        }
    }
}
