// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./IStargatePool.sol";

interface IStargateFactory {
    function getPool(uint256) external view returns (IStargatePool);
}
