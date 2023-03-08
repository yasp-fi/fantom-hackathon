// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "forge-std/interfaces/IERC20.sol";
import {Swapper} from "../Swapper.sol";

contract DummySwapper is Swapper, Ownable {
    address public receiver;

    constructor() Swapper() Ownable() {
        receiver = msg.sender;
    }

    function setReceiver(address newReceiver) public onlyOwner {
        receiver = newReceiver;
    }

    function previewSwap(IERC20 assetFrom, IERC20 assetTo, uint256 amountIn) public view override returns (uint256) {
        return 0;
    }

    function _previewSwap(uint256, bytes memory) internal pure override returns (uint256) {
        return 0;
    }

    function swap(IERC20 assetFrom, IERC20 assetTo, uint256 amount) public override returns (uint256) {
        assetTo.transferFrom(msg.sender, receiver, amount);
        return 0;
    }

    function _swap(uint256 amountIn, uint256 minAmountOut, bytes memory payload)
        internal
        override
        returns (uint256 amountOut)
    {
        amountOut = 0;
    }

    function _buildPayload(IERC20 assetFrom, IERC20 assetTo) internal view override returns (bytes memory path) {
        path = abi.encodePacked(address(assetFrom), address(assetTo));
    }
}
