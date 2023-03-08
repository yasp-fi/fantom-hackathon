// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "forge-std/interfaces/IERC20.sol";

interface IERC4626 {
    function asset() external view returns (address);
}

contract FeesController is Ownable {
    uint24 constant MAX_BPS = 10000;
    uint24 constant MAX_FEE_BPS = 2500;

    struct FeeConfig {
        bool enabled;
        uint24 depositFeeBps;
        uint24 withdrawFeeBps;
        uint24 harvestFeeBps;
    }

    FeeConfig public defaultConfig;
    address public treasury;

    mapping(address => FeeConfig) public configs;
    mapping(address => uint256) public feesCollected;

    event DefaultConfigUpdated(FeeConfig newConfig);
    event ConfigUpdated(address indexed vault, FeeConfig newConfig);
    event FeesCollected(address indexed vault, uint256 feeAmount, address asset);
    event TreasuryUpdated(address prevTreasury, address nextTreasury);

    constructor() Ownable() {}

    function setTreasury(address nextTreasury) external onlyOwner {
        address prevTreasury = treasury;
        treasury = nextTreasury;

        emit TreasuryUpdated(prevTreasury, nextTreasury);
    }

    function setDefaultConfig(FeeConfig memory config) external onlyOwner {
        _validateConfig(config);
        defaultConfig = config;

        emit DefaultConfigUpdated(config);
    }

    function setCustomConfig(address vault, FeeConfig memory config) external onlyOwner {
        _validateConfig(config);
        configs[vault] = config;

        emit ConfigUpdated(vault, config);
    }

    function onDeposit(uint256 amount) external returns (uint256 feesAmount) {
        FeeConfig memory config = configs[msg.sender];

        if (!config.enabled) {
            config = defaultConfig;
        }

        feesAmount = _collectFees(msg.sender, amount, config.depositFeeBps);
    }

    function onWithdraw(uint256 amount) external returns (uint256 feesAmount) {
        FeeConfig memory config = configs[msg.sender];

        if (!config.enabled) {
            config = defaultConfig;
        }

        feesAmount = _collectFees(msg.sender, amount, config.withdrawFeeBps);
    }

    function onHarvest(uint256 amount) external returns (uint256 feesAmount) {
        FeeConfig memory config = configs[msg.sender];

        if (!config.enabled) {
            config = defaultConfig;
        }

        feesAmount = _collectFees(msg.sender, amount, config.harvestFeeBps);
    }

    function _collectFees(address vault, uint256 amount, uint24 bps) internal returns (uint256 feesAmount) {
        address asset = IERC4626(vault).asset();
        feesAmount = amount * bps / MAX_BPS;

        if (feesAmount > 0) {
            TransferHelper.safeTransferFrom(asset, vault, treasury, feesAmount);
            feesCollected[vault] += feesAmount;

            emit FeesCollected(vault, feesAmount, asset);
        }
    }

    function _validateConfig(FeeConfig memory config) internal pure returns (bool) {
        require(config.depositFeeBps <= MAX_FEE_BPS, "Invalid deposit fee");
        require(config.withdrawFeeBps <= MAX_FEE_BPS, "Invalid withdraw fee");
        require(config.harvestFeeBps <= MAX_FEE_BPS, "Invalid harvest fee");
        return true;
    }
}
