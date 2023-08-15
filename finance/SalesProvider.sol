// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

// Goerli DAI Aggregator Contract Address : 0x0d79df66BE487753B02D015Fb622DED7f0E9798d
// Goerli LINK Aggregator Contract Address : 0x48731cF7e84dc94C5f84577882c14Be11a5B7456
// Goerli USDC Aggregator Contract Address : 0xAb5c49580294Aff77670F839ea425f5b78ab3Ae7
// ["0x0d79df66BE487753B02D015Fb622DED7f0E9798d","0x48731cF7e84dc94C5f84577882c14Be11a5B7456","0xAb5c49580294Aff77670F839ea425f5b78ab3Ae7"]

// Goerli DAI Contract Address: 0x11fE4B6AE13d2a6055C8D9cF65c55bac32B5d844
// Goerli LINK Contract Address: 0x326C977E6efc84E512bB9C30f76E30c160eD06FB
// Goerli USDC Contract Address: 0x07865c6E87B9F70255377e024ace6630C1Eaa37F
// ["0x11fE4B6AE13d2a6055C8D9cF65c55bac32B5d844","0x326C977E6efc84E512bB9C30f76E30c160eD06FB","0x07865c6E87B9F70255377e024ace6630C1Eaa37F"]

// Interface to support ERC20 tokens with decimals
// NOTE: ERC20 tokens without decimal function are not supported by this contract
interface IERC20WithDecimals is IERC20 {
    function decimals() external view returns (uint8);
}

/**
 * @dev Abstract contract to support sales of ERC20 tokens and ETH
 * This contract supports the following types of sales:
 * 1. Fixed price in USD pegged tokens/ETH (using Chainlink price feed)
 * 2. Fixed price in ETH
 * 3. Dutch auction in USD pegged tokens/ETH (using Chainlink price feed)
 * 4. Dutch auction in ETH
 * 
 * This contract does not support tokens without decimals function
 * When using Chainlink price feeds, only price feeds pegged to USD are supported (should we change this?!)
 * 
 * Created by: Westy_Dev
 * Chainlink price feed addresses: https://docs.chain.link/data-feeds/price-feeds/addresses
 */
abstract contract SalesProvider is AccessControl {

    // Define roles for access control
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant SALE_ROLE = keccak256("SALE_ROLE");

    // Modifier to restrict access to admin or sale role
    modifier onlyAdminOrSaleRole() {
        require(hasRole(ADMIN_ROLE, msg.sender) || hasRole(SALE_ROLE, msg.sender), "Must have admin or sale role");
        _;
    }

    // Struct to hold token sale information
    struct TokenSaleInfo {
        uint256 usdPrice18; //USD price in 1e18
        uint8 discount; // discounts are from 0 to 100 provided as % e.g 10 for 10%
        uint16 markup; // markups are from 0 to 65535 provided as % e.g 10 for 10%
        AggregatorV3Interface priceFeed; // price feed for the token - see Chainlink price feed addresses
        uint256 fixedTokenPrice; // Fixed price if applicable
        DutchAuctionInfo dutchAuction; // Dutch auction information
    }

    // Struct to hold Ether sale information
    struct EthSaleInfo {
        uint256 usdPrice18; // Ethereum price in USD in 1e18
        uint256 ethPrice; // Ethereum price in wei
        uint8 discount; // discounts are from 0 to 100
        uint16 markup; // markups are from 0 to 65535
        AggregatorV3Interface priceFeed; // price feed for eth - see Chainlink price feed addresses
        DutchAuctionInfo dutchAuction; // Dutch auction information
    }

    // Struct to hold Dutch auction information
    struct DutchAuctionInfo {
        uint256 startTime; // Auction start time
        uint256 endTime; // Auction end time
        uint256 startPrice; // Initial start price
        uint256 reservePrice; // Price at which the auction will not go lower
    }

    // Struct to hold sale information for tokens and Ether
    struct SaleInfo {
        mapping(IERC20WithDecimals => TokenSaleInfo) tokenSaleInfos; // Token sale info per token
        EthSaleInfo ethSaleInfo; // Ether sale info
    }

    // Mapping to hold sale information for different sale items
    mapping(uint256 => SaleInfo) saleInfo;

    /**
     * @dev Initializes contract and grants `DEFAULT_ADMIN_ROLE` and `SALE_ROLE` to the account that
     * deploys the contract.
     */
    constructor() {
        _setupRole(ADMIN_ROLE, msg.sender);
        _setRoleAdmin(SALE_ROLE, ADMIN_ROLE);
    }

    /**
     * @dev Sets the price feed info for a token sale.
     * @param _saleId The sale id
     * @param _token The token to set the price feed for
     * @param _usdPrice The USD price in 1e18
     * @param _priceFeed The chainlink price feed address
     */
    function setTokenSalePriceFeedInfo(uint256 _saleId, IERC20WithDecimals _token, uint256 _usdPrice, AggregatorV3Interface _priceFeed) public virtual onlyAdminOrSaleRole {  
        saleInfo[_saleId].tokenSaleInfos[_token].usdPrice18 = _usdPrice * 1e18;
        saleInfo[_saleId].tokenSaleInfos[_token].priceFeed = _priceFeed;
    }

    /**
     * @dev Sets the fixed price info for a token sale.
     * @param _saleId The sale id
     * @param _token The token to set the price for
     * @param _fixedTokenPrice The fixed token price
     */
    function setTokenSaleFixedPriceInfo(uint256 _saleId, IERC20WithDecimals _token, uint256 _fixedTokenPrice) public virtual onlyAdminOrSaleRole {
        saleInfo[_saleId].tokenSaleInfos[_token].fixedTokenPrice = _fixedTokenPrice;
    }

    /**
     * @dev Sets the discount for a token sale.
     * @param _saleId The sale id
     * @param _token The token to set the discount for
     * @param _discount The discount (0% to 100%)
     */
    function setTokenSaleDiscount(uint256 _saleId, IERC20WithDecimals _token, uint8 _discount) public virtual onlyAdminOrSaleRole {
        require(_discount <= 100, "Discount must be between 0 and 100");
        saleInfo[_saleId].tokenSaleInfos[_token].discount = _discount;
    }

    /**
     * @dev Sets the markup for a token sale.
     * @param _saleId The sale id
     * @param _token The token to set the markup for
     * @param _markup The markup (0% to 65535%)
     */
    function setTokenSaleMarkup(uint256 _saleId, IERC20WithDecimals _token, uint16 _markup) public virtual onlyAdminOrSaleRole {
        saleInfo[_saleId].tokenSaleInfos[_token].markup = _markup;
    }

    /**
     * @dev Sets the Dutch auction info for a token sale.
     * @param _saleId The sale id
     * @param _token The token to set the Dutch auction info for
     * @param _startTime The start time of the auction
     * @param _endTime The end time of the auction
     * @param _startPrice The start price of the auction
     * @param _reservePrice The reserve price of the auction
     */
    function setTokenSaleDutchAuctionInfo(uint256 _saleId, IERC20WithDecimals _token, uint256 _startTime, uint256 _endTime, uint256 _startPrice, uint256 _reservePrice) public virtual onlyAdminOrSaleRole {
        require(_startTime < _endTime, "Start time must be before end time");
        require(_startPrice >= _reservePrice, "Start price must be greater than or equal to reserve price");
        
        DutchAuctionInfo memory dutchAuctionInfo = DutchAuctionInfo({startTime: _startTime, endTime: _endTime,
                                                                     startPrice: _startPrice, reservePrice: _reservePrice });

        saleInfo[_saleId].tokenSaleInfos[_token].dutchAuction = dutchAuctionInfo;
    }

    /**
     * @dev Sets the price feed info for an Ether sale.
     * @param _saleId The sale id
     * @param _usdPrice The USD price in 1e18
     * @param _priceFeed The chainlink price feed address for Eth/USD
     */
    function setEthPriceFeedInfo(uint256 _saleId, uint256 _usdPrice, AggregatorV3Interface _priceFeed) public virtual onlyAdminOrSaleRole {
        saleInfo[_saleId].ethSaleInfo.usdPrice18 = _usdPrice * 1e18;
        saleInfo[_saleId].ethSaleInfo.priceFeed = _priceFeed;
    }

    /**
     * @dev Sets the fixed price info for an Ether sale.
     * @param _saleId The sale id
     * @param _etherPrice The fixed Ether price
     */
    function setFixedEtherPrice(uint256 _saleId, uint256 _etherPrice) public virtual onlyAdminOrSaleRole {
        saleInfo[_saleId].ethSaleInfo.ethPrice = _etherPrice;
    }

    /**
     * @dev Sets the discount for an Ether sale.
     * @param _saleId The sale id
     * @param _discount The discount (0% to 100%)
     */
    function setEtherSaleDiscount(uint256 _saleId, uint8 _discount) public virtual onlyAdminOrSaleRole {
        require(_discount <= 100, "Discount must be between 0 and 100");
        saleInfo[_saleId].ethSaleInfo.discount = _discount;
    }

    /**
     * @dev Sets the markup for an Ether sale.
     * @param _saleId The sale id
     * @param _markup The markup (0% to 65535%)
     */
    function setEtherSaleMarkup(uint256 _saleId, uint16 _markup) public virtual onlyAdminOrSaleRole {
        saleInfo[_saleId].ethSaleInfo.markup = _markup;
    }

    /**
     * @dev Gets the latest price from the price feed for a specific token.
     * @param _saleId The sale id
     * @param _token The token to get the price for
     */
    function getLatestTokenPrice(uint256 _saleId, IERC20WithDecimals _token) public view returns (int256) {
        (, int256 price, , , ) = saleInfo[_saleId].tokenSaleInfos[_token].priceFeed.latestRoundData();
        return price;
    }

    /**
     * @dev Gets the latest price from the price feed for Ether.
     * @param _saleId The sale id
     */
    function getLatestEthPrice(uint256 _saleId) public view returns (int256) {
        (, int256 price, , , ) = saleInfo[_saleId].ethSaleInfo.priceFeed.latestRoundData();
        return price;
    }

    /**
     * @dev Gets the price feed name for a specific token.
     * @param _saleId The sale id
     * @param _token The token to get the price feed name for
     */
    function getTokenPriceFeedName(uint256 _saleId, IERC20WithDecimals _token) public view returns (string memory) {
        return saleInfo[_saleId].tokenSaleInfos[_token].priceFeed.description();
    }

    /**
     * @dev Gets the price feed name for Ether.
     * @param _saleId The sale id
     */
    function getEthPriceFeedName(uint256 _saleId) public view returns (string memory) {
        return saleInfo[_saleId].ethSaleInfo.priceFeed.description();
    }

    /**
     * @dev Obtains the token price in token decimalisation for a purchase pegged to USD.
     * Applies discount and markup if applicable.
     * 
     * @param _saleId The sale id
     * @param _token The token to get the price for
     */
    function purchaseWithToken(uint256 _saleId, IERC20WithDecimals _token) public view virtual returns (uint256) {

        TokenSaleInfo memory tokenSaleInfo = saleInfo[_saleId].tokenSaleInfos[_token];
        require(tokenSaleInfo.usdPrice18 > 0, "USD peg price must be greater than 0");
        require(tokenSaleInfo.priceFeed != AggregatorV3Interface(address(0)), "There must be a price feed for this purchase");

        uint256 priceInTokenDecimals = getPriceInTokenAmountForPurchase(_saleId, _token);

        priceInTokenDecimals = applyDiscountAndMarkup(priceInTokenDecimals, tokenSaleInfo.discount, tokenSaleInfo.markup);

        return priceInTokenDecimals;
    }

    /**
     * @dev Obtains the price in fixed token amount for a purchase.
     * Applies discount and markup if applicable.
     * 
     * @param _saleId The sale id
     * @param _token The token to get the price for
     */
    function purchaseWithFixedToken(uint256 _saleId, IERC20WithDecimals _token) public view virtual returns (uint256) {
        
        TokenSaleInfo memory tokenSaleInfo = saleInfo[_saleId].tokenSaleInfos[_token];

        require(tokenSaleInfo.fixedTokenPrice > 0, "There must be a fixed token price for this purchase");

        uint256 priceInTokens = tokenSaleInfo.fixedTokenPrice;

        priceInTokens = applyDiscountAndMarkup(priceInTokens, tokenSaleInfo.discount, tokenSaleInfo.markup);

        return priceInTokens;
    }

    /**
     * @dev Obtains the current price in token amount for a dutch auction purchase.
     * @param _saleId The sale id
     * @param _token The token to get the price for
     */
    function purchaseWithDutchAuctionToken(uint256 _saleId, IERC20WithDecimals _token) public view virtual returns (uint256) {

        TokenSaleInfo memory tokenSaleInfo = saleInfo[_saleId].tokenSaleInfos[_token];
        require(tokenSaleInfo.dutchAuction.startPrice > 0, "There must be a Dutch auction start price for this purchase");
        require(tokenSaleInfo.dutchAuction.startTime <= block.timestamp, "Dutch auction hasn't started yet");
        require(tokenSaleInfo.dutchAuction.endTime >= block.timestamp, "Dutch auction has ended");

        uint256 currentDAPrice = calculateDutchAuctionPrice(tokenSaleInfo.dutchAuction);

        return currentDAPrice;
    }

    /**
     * @dev Obtains the Ether price for a purchase pegged to USD.
     * Applies discount and markup if applicable.
     * 
     * @param _saleId The sale id
     */
    function purchaseWithEth(uint256 _saleId) public view virtual returns (uint256) {

        EthSaleInfo memory ethSaleInfo = saleInfo[_saleId].ethSaleInfo;
        require(ethSaleInfo.usdPrice18 > 0, "There must be a USD peg price for this purchase");
        require(ethSaleInfo.priceFeed != AggregatorV3Interface(address(0)), "There must be a price feed for this purchase");

        uint256 ethPrice = getPriceInEthAmountForPurchase(_saleId);

        ethPrice = applyDiscountAndMarkup(ethPrice, ethSaleInfo.discount, ethSaleInfo.markup);

        return ethPrice;
    }

    /**
     * @dev Obtains the price in fixed Ether amount for a purchase.
     * Applies discount and markup if applicable.
     * 
     * @param _saleId The sale Id
     */
    function purchaseWithFixedEth(uint256 _saleId) public view virtual returns (uint256) {
        
        EthSaleInfo memory ethSaleInfo = saleInfo[_saleId].ethSaleInfo;

        require(ethSaleInfo.ethPrice > 0, "There must be a fixed token price for this purchase");

        uint256 ethPrice = ethSaleInfo.ethPrice;

        ethPrice = applyDiscountAndMarkup(ethPrice, ethSaleInfo.discount, ethSaleInfo.markup);

        return ethPrice;
    }

    /**
     * @dev Obtains the current price in Ether amount for a dutch auction purchase.
     * @param _saleId The sale id
     */
    function purchaseWithDutchAuctionEth(uint256 _saleId) public view virtual returns (uint256) {

        EthSaleInfo memory ethSaleInfo = saleInfo[_saleId].ethSaleInfo;
        require(ethSaleInfo.dutchAuction.startPrice > 0, "There must be a Dutch auction start price for this purchase");
        require(ethSaleInfo.dutchAuction.startTime <= block.timestamp, "Dutch auction hasn't started yet");
        require(ethSaleInfo.dutchAuction.endTime >= block.timestamp, "Dutch auction has ended");

        uint256 currentPrice = calculateDutchAuctionPrice(ethSaleInfo.dutchAuction);

        return currentPrice;
    }

    /**
     * @dev Helper function to obtain the price in token decimals for a purchase pegged to USD.
     * @param _saleId The sale id
     * @param _token The token to get the price for
     */
    function getPriceInTokenAmountForPurchase(uint256 _saleId, IERC20WithDecimals _token) public view virtual returns (uint256) {
        uint256 priceFeedUSDTokenPrice = uint256(getLatestTokenPrice(_saleId, _token));
        // e.g 100000000 8 decimals
        uint256 priceFeedDecimals = saleInfo[_saleId].tokenSaleInfos[_token].priceFeed.decimals();
        // e.g 8
        uint256 priceFeedDifferenceDecimals = 18 - priceFeedDecimals;
        // e.g 10
        uint256 USDTokenPrice18 = priceFeedUSDTokenPrice * 10 ** priceFeedDifferenceDecimals;
        // 1000000000000000000

        //Multiply before dividing to keep precision
        //Also we want to multiply by 10 ** 18 to get the price in 18 decimals
        uint256 numberOfTokens18 = (((saleInfo[_saleId].tokenSaleInfos[_token].usdPrice18)  * 10 ** 18) / USDTokenPrice18);

        //Get token decimals
        uint256 tokenDecimals = _token.decimals();

        //Get the difference in decimals between the token and 18
        uint256 tokenDifferenceDecimals = 18 - tokenDecimals;

        //Divide our tokens in 18 by 10 ** difference to get the price in token decimals
        uint256 priceInTokenDecimals = numberOfTokens18 / (10 ** tokenDifferenceDecimals);

        return priceInTokenDecimals;
    }

    /**
     * @dev Helper function to obtain the ether price for a purchase pegged to USD.
     * @param _saleId The sale id
     */
    function getPriceInEthAmountForPurchase(uint256 _saleId) public view virtual returns (uint256) {
        uint256 priceFeedUSDTokenPrice = uint256(getLatestEthPrice(_saleId));
        // e.g 100000000 8 decimals
        uint256 priceFeedDecimals = saleInfo[_saleId].ethSaleInfo.priceFeed.decimals();
        // e.g 8
        uint256 priceFeedDifferenceDecimals = 18 - priceFeedDecimals;
        // e.g 10
        uint256 USDTokenPrice18 = priceFeedUSDTokenPrice * 10 ** priceFeedDifferenceDecimals;
        // 1000000000000000000

        //Multiply before dividing to keep precision
        //Also we want to multiply by 10 ** 18 to get the price in 18 decimals
        uint256 ethPriceInWei = (((saleInfo[_saleId].ethSaleInfo.usdPrice18)  * 10 ** 18) / USDTokenPrice18);

        return ethPriceInWei;
    }

    /**
     * @dev Helper function to calculate the current price for a Dutch auction.
     * By default this is a linearly interpolated price based on the difference between startPrice and reservePrice
     * Can be overridden to implement other algorithms such as exponential decay
     * 
     * @param _auction The Dutch auction info struct containing the auction information
     */
    function calculateDutchAuctionPrice(DutchAuctionInfo memory _auction) public virtual view returns (uint256) {
         if(block.timestamp <= _auction.startTime) {
            return _auction.startPrice;
        } else if(block.timestamp >= _auction.endTime) {
            return _auction.reservePrice;
        } else {
            uint256 timePassed = block.timestamp - _auction.startTime;
            uint256 totalAuctionTime = _auction.endTime - _auction.startTime;

            // Linearly decreases the price from startPrice to reservePrice as the auction goes on
            uint256 currentPrice = _auction.startPrice - ((_auction.startPrice - _auction.reservePrice) * timePassed / totalAuctionTime);

            return currentPrice;
        }
    }

    /**
     * @dev Helper function to apply discount and markup to a price.
     * @param _price The price to apply the discount and markup to
     * @param _discount The discount (0% to 100%)
     * @param _markup The markup (0% to 65535%)
     */
    function applyDiscountAndMarkup(uint256 _price, uint8 _discount, uint16 _markup) public virtual pure returns (uint256) {
        return (_price * (100 - _discount + _markup)) / 100;
    }
}