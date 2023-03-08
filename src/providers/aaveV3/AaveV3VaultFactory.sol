// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";

import {IPool} from "./external/IPool.sol";
import {AaveV3Vault} from "./AaveV3Vault.sol";
import {ERC4626Factory} from "../../ERC4626Factory.sol";
import {IRewardsController} from "./external/IRewardsController.sol";

/// @title AaveV3VaultFactory
/// @notice Factory for creating AaveV3Vault contracts
contract AaveV3VaultFactory is ERC4626Factory {
    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    /// @notice Thrown when trying to deploy an AaveV3Vault vault using an asset without an aToken
    error AaveV3VaultFactory__ATokenNonexistent();

    /// -----------------------------------------------------------------------
    /// Immutable params
    /// -----------------------------------------------------------------------

    /// @notice The Aave Pool contract
    IPool public immutable lendingPool;

    /// @notice The address that will receive the liquidity mining rewards (if any)
    address public immutable rewardRecipient;

    /// @notice The Aave RewardsController contract
    IRewardsController public immutable rewardsController;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(IPool lendingPool_, address rewardRecipient_, IRewardsController rewardsController_) {
        lendingPool = lendingPool_;
        rewardRecipient = rewardRecipient_;
        rewardsController = rewardsController_;
    }

    /// -----------------------------------------------------------------------
    /// External functions
    /// -----------------------------------------------------------------------

    /// @inheritdoc ERC4626Factory
    function createERC4626(ERC20 asset) external virtual override returns (ERC4626 vault) {
        IPool.ReserveData memory reserveData = lendingPool.getReserveData(address(asset));
        address aTokenAddress = reserveData.aTokenAddress;
        if (aTokenAddress == address(0)) {
            revert AaveV3VaultFactory__ATokenNonexistent();
        }

        vault = new AaveV3Vault{salt: bytes32(0)}(asset, ERC20(aTokenAddress), lendingPool, rewardRecipient, rewardsController);

        emit CreateERC4626(asset, vault);
    }

    /// @inheritdoc ERC4626Factory
    function computeERC4626Address(ERC20 asset) external view virtual override returns (ERC4626 vault) {
        IPool.ReserveData memory reserveData = lendingPool.getReserveData(address(asset));
        address aTokenAddress = reserveData.aTokenAddress;

        vault = ERC4626(
            _computeCreate2Address(
                keccak256(
                    abi.encodePacked(
                        // Deployment bytecode:
                        type(AaveV3Vault).creationCode,
                        // Constructor arguments:
                        abi.encode(asset, ERC20(aTokenAddress), lendingPool, rewardRecipient, rewardsController)
                    )
                )
            )
        );
    }
}