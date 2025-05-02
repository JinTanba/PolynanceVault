
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/* ─────────────────────  0. PositionKey  ───────────────────── */
library PositionKeyLib {
    /// @notice Unique key for {exchange, marketToken, outcomeId, owner}
    function key(
        address exchange,
        address marketToken,
        uint256 outcomeId,
        address owner
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(exchange, marketToken, outcomeId, owner));
    }
}
