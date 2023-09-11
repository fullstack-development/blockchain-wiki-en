// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {StableCoin} from "./StableCoin.sol";
import {OracleLib} from "./libraries/OracleLib.sol";

/**
 * @title Stablecoin Engine
 * @notice This contract is required to manage mint() and burn() of the stablecoin.
 * This mechanism is necessary to maintain the peg of 1 DSC = 1$.
 *
 * Important! Our system must always be overcollateralized.
 * Threshold: 150%
 */
contract Engine is ReentrancyGuard {
    using OracleLib for AggregatorV3Interface;

    uint256 public constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 public constant PRECISION = 1e18;
    uint256 public constant LIQUIDATION_THRESHOLD = 50; // Это значение будет требовать 200% сверх обеспечения.
    uint256 public constant LIQUIDATION_PRECISION = 100;
    uint256 public constant LIQUIDATION_BONUS = 10; // 10%
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;

    mapping(address token => address priceFeeds) private _priceFeeds;
    mapping(address user => mapping(address token => uint256 amount)) private _collateralDeposited;
    mapping(address user => uint256 amountDscMinted) private _dscMinted;
    address[] private _collateralTokens;

    StableCoin private _dsc;

    event CollateralDeposited(address indexed user, address indexed collateralToken, uint256 collateralAmount);
    event CollateralRedeemed(
        address indexed redeemedFrom,
        address indexed redeemedTo,
        address indexed collateralToken,
        uint256 collateralAmount
    );

    error ZeroAmount();
    error TokenAddressesAndPriceFeedAddressesShouldBeSameLength();
    error NotAllowedToken();
    error TransferFailed();
    error BreaksHealthFactor(uint256 healthFactor);
    error MintFailed();
    error HealthFactorIsPositive();
    error HealthFactorNotImproved();

    modifier notZeroAmount(uint256 amount) {
        if (amount == 0) {
            revert ZeroAmount();
        }

        _;
    }

    modifier isAllowedToken(address token) {
        if (_priceFeeds[token] == address(0)) {
            revert NotAllowedToken();
        }

        _;
    }

    constructor(address[] memory tokens, address[] memory priceFeeds, address dsc) {
        if (tokens.length != priceFeeds.length) {
            revert TokenAddressesAndPriceFeedAddressesShouldBeSameLength();
        }

        for (uint256 i = 0; i < tokens.length; i++) {
            _priceFeeds[tokens[i]] = priceFeeds[i];
            _collateralTokens.push(tokens[i]);
        }

        _dsc = StableCoin(dsc);
    }

    // region - External and public functions -

    /**
     * @notice Allows sending collateral to receive the stablecoin
     * @param collateralToken The address of the collateral token
     * @param collateralAmount The amount of collateral to deposit
     * @param amountToMint The amount to mint the stablecoin
     */
    function depositCollateralAndMintDsc(address collateralToken, uint256 collateralAmount, uint256 amountToMint)
        external
    {
        depositCollateral(collateralToken, collateralAmount);
        mintDsc(amountToMint);
    }

    /**
     * @notice Allows depositing collateral to secure the stablecoin
     * @param collateralToken The address of the collateral token
     * @param collateralAmount The amount of collateral to deposit
     */
    function depositCollateral(address collateralToken, uint256 collateralAmount)
        public
        notZeroAmount(collateralAmount)
        isAllowedToken(collateralToken)
        nonReentrant
    {
        _collateralDeposited[msg.sender][collateralToken] += collateralAmount;

        bool success = IERC20(collateralToken).transferFrom(msg.sender, address(this), collateralAmount);

        if (!success) {
            revert TransferFailed();
        }

        emit CollateralDeposited(msg.sender, collateralToken, collateralAmount);
    }

    /**
     * @notice Allows you to retrieve collateral in exchange for stablecoin
     * @param collateralToken The address of the collateral token
     * @param collateralAmount The amount of collateral being deposited
     * @param amountToBurn The amount to burn in stablecoin
     */
    function redeemCollateralAndBurnDsc(address collateralToken, uint256 collateralAmount, uint256 amountToBurn)
        external
    {
        // First, burn the stablecoin
        burnDsc(amountToBurn);
        redeemCollateral(collateralToken, collateralAmount);
    }

    /**
     * @notice Allows you to retrieve collateral
     * @param collateralToken The address of the collateral token
     * @param collateralAmount The amount of collateral being deposited
     */
    function redeemCollateral(address collateralToken, uint256 collateralAmount)
        public
        notZeroAmount(collateralAmount)
        isAllowedToken(collateralToken)
        nonReentrant
    {
        _redeemCollateral(collateralToken, collateralAmount, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @notice Минтит стейблкоин
     * @param amountToMint The amount to mint the stablecoin
     */
    function mintDsc(uint256 amountToMint) public notZeroAmount(amountToMint) nonReentrant {
        _dscMinted[msg.sender] += amountToMint;

        _revertIfHealthFactorIsBroken(msg.sender);

        bool minted = _dsc.mint(msg.sender, amountToMint);
        if (!minted) {
            revert MintFailed();
        }
    }

    /**
     * @notice Burns the stablecoin
     * @param amountToBurn The amount to burn the stablecoin
     */
    function burnDsc(uint256 amountToBurn) public notZeroAmount(amountToBurn) nonReentrant {
        _burnDsc(amountToBurn, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @notice Allows liquidating a user's collateral and receiving a reward
     * @param collateralToken The address of the collateral token
     * @param user The user whose collateral can be liquidated due to insufficient collateralization
     * @param debtToCover The amount of stablecoin to be burned to adjust the user's health factor
     */
    function liquidate(address collateralToken, address user, uint256 debtToCover)
        external
        notZeroAmount(debtToCover)
        nonReentrant
    {
        uint256 startingUserHealthFactor = _healthFactor(user);

        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert HealthFactorIsPositive();
        }

        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateralToken, debtToCover);
        uint256 bonusCollateral = tokenAmountFromDebtCovered * LIQUIDATION_BONUS / LIQUIDATION_PRECISION;

        uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusCollateral;

        _redeemCollateral(collateralToken, totalCollateralToRedeem, user, msg.sender);

        _burnDsc(debtToCover, user, msg.sender);

        uint256 endingUserHealthFactor = _healthFactor(user);

        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert HealthFactorNotImproved();
        }

        _revertIfHealthFactorIsBroken(msg.sender);
    }

    // endregion

    // region - Public and external view functions -

    /**
     * @notice Returns the total collateral amount in USD
     * @param user The user for whom to calculate the collateral
     * @dev The amount is calculated for each token that can be used as collateral on the protocol
     */
    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        for (uint256 i = 0; i < _collateralTokens.length; i++) {
            address token = _collateralTokens[i];
            uint256 amount = _collateralDeposited[user][token];

            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
    }

    /**
     * @notice Returns the amount in USD
     * @param token The token address for which the amount needs to be converted to USD
     * @param amount The amount of the token
     * @dev The USD amount is calculated based on the obtained price from the Chainlink oracle
     */
    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();

        return uint256(price) * ADDITIONAL_FEED_PRECISION * amount / PRECISION;
    }

    /**
     * @notice Returns the equivalent amount of tokens in USD
     * @param token The token address for which the amount should be converted to USD
     * @param usdAmount The amount in USD, in wei format
     * @dev Token to USD conversion is determined using data from the Chainlink oracle
     */
    function getTokenAmountFromUsd(address token, uint256 usdAmount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();

        return (usdAmount * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

    /**
     * @notice Returns the health factor
     * @param user The user's address for which to retrieve the health factor
     * @dev The health factor indicates the possibility of liquidating a user's collateral
     */
    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }

    /**
     * @notice Returns the addresses of tokens allowed for use as collateral
     */
    function getCollateralTokens() external view returns (address[] memory) {
        return _collateralTokens;
    }

    /**
     * @notice Returns the address of the Chainlink price feed for the token
     */
    function getCollateralTokenPriceFeed(address token) external view returns (address) {
        return _priceFeeds[token];
    }

    /**
     * @notice Returns the collateral amount deposited by the user on the protocol in the specified token
     * @param user The user's address for whom the collateral amount is requested
     * @param token The address of the token for which the collateral amount needs to be returned
     */

    function getCollateralBalanceOfUser(address user, address token) external view returns (uint256) {
        return _collateralDeposited[user][token];
    }

    /**
     * @notice Returns information about the account: the total amount of stablecoin and the collateral amount in USD
     * @param user The user's address for whom to retrieve account information
     */
    function getAccountInformation(address user)
        external
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        (totalDscMinted, collateralValueInUsd) = _getAccountInformation(user);
    }

    // endregion

    // region - Private and internal view functions -

    function _redeemCollateral(address collateralToken, uint256 collateralAmount, address from, address to) private {
        _collateralDeposited[from][collateralToken] -= collateralAmount;

        bool success = IERC20(collateralToken).transfer(to, collateralAmount);

        if (!success) {
            revert TransferFailed();
        }

        emit CollateralRedeemed(from, to, collateralToken, collateralAmount);
    }

    function _burnDsc(uint256 amountToBurn, address onBehalfOf, address from) private {
        _dscMinted[onBehalfOf] -= amountToBurn;

        bool success = _dsc.transferFrom(from, address(this), amountToBurn);
        if (!success) {
            revert TransferFailed();
        }

        _dsc.burn(amountToBurn);
    }

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        totalDscMinted = _dscMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    /**
     * @notice Returns the liquidation factor of a user's collateral
     * @dev If the factor for a user is below 1, their collateral can be liquidated
     * LIQUIDATION_THRESHOLD = 50 // Essentially, this is the requirement that you can borrow a maximum of 50% of the collateral
     * or conversely, the requirement that the borrowed stablecoin must have collateral of 200%
     * LIQUIDATION_PRECISION = 100
     * So, for example, if the total collateral = $1000. Then the maximum you can borrow is 500 stablecoins.
     * Or, to borrow 500 stablecoins, you need to have collateral = $1000. This is equivalent to 200%.
     * You can check this by substituting values into the formula of the function:
     * threshold = totalCollateral * 0.5 / totalMinted.
     * If threshold < 1, liquidation is possible, otherwise not.
     */
    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);

        if (totalDscMinted == 0) {
            return type(uint256).max;
        }

        uint256 collateralAdjustedForThreshold = collateralValueInUsd * LIQUIDATION_THRESHOLD / LIQUIDATION_PRECISION;

        return collateralAdjustedForThreshold * PRECISION / totalDscMinted;
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);

        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert BreaksHealthFactor(userHealthFactor);
        }
    }

    // endregion
}
