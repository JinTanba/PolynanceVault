// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./interfaces/IStrategy.sol";
import "./interfaces/IAdaptor.sol";
import "./interfaces/INonfungiblePredictionManager.sol";



contract SimpleStrategy is IStrategy, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;

    // === Constants ===
    uint256 private constant DECIMALS_FACTOR = 10**18;
    uint256 private constant PCT_BASE = 1_000_000; // 100% = 1,000,000
    uint256 private liquidationCost;//10%
    
    // === State Variables ===
    IERC20 public immutable collateralToken;
    address public immutable vault;
    INonfungiblePredictionManager public immutable nftManager;
    
    // Configurable parameters
    uint256 public bettingToValueRate; // Fixed ratio of collateral required at purchase/ Threshold for liquidation
    
    // === Events ===
    event PositionCreated(uint256 indexed tokenId, address indexed owner, uint256 amount, uint256 collateral, uint256 price);
    event PositionUpdated(uint256 indexed tokenId, address indexed owner, uint256 amount, uint256 collateral, uint256 price);
    event PositionSold(uint256 indexed tokenId, address indexed owner, uint256 amount, uint256 payout);
    event PositionSettled(uint256 indexed tokenId, address indexed settler, address indexed owner, uint256 reward, uint256 refund);
    event FundingAdded(uint256 indexed tokenId, address indexed owner, uint256 amount, uint256 newCollateral);
    event ParameterUpdated(string indexed paramName, uint256 oldValue, uint256 newValue);
    
    // === Modifiers ===
    modifier onlyVault() {
        require(msg.sender == vault, "Only vault can call");
        _;
    }
    
    /**
     * @notice Constructor initializes the strategy
     * @param _collateralToken The collateral token
     * @param _nftManager The NFT position manager
     * @param _collateralRequirement Collateral requirement percentage (PCT_BASE)
     * @param _settlementThreshold Settlement threshold percentage (PCT_BASE)
     */
    constructor(
        address _collateralToken,
        address _nftManager,
        uint256 _collateralRequirement,
        uint256 _settlementThreshold
    ) {        
        collateralToken = IERC20(_collateralToken);
        nftManager = INonfungiblePredictionManager(_nftManager);
        vault = msg.sender; // The vault deploys the strategy
        bettingToValueRate = _collateralRequirement;
    }
    
    /**
     * @notice Delegate buying operation to the strategy
     * @param user User address
     * @param adaptor Adaptor address
     * @param exchange Exchange address
     * @param tokenAddress Token address
     * @param tokenId Token ID 
     * @param amount Amount to buy
     * @param data Additional data for the trade
     * @return positionKey Generated position key
     * @return collateralAmount Collateral amount used
     */
    function delegateBuy(
        address user, 
        address adaptor,
        address exchange, 
        address tokenAddress, 
        uint256 tokenId, 
        uint256 amount, 
        bytes calldata data
    ) external override onlyVault nonReentrant returns (uint256 positionKey, uint256 collateralAmount) {
        require(amount > 0, "Amount must be greater than zero");
        
        // Get price from adaptor
        uint256 price = IAdaptor(adaptor).getPrice(exchange, tokenAddress, tokenId);
        require(price > 0, "Invalid price");
        
        // Calculate costs
        uint256 positionValue = (price * amount) / DECIMALS_FACTOR;
        collateralAmount = (positionValue * bettingToValueRate) / PCT_BASE;
        uint256 totalCost = positionValue + collateralAmount;
        
        // Transfer tokens from vault (which already collected from the user)
        collateralToken.safeTransferFrom(vault, address(this), totalCost);
        
        // Create trade parameters for the adaptor
        IAdaptor.TradeParams memory params = IAdaptor.TradeParams({
            trader: address(this),
            exchange: exchange,
            tokenAddress: tokenAddress,
            tokenId: tokenId,
            amount: amount,
            isBuy: true,
            data: data
        });
        
        // Generate position key
        positionKey = nftManager.getPositionKey(exchange, tokenAddress, tokenId);
        
        // Check if user already has a position
        uint256 nftTokenId = nftManager.getTokenIdFromTraderPosition(
            exchange, 
            tokenAddress, 
            tokenId, 
            user
        );
        

        // Position exists, update it
        // First get current position data
        INonfungiblePredictionManager.PositionData memory position = nftManager.getPosition(nftTokenId);
        
        uint256 newAmount = position.amount + amount;
        uint256 newCollateral = position.collateral + collateralAmount;
        uint256 newPurchaseValue = position.purchaseValue + positionValue;
        // Update position in NFT manager
        nftManager.updatePosition(nftTokenId, newAmount, newCollateral);
        emit PositionUpdated(nftTokenId, user, newAmount, newCollateral, price);

        return (positionKey, collateralAmount);
    }

    /**
     * @notice Helper function to safely execute a payload on the exchange
     * @param adaptor Adaptor address
     * @param payload The calldata payload
     * @return success Whether the call succeeded
     */
    function executePayload(address adaptor, bytes memory payload) internal returns (bool) {
        require(adaptor != address(0), "Invalid adaptor address");
        (bool success, ) = adaptor.call(payload);
        require(success, "Settlement execution failed");
        return success;
    }
        
    
    /**
     * @notice Delegate selling operation to the strategy
     * @param user User address
     * @param adaptor Adaptor address
     * @param exchange Exchange address
     * @param tokenAddress Token address
     * @param tokenId Token ID
     * @param amount Amount to sell
     * @param data Additional data for the trade
     * @return payout Amount paid out
     */
    function delegateSell(
        address user,
        address adaptor,
        address exchange,
        address tokenAddress,
        uint256 tokenId,
        uint256 amount,
        bytes calldata data
    ) external override onlyVault nonReentrant returns (uint256 payout) {
        // Get NFT token ID for this position
        uint256 nftTokenId = nftManager.getTokenIdFromTraderPosition(
            exchange, 
            tokenAddress, 
            tokenId, 
            user
        );
        
        require(nftTokenId != 0, "Position not found");
        
        // Get position data
        INonfungiblePredictionManager.PositionData memory position = nftManager.getPosition(nftTokenId);
        
        require(position.active, "Position not active");
        require(position.amount >= amount, "Insufficient position amount");
        
        // Get current price from adaptor
        uint256 currentPrice = IAdaptor(adaptor).getPrice(exchange, tokenAddress, tokenId);
        require(currentPrice > 0, "Invalid price");
        
        // Create trade parameters for the adaptor
        IAdaptor.TradeParams memory params = IAdaptor.TradeParams({
            trader: address(this),
            exchange: exchange,
            tokenAddress: tokenAddress,
            tokenId: tokenId,
            amount: amount,
            isBuy: false,
            data: data
        });
        
        // Build sell payload
        bytes memory payload = IAdaptor(adaptor).buildSell(params);
        
        // Execute the payload using our helper
        bool success = executePayload(adaptor, payload);
        require(success, "Sell execution failed");
        
        // Calculate sale value
        uint256 saleValue = (currentPrice * amount) / DECIMALS_FACTOR;
        
        // Calculate proportional values
        uint256 proportionOfPosition = (amount * PCT_BASE) / position.amount;
        uint256 collateralPortion = (position.collateral * proportionOfPosition) / PCT_BASE;
        uint256 purchaseValuePortion = (position.purchaseValue * proportionOfPosition) / PCT_BASE;
        
        // Calculate total payout
        payout = saleValue + collateralPortion;
        
        // Update position in NFT contract
        if (amount == position.amount) {
            // Full position sale - burn NFT
            nftManager.burnPosition(nftTokenId);
        } else {
            // Partial position sale - update NFT
            uint256 newAmount = position.amount - amount;
            uint256 newCollateral = position.collateral - collateralPortion;
            nftManager.updatePosition(nftTokenId, newAmount, newCollateral);
        }
        
        // Transfer payout to vault (which will transfer to user)
        collateralToken.safeTransfer(vault, payout);
        
        emit PositionSold(nftTokenId, user, amount, payout);
        
        return payout;
    }
    
    /**
     * @notice Add funding to a position
     * @param user User address
     * @param exchange Exchange address
     * @param tokenAddress Token address
     * @param tokenId Token ID
     * @param amount Amount of funding to add
     * @return newCollateral New total collateral amount
     */
    function addFunding(
        address user,
        address exchange,
        address tokenAddress,
        uint256 tokenId,
        uint256 amount
    ) external onlyVault nonReentrant returns (uint256 newCollateral) {
    }
    
    /**
     * @notice Check if position can be managed by this strategy
     * @param exchange Exchange address
     * @param tokenAddress Token address
     * @param tokenId Token ID
     * @return Whether the position is valid for this strategy
     */
    function isValidPosition(
        address exchange,
        address tokenAddress,
        uint256 tokenId
    ) external view override returns (bool) {
        // For this simple strategy, all positions are valid
        return true;
    }
    
    /**
     * @notice Settle (liquidate) a position that is underwater
     * @param nftTokenId NFT token ID representing the position
     * @return reward Reward for the settler (the discounted position)
     */
    function settle(
        address adaptor,
        uint256 nftTokenId
    ) external nonReentrant returns (uint256 reward) {

        INonfungiblePredictionManager.PositionData memory position = nftManager.getPosition(nftTokenId);
        require(position.active, "Position not active");
        // Get current price
        uint256 currentPrice = IAdaptor(adaptor).getPrice(position.exchange, position.tokenAddress, position.tokenId);
        uint256 oldPrice = position.price;
        require(currentPrice > 0, "Invalid price");
        require(currentPrice > oldPrice, "Position not settleable");

        //TODO: Math
        uint256 diff = (position.amount * oldPrice) - (position.amount*currentPrice);
        uint256 a;
        uint256 profit = diff+a;

        ///Sell
        IAdaptor.TradeParams memory params = IAdaptor.TradeParams({
            trader: address(this),
            exchange: position.exchange,
            tokenAddress: position.tokenAddress,
            tokenId: position.tokenId,
            amount: position.amount,
            isBuy: false,
            data: ""
        });

        (address oppsiteTokenAddress, uint256 oppositeTokenId) = IAdaptor(adaptor).getOppositePosition(position.tokenAddress, position.tokenId);
        
        
    }
    

    /**
     * @notice Set collateral requirement
     * @param _collateralRequirement New collateral requirement
     */
    function setCollateralRequirement(uint256 _collateralRequirement) external {
        require(_collateralRequirement <= PCT_BASE, "Invalid collateral requirement");
        
        uint256 oldValue = bettingToValueRate;
        bettingToValueRate = _collateralRequirement;
        
        emit ParameterUpdated("bettingToValueRate", oldValue, _collateralRequirement);
    }
    
}