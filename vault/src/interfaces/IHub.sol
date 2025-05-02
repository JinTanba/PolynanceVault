// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

interface ISchema {
    enum PositionStatus {
        Open,
        Withdrawn,
        Liquidated,
        Redeemed
    }

    struct Position {
        address adaptor;
        bytes positionKey;
        uint256 collateralAmount;
        uint256 tokenQuantity; // token amount
        uint256 price; // price in 1 collateral
        PositionStatus status;
    }
}