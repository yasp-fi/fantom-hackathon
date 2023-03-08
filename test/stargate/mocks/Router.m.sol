// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {IStargateRouter} from "../../../src/providers/stargate/external/IStargateRouter.sol";
import {StargatePoolMock, ERC20Mock} from "./Pool.m.sol";

contract StargateRouterMock is IStargateRouter {
    StargatePoolMock public pool;

    constructor(StargatePoolMock pool_) {
      pool = pool_;
    }

    function addLiquidity(uint256 _from, uint256 _amountLD, address _to) external {
      ERC20Mock(pool.underlying()).transferFrom(msg.sender, address(this), _amountLD);
      ERC20Mock(pool.underlying()).approve(address(pool), _amountLD);

      pool.addLiquidity(_amountLD, _to);
    }

    function instantRedeemLocal(uint16 _from, uint256 _amountLP, address _to) external returns (uint256) {
      ERC20Mock(pool.lpToken()).approve(address(pool), _amountLP);

      pool.instantRedeemLocal(_amountLP, _to);

      ERC20Mock(pool.underlying()).transfer(msg.sender, _amountLP);
    }
}