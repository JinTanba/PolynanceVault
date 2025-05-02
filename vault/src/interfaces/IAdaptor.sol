// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IAdaptor {

    function priceE18(
        address exchange,
        address marketToken,
        uint256 outcomeId
    ) external view returns (uint256);

    function buildBuy(
        address marketToken,
        uint256 outcomeId,
        uint128 amount
    ) external view returns (bytes memory);

    function buildSell(
        address marketToken,
        uint256 outcomeId,
        uint128 amount
    ) external view returns (bytes memory);

    function execute(bytes calldata payload) external returns (int256 usdcDelta, uint128 tokenDelta);
}
