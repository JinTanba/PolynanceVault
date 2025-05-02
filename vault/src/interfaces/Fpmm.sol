// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IConditionalTokens } from "./IConditionalTokens.sol"; // ← path as used in your project

/**
 * @title IFpmm
 * @notice Interface for the Gnosis Fixed-Product Market Maker (FPMM) that trades
 *         ERC-1155 Conditional Tokens defined by `IConditionalTokens`.
 * @dev All values are expressed in wei-style uint256 integers.
 */
interface IFpmm {
    /* ──────────────────── Events ──────────────────── */

    event FPMMFundingAdded(
        address indexed funder,
        uint256[] amountsAdded,
        uint256 sharesMinted
    );

    event FPMMFundingRemoved(
        address indexed funder,
        uint256[] amountsRemoved,
        uint256 collateralRemovedFromFeePool,
        uint256 sharesBurnt
    );

    event FPMMBuy(
        address indexed buyer,
        uint256 investmentAmount,
        uint256 feeAmount,
        uint256 indexed outcomeIndex,
        uint256 outcomeTokensBought
    );

    event FPMMSell(
        address indexed seller,
        uint256 returnAmount,
        uint256 feeAmount,
        uint256 indexed outcomeIndex,
        uint256 outcomeTokensSold
    );

    /* ───────────── Read-only getters ───────────── */

    function conditionalTokens() external view returns (IConditionalTokens);
    function collateralToken()  external view returns (IERC20);

    function conditionIds(uint256 index)        external view returns (bytes32);
    function outcomeSlotCounts(uint256 index)   external view returns (uint256);
    function collectionIds(uint256 condIdx, uint256 collIdx)
        external
        view
        returns (bytes32);
    function positionIds(uint256 index)         external view returns (uint256);

    function fee()           external view returns (uint256);
    function feePoolWeight() external view returns (uint256);

    function collectedFees()                         external view returns (uint256);
    function feesWithdrawableBy(address account)     external view returns (uint256);

    /* ─────────────── Fee handling ─────────────── */

    function withdrawFees(address account) external;

    /* ─────────── Liquidity management ─────────── */

    function addFunding(
        uint256 addedFunds,
        uint256[] calldata distributionHint
    ) external;

    function removeFunding(uint256 sharesToBurn) external;

    /* ───────────── Price calculation ───────────── */

    function calcBuyAmount(
        uint256 investmentAmount,
        uint256 outcomeIndex
    ) external view returns (uint256);

    function calcSellAmount(
        uint256 returnAmount,
        uint256 outcomeIndex
    ) external view returns (uint256);

    /* ──────────────── Trading API ──────────────── */

    function buy(
        uint256 investmentAmount,
        uint256 outcomeIndex,
        uint256 minOutcomeTokensToBuy
    ) external;

    function sell(
        uint256 returnAmount,
        uint256 outcomeIndex,
        uint256 maxOutcomeTokensToSell
    ) external;

    /* ────────── ERC-1155 receiver hooks ────────── */

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4);

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4);
}
