// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @notice Storage for the router
 * @dev Contains information about the owner and the list of facets for function selectors
 */
abstract contract RouterStorage {
    struct CoreStorage {
        address owner;
        mapping(bytes4 selector => address facet) selectorToFacet;
    }

    // keccak256(abi.encode("the-same-pendle-routing"))
    bytes32 private constant STORAGE_LOCATION = 0x25e5c12553aca6bac665d66f71e8380eae2ff9ef17f649227265212ec2f7f613;

    function _getCoreStorage() internal pure returns (CoreStorage storage $) {
        assembly {
            $.slot := STORAGE_LOCATION
        }
    }
}
