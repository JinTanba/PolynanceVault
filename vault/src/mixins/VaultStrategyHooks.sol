// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReentrancyGuard}    from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20, IERC20}  from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IVaultStrategyHook} from "../interfaces/IStrategy.sol";
import {VaultStorage} from "../libs/VaultStorage.sol";
import {IVaultUser,VaultEE} from "../interfaces/SuperInterface.sol";


abstract contract VaultStrategyHooks is IVaultStrategyHook, ReentrancyGuard {

    function lockCollateral(bytes32 posKey, uint256 amount)
        external
        override
        nonReentrant
    {
        VaultStorage.Layout storage v = VaultStorage.$$();

        if (!v.approvedStrategy[msg.sender]) revert VaultEE.NotApprovedStrategy(msg.sender);
        if (v.idleCollateral < amount) revert VaultEE.CollateralShortfall(posKey, amount, v.idleCollateral);

        /* global accounting */
        v.idleCollateral -= uint128(amount);
        v.totalLocked += uint128(amount);

        v.pos[posKey].collateral += uint128(amount);
        if (v.pos[posKey].state == VaultStorage.PositionState.PREVIEWED) {
            v.pos[posKey].state  = VaultStorage.PositionState.OPEN;
            v.pos[posKey].opened = uint64(block.timestamp);
        }
        
        SafeERC20.safeTransfer(v.collateralToken, msg.sender, amount);
        //go aave;
        emit VaultEE.CollateralFlow(posKey, VaultEE.Flow.OUT_STRAT, amount);
    }

    /* ════════════════════════════════════════════════════════════════════
                               unlockCollateral
       Strategy returns funds to the vault; caller decides the final
       recipient (`to`).  If `to==address(this)` they stay idle inside.
    ════════════════════════════════════════════════════════════════════ */
    function unlockCollateral(
        bytes32 posKey,
        uint256 amount,
        address to
    )
        external
        override
        nonReentrant
    {
        VaultStorage.Layout storage v = VaultStorage.$$();

        if (!v.approvedStrategy[msg.sender]) revert VaultEE.NotApprovedStrategy(msg.sender);
        if (v.pos[posKey].collateral < amount) revert VaultEE.CollateralShortfall(posKey, amount, v.pos[posKey].collateral);

        SafeERC20.safeTransferFrom(v.collateralToken, msg.sender, address(this), amount);

        v.totalLocked -= uint128(amount);
        v.pos[posKey].collateral -= uint128(amount);

        if (to == address(this)) {
            v.idleCollateral += uint128(amount);
            emit VaultEE.CollateralFlow(posKey, VaultEE.Flow.IN_AFTER_TRADE, amount);
        } else {
            SafeERC20.safeTransfer(v.collateralToken, to, amount);
            emit VaultEE.CollateralFlow(posKey, VaultEE.Flow.OUT_USER, amount);
        }

        /* auto-close position if fully unlocked */
        if (
            v.pos[posKey].collateral == 0 &&
            v.pos[posKey].state == VaultStorage.PositionState.OPEN
        ) {
            v.pos[posKey].state  = VaultStorage.PositionState.CLOSED;
            v.pos[posKey].closed = uint64(block.timestamp);
            // emit VaultEE.PositionStateChange(posKey, VaultStorage.PositionState.CLOSED);
        }
    }

    function adjustExposure(
        bytes32   /*posKey*/,
        address  adaptor,
        bytes    calldata payload
    )
        external
        override
        nonReentrant
        returns (int256 usdcDelta)
    {
        // VaultStorage.Layout storage v = VaultStorage.$$();
        // if (!v.approvedStrategy[msg.sender]) revert VaultEE.NotApprovedStrategy(msg.sender);

        // uint256 balBefore = IERC20(v.collateralToken).balanceOf(address(this));

        // (bool ok, bytes memory ret) = adaptor.call(payload);
        // if (!ok) {
        //     if (ret.length != 0) assembly { revert(add(ret,32), mload(ret)) }
        //     revert VaultEE.AdaptorCallFailed(adaptor);
        // }

        // uint256 balAfter = IERC20(v.collateralToken).balanceOf(address(this));
        // usdcDelta = int256(balAfter) - int256(balBefore);

        // /* idle-collateral bookkeeping */
        // if (usdcDelta > 0) {
        //     v.idleCollateral += uint128(uint256(usdcDelta));
        // } else if (usdcDelta < 0) {
        //     uint256 spent = uint256(-usdcDelta);
        //     if (v.idleCollateral < spent)
        //         revert VaultEE.CollateralShortfall(bytes32(0), spent, v.idleCollateral);
        //     v.idleCollateral -= uint128(spent);
        // }
    }

     


}
