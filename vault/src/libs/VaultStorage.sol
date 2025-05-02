// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {NonfungiblePredictionManager} from "../NonfungiblePredictionManager.sol";

/**
 * Shared persistent state for CoreVault and all mix-ins.
 * Access from anywhere via $.$$() once you write
 *
 *   import {VaultStorage as $} from "./VaultStorage.sol";
 *
 * (No “using” needed.)
 */
library VaultStorage {
    /* keccak256("polynance.corevault.storage") - 1 */
    //TODO
    bytes32 internal constant SLOT = 0xccb9ce4c9a3b38bf5d090cdd4a8f94bbf1c0869b3bb0a81f8fc9fb0e9f4b7e61;
    enum PositionState { PREVIEWED, OPEN, SETTLING, CLOSED, LIQUIDATED }

    struct PositionData {
        PositionState  state;
        uint64  opened;
        uint64  closed;
        uint128 collateral;
        uint128 size;
        uint128 entryPriceE18;
    }

    struct Layout {
        mapping(bytes32 => PositionData) pos;
        uint128 idleCollateral;
        uint128 totalLocked;
        IERC20  collateralToken;
        NonfungiblePredictionManager npm;
        mapping(address => bool) approvedStrategy;
        mapping(address => bool) oparators;
    }

    function $$() internal pure returns (Layout storage l) {
        bytes32 slot = SLOT;
        assembly { l.slot := slot }
    }
}
