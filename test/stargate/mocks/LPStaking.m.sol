// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {IStargateLPStaking} from "../../../src/providers/stargate/external/IStargateLPStaking.sol";
import {ERC20Mock} from "../../mocks/ERC20.m.sol";

contract StargateLPStakingMock is IStargateLPStaking {
    ERC20Mock public lpToken;
    ERC20Mock public reward;
    UserInfo userInfo_;
    PoolInfo poolInfo_;

    constructor(ERC20Mock lpToken_, ERC20Mock reward_) {
      lpToken = lpToken_;
      reward = reward_;
    }

    function userInfo(uint256 _pid, address _owner) external view returns (UserInfo memory) {
      return userInfo_;
    }

    function poolInfo(uint256 _pid) external view returns (PoolInfo memory) {
      return poolInfo_;
    }

    function deposit(uint256 _pid, uint256 _amount) external {
        lpToken.transferFrom(msg.sender, address(this), _amount);

        userInfo_.amount += _amount;
    }

    function withdraw(uint256 _pid, uint256 _amount) external {
        require(userInfo_.amount >= _amount);

        userInfo_.amount -= _amount;
        
        reward.mint(msg.sender, pendingStargate(_pid, msg.sender));
        lpToken.transfer(msg.sender, _amount);
    }

    function pendingStargate(uint256 _pid, address _user) public view returns (uint256) {
      return 0;
    }
}
