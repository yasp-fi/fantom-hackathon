# YaspFi Fantom hackathon

This repository contains all the smart contracts that were developed by our team during the hackathon period in the Fantom network. The repository includes two main smart contracts based on the ERC-4626 standard, namely **StargateVault** and **AaveV3Vault**.

In addition to the main smart contracts, our team also wrote some peripheral contracts to facilitate the full auto-compound cycle inside the Vaults. These contracts are:

**SpookySwapper**: This contract is used for swaps in Fantom. It facilitates the exchange of tokens between the Vault and other external parties.

**FeesController**: This contract is used to receive fees from the Vault. The fees are collected automatically and can be distributed to the stakeholders as per the defined distribution logic.

All the contracts in this repository have been developed using the Solidity programming language and are based on the ERC-4626 standard. They have been tested thoroughly to ensure their functionality and security. However, we do not provide any guarantee or warranty for their usage.

## Getting Started
To get started with using these contracts, you can clone the repository and build smart contracts via [Foundry](https://book.getfoundry.sh/)  using this command:
```bash
forge build
```
If you have never used Foundry to develop smart contracts, we highly recommend trying this toolkit because of its coolness and convenience.

## Testing
For each contract, a small set of tests is written to test the concept. Generalized property tests for ERC-4626 contracts have also been integrated, for which many thanks to A16Z for [this repo](https://github.com/a16z/erc4626-tests).
```bash
forge test # Runs all tests
forge test -vvv --match-contract AaveV3VaultStdTest # runs only prop tests for AaveV3 Vault
forge test -vvv --match-contract StargateVaultStdTest # runs only prop tests for Stargate Vault
```

## Deployed contracts

- [StargateVaultFactory](https://ftmscan.com/address/0x753b5bba84fa79dcc00bee0fcf53b839a782daa4)
- [StargateVault (USDC)](https://ftmscan.com/address/0x364f0dd479942d9a9b4a63c0b2b1700f31c9ae0b)
- [SpookySwapper](https://ftmscan.com/address/0xdbf7876c13e765694a7acf8ac01284c3ef3ac810)
- [DummySwapper](https://ftmscan.com/address/0x8eae291df7ade0b868d4495673fc595483a9cc24)
- [FeesController](https://ftmscan.com/address/0x9d2acb1d33eb6936650dafd6e56c9b2ab0dd680c)

## License
All the contracts in this repository are licensed under the MIT License. You can use these contracts for any commercial or non-commercial purpose, subject to the terms and conditions of the license.
