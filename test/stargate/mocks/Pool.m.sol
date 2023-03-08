// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {IStargatePool} from "../../../src/providers/stargate/external/IStargatePool.sol";
import {ERC20Mock} from "../../mocks/ERC20.m.sol";

contract StargatePoolMock is IStargatePool {
    uint256 public poolId;

    ERC20Mock public lpToken;
    ERC20Mock public underlying;

    constructor(uint256 poolId_, ERC20Mock underlying_, ERC20Mock lpToken_) {
      poolId = poolId_;
      lpToken = lpToken_;
      underlying = underlying_;
    }

    function token() external view returns (address) {
      return address(underlying);
    }

    function totalSupply() external view returns (uint256) {
      return lpToken.totalSupply();
    }

    function totalLiquidity() external view returns (uint256) {
      return underlying.totalSupply();
    }

    function convertRate() external view returns (uint256) {
        return 1;
    }

    function amountLPtoLD(uint256 _amountLP) external view returns (uint256) {
        return _amountLP;
    }

    function addLiquidity(uint256 _amountLD, address _to) external {
      underlying.transferFrom(msg.sender, address(this), _amountLD);
      
      lpToken.mint(_to, _amountLD);
    }

    function instantRedeemLocal(uint256 _amountLP, address _to) external {
      lpToken.burn(msg.sender, _amountLP);
      
      underlying.transfer(_to, _amountLP);
    }
}
