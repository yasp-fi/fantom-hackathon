// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "forge-std/interfaces/IERC20.sol";
import {Swapper} from "../Swapper.sol";

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

/// Spooky Swap Swapper
contract SpookySwapper is Swapper {
    IUniswapV2Router01 public immutable swapRouter;
    mapping(address => mapping(address => address)) pools;

    constructor(IUniswapV2Router01 swapRouter_) Swapper() {
        swapRouter = swapRouter_;
    }

    function swap(IERC20 assetFrom, IERC20 assetTo, uint256 amountIn) public override returns (uint256 amountOut) {
        address[] memory path = _buildPath(assetFrom, assetTo);

        amountOut = _swapWithPath(amountIn, 0, path);

        emit Swap(msg.sender, assetFrom, assetTo, amountIn, amountOut);
    }

    function previewSwap(IERC20 assetFrom, IERC20 assetTo, uint256 amountIn)
        public
        view
        override
        returns (uint256 amountOut)
    {
        address[] memory path = _buildPath(assetFrom, assetTo);

        amountOut = _previewSwapWithPath(amountIn, path);
    }

    function _swapWithPath(uint256 amountIn, uint256 minAmountOut, address[] memory path)
        internal
        returns (uint256 amountOut)
    {
        TransferHelper.safeTransferFrom(path[0], msg.sender, address(this), amountIn);

        TransferHelper.safeApprove(path[0], address(swapRouter), amountIn);

        uint256[] memory amountsOut =
            swapRouter.swapExactTokensForTokens(amountIn, minAmountOut, path, msg.sender, block.timestamp);

        amountOut = amountsOut[amountsOut.length - 1];
    }

    function _previewSwapWithPath(uint256 amountIn, address[] memory path) internal view returns (uint256) {
        uint256[] memory amountsOut = swapRouter.getAmountsOut(amountIn, path);
        return amountsOut[amountsOut.length - 1];
    }

    function _buildPath(IERC20 assetFrom, IERC20 assetTo) internal view returns (address[] memory path) {
        path = new address[](2);
        path[0] = address(assetFrom);
        path[1] = address(assetTo);
    }

    function _previewSwap(uint256 amountIn, bytes memory payload) internal view override returns (uint256) {
        return 0;
    }

    function _swap(uint256 amountIn, uint256 minAmountOut, bytes memory payload)
        internal
        override
        returns (uint256 amountOut)
    {
        amountOut = 0;
    }

    function _buildPayload(IERC20 assetFrom, IERC20 assetTo) internal view override returns (bytes memory payload) {
        payload = abi.encodePacked(address(assetFrom), address(assetTo));
    }
}
