// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IStrategy {
    /// User-facing entry (e.g., open market-long)
    function openPosition(
        address exchange,
        address marketToken,
        uint256 outcomeId,
        uint128 notionalUSDC,
        bytes memory extraParams
    ) external;

    function rebalance(bytes32 posKey, bytes calldata data) external;
    function liquidate(bytes32 posKey) external;
    function settle(bytes32 posKey, bytes calldata oracleProof) external;
}

interface IVaultStrategyHook {
    /// Pull idle collateral into a position (caller=approved strategy)
    function lockCollateral(bytes32 posKey, uint256 amount) external;

    /// Release collateral to given receiver (strategy or user)
    function unlockCollateral(bytes32 posKey, uint256 amount, address to) external;

    /// Buy/sell more outcome tokens via adaptor; vault moves funds & returns spend
    function adjustExposure(
        bytes32   posKey,
        address   adaptor,
        bytes     calldata adaptorPayload  // opaque to vault
    ) external returns (int256 usdcDelta); // +out / -in
}
