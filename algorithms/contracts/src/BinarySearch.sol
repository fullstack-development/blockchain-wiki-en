// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/**
 * @title Binary Search
 * @notice The contract implements the binarySearch() function, which performs a search for an element in a sorted list
 */

contract BinarySearch {
    uint256[] private _list;

    /// @notice Return when the desired element is not found in the list
    error None();

    /// @notice Return when the size of the created list is zero
    error ZeroSize();

    constructor(uint256 size) {
        if (size == 0) {
            revert ZeroSize();
        }

        _createList(size);
    }

   /**
 * @notice Binary search
 * @param desiredValue The value being searched for
 */

    function binarySearch(uint256 desiredValue) external view returns (uint256) {
    /// Variables to store the boundaries of the list being searched
        uint256 start = 0;
        uint256 end = _list.length - 1;

        /// Continue searching until the desired element is found
        while (start <= end) {
            uint256 middle = (start + end) / 2;
            uint256 guessedValue = _list[middle];

            if (guessedValue == desiredValue) {
                return middle; /// Value found
            }

            if (desiredValue < guessedValue) {
                end = middle - 1; /// The desired element is in the left half
            } else {
                start = middle + 1; /// The desired element is in the right half
            }
        }

        revert None();
    }

    /**
     * @notice Initialize a sorted list
     * @param size The size of the sorted list to be created
     */
    function _createList(uint256 size) private {
        for (uint256 i = 0; i < size; i++) {
            _list.push(i);
        }
    }
}
