// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "chainlink/v0.8/interfaces/AggregatorV3Interface.sol";
import "openzeppelin-contracts/utils/math/SafeCast.sol";

/// @notice Contract for obtaining the token's price based on the Chainlink PriceFeed.
contract PriceConsumer {
    /// @notice We are connecting the wonderful library that allows converting Int to Uint.
    using SafeCast for int256;

    AggregatorV3Interface internal priceFeed;

    /**
     * Network: Sepolia
     * Aggregator: BTC/USD
     * Address: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43
     * @dev The example will work on the Sepolia network for the corresponding Aggregator contract.
     */
    constructor(address aggregator) {
        priceFeed = AggregatorV3Interface(aggregator);
    }

    /**
     * @notice Returns the price of the Bitcoin token relative to USD.
     */
    function getLatestPrice() public view returns (uint256) {
        (
            /* uint80 roundID */,
            int price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();

        return price.toUint256();
    }
}
