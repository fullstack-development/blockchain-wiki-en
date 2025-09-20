// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Proxy} from "@openzeppelin/contracts/proxy/Proxy.sol";

import {RouterStorage} from "./RouterStorage.sol";
import {IActionStorage} from "./ActionStorage.sol";

/**
 * @notice Router smart contract that delegates calls to facets based on selectors
 * @dev Acts as a proxy contract that uses delegatecall to execute functions on different smart contracts (facets)
 */
contract Router is Proxy, RouterStorage {
    error InvalidSelector();

    constructor(address actionStorage) {
        RouterStorage.CoreStorage storage $ = _getCoreStorage();
        $.owner = msg.sender;
        // Register the selector of the `setSelectorToFacets` function in `ActionStorage` for future addition of new function selectors and the addresses of smart contracts where these functions are implemented  
        $.selectorToFacet[IActionStorage.setSelectorToFacets.selector] = actionStorage;
    }

    function _implementation() internal view override returns (address facet) {
        RouterStorage.CoreStorage storage $ = _getCoreStorage();

        // Retrieve the facet address for the function selector from the call
        facet = $.selectorToFacet[msg.sig];
        if (facet == address(0)) {
            revert InvalidSelector();
        }
    }
}
