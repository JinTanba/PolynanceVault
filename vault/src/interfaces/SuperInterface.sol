// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


/* ─────────────────────  3. Vault public façade  ───────────────────── */
interface IVaultUser {
    /// @notice User deposits USDC which becomes idle collateral.
    function depositCollateral(uint256 amount) external;

    /// @notice Withdraw idle collateral; fails if locked for positions.
    function withdrawCollateral(uint256 amount) external;
}


interface IVaultAdmin {
    function setApprovedStrategy(address strat, bool approved) external;
    function pause(bool p) external;
    function collateralToken() external view returns (address);
}



/* ─────────────────────  6. Events / Errors  ───────────────────── */
library VaultEE {
    enum PositionState {OPEN, SETTLING, CLOSED, LIQUIDATED}
    enum Flow { IN_USER, OUT_STRAT, IN_AFTER_TRADE, OUT_USER }
    event CollateralFlow(bytes32 indexed posKey, Flow t, uint256 amt);
    event PositionStateChange(bytes32 indexed posKey, PositionState to);
    error NotApprovedStrategy(address strat);
    error CollateralShortfall(bytes32 posKey, uint256 needed, uint256 available);
    error VaultPaused();
    error AdaptorCallFailed(address adaptor);
}
