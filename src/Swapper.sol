// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.13;

import "forge-std/interfaces/IERC20.sol";
import {Bytes32AddressLib} from "solmate/utils/Bytes32AddressLib.sol";

interface ISwapper {
  function previewSwap(IERC20 assetFrom, IERC20 assetTo, uint256 amountIn) external view returns (uint256 amountOut);
  function swap(IERC20 assetFrom, IERC20 assetTo, uint256 amountIn) external returns (uint256 amountOut);
}

/// @title Swapper
/// @notice Abstract base contract for deploying wrappers for AMMs
/// @dev
abstract contract Swapper is ISwapper {
    /// -----------------------------------------------------------------------
    /// Library usage
    /// -----------------------------------------------------------------------

    using Bytes32AddressLib for bytes32;

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    /// @notice Emitted when a new swap has been executed
    /// @param from The base asset
    /// @param to The quote asset
    /// @param amountIn amount that has been swapped
    /// @param amountOut received amount
    event Swap(address indexed sender, IERC20 indexed from, IERC20 indexed to, uint256 amountIn, uint256 amountOut);

    function previewSwap(IERC20 assetFrom, IERC20 assetTo, uint256 amountIn) public virtual view returns (uint256 amountOut) {
        bytes memory payload = _buildPayload(assetFrom, assetTo);

        amountOut = _previewSwap(amountIn, payload);
    }

    function swap(IERC20 assetFrom, IERC20 assetTo, uint256 amountIn) public virtual returns (uint256 amountOut) {
        bytes memory payload = _buildPayload(assetFrom, assetTo);

        // 10% slippage
        uint256 minAmountOut = previewSwap(assetFrom, assetTo, amountIn) * 90 / 100; 
        amountOut = _swap(amountIn, minAmountOut, payload);

        emit Swap(msg.sender, assetFrom, assetTo, amountIn, amountOut);
    }

    /// -----------------------------------------------------------------------
    /// Internal functions
    /// -----------------------------------------------------------------------
    function _buildPayload(IERC20 assetFrom, IERC20 assetTo) internal virtual view returns (bytes memory path);

    function _previewSwap(uint256 amountIn, bytes memory payload) internal virtual view returns (uint256 amountOut);

    function _swap(uint256 amountIn, uint256 minAmountOut, bytes memory payload) internal virtual returns (uint256 amountOut);
}
