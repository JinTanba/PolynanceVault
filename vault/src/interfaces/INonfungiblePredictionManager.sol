// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title INonfungiblePredictionManager
 * @notice Interface for the NonfungiblePredictionManager contract
 */
interface INonfungiblePredictionManager is IERC721 {
    struct PositionData {
        address exchange;      // Exchange address (e.g., Uniswap v3, Sushiswap, etc.)
        address tokenAddress;  // The token address being traded
        uint256 tokenId;       // Token ID in the exchange
        uint256 amount;        // Quantity of tokens held
        uint256 collateral;    // Collateral amount
        uint256 purchasePrice; // Price per token at purchase time
        uint256 purchaseValue; // Total position value at purchase time
        uint256 timestamp;     // When position was created or last updated
        bool active;           // Whether position is active (not fully sold)
    }

    /**
     * @notice Mint a new position NFT
     * @param owner Owner of the position
     * @param exchange Exchange address
     * @param tokenAddress Token address
     * @param tokenId Token ID
     * @param amount Initial amount
     * @param collateral Initial collateral
     * @param purchasePrice Purchase price
     * @param purchaseValue Purchase value
     * @return tokenId The minted token ID
     */
    function mintPosition(
        address owner,
        address exchange,
        address tokenAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 collateral,
        uint256 purchasePrice,
        uint256 purchaseValue
    ) external returns (uint256);

    /**
     * @notice Burn a position NFT
     * @param tokenId Token ID to burn
     */
    function burnPosition(uint256 tokenId) external;

    /**
     * @notice Update position data
     * @param tokenId Token ID to update
     * @param newAmount New amount
     * @param newCollateral New collateral
     */
    function updatePosition(
        uint256 tokenId,
        uint256 newAmount,
        uint256 newCollateral
    ) external;

    /**
     * @notice Get position key from parameters
     * @param exchange Exchange address
     * @param tokenAddress Token address
     * @param tokenId Token ID
     * @return Position key
     */
    function getPositionKey(
        address exchange,
        address tokenAddress,
        uint256 tokenId
    ) external pure returns (uint256);

    /**
     * @notice Get trader position key
     * @param positionKey Position key
     * @param trader Trader address
     * @return Trader position key
     */
    function getTraderPositionKey(
        uint256 positionKey,
        address trader
    ) external pure returns (bytes32);

    /**
     * @notice Get token ID for a trader's position
     * @param exchange Exchange address
     * @param tokenAddress Token address
     * @param tokenId Token ID
     * @param trader Trader address
     * @return tokenId NFT token ID
     */
    function getTokenIdFromTraderPosition(
        address exchange,
        address tokenAddress,
        uint256 tokenId,
        address trader
    ) external view returns (uint256);

    /**
     * @notice Get all token IDs for a position
     * @param exchange Exchange address
     * @param tokenAddress Token address
     * @param tokenId Token ID
     * @return tokenIds Array of NFT token IDs
     */
    function getTokenIdsForPosition(
        address exchange,
        address tokenAddress,
        uint256 tokenId
    ) external view returns (uint256[] memory);

    /**
     * @notice Check if a token represents an active position
     * @param tokenId Token ID to check
     * @return active Whether the position is active
     */
    function isPositionActive(uint256 tokenId) external view returns (bool);

    /**
     * @notice Get position details
     * @param tokenId Token ID
     * @return position The position data
     */
    function getPosition(uint256 tokenId) external view returns (PositionData memory);
}