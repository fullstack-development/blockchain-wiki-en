// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IOracle} from "./interfaces/IOracle.sol";
import {RequestType} from "./utils/Constants.sol";

/**
 * @notice Example of a contract that needs to receive off-chain price information.
 * @dev Obtains off-chain data through a specialized Oracle contract.
 */
contract Client {
/// @notice Instance of the Oracle contract.
IOracle private _oracle;

    /// @notice Private variable for storing off-chain information about the price.
    uint256 private _price;

    event OracleSet(address oracle);
    event PriceSet(uint256 price);

    error OnlyOracle();

    modifier onlyOracle {
        if (msg.sender != address(_oracle)) {
            revert OnlyOracle();
        }

        _;
    }

    constructor(address oracle) {
        _oracle = IOracle(oracle);

        emit OracleSet(oracle);
    }

    /**
     * @notice Makes a request for off-chain data to the Oracle contract.
 * @param oracleNode The address on behalf of which the oracle node can interact with the Oracle contract.
     * Oracle node находится в off-chain пространстве
     */
    function requestPrice(address oracleNode) external {
        bytes memory data = abi.encode(RequestType.GET_PRICE);

        _oracle.createRequest(
            oracleNode,
            data,
            IOracle.Callback({
                to: address(this),
                functionSelector: Client.setPrice.selector
            })
        );
    }

    function getPrice() external view returns (uint256) {
        return _price;
    }

    /**
     * @notice Function that will be called by the Oracle contract to update the price information.
 * @param data A set of encoded data containing information about the price.
     */
    function setPrice(bytes memory data) external onlyOracle {
        uint256 price = abi.decode(data, (uint256));

        _price = price;

        emit PriceSet(price);
    }
}
