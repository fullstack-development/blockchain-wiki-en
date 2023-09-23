// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/// @notice Sorting direction
enum SortDirection {
    ASC,
    DESC
}

/**
 * @title Selection Sort
 * @notice This contract implements the sort() function for selection sorting of elements in an array
 */
contract SelectionSort {
    /**
     * @notice Selection Sort
     * @param arr Unsorted array of numbers
     * @param sortDirection Sorting direction
     */

    function sort(uint256[] memory arr, SortDirection sortDirection)
        external
        pure
        returns
        (uint256[] memory sortedArr)
    {
        /// Declare an array to store the sorted elements of the original array
        sortedArr = new uint256[](arr.length);

        for (uint256 i = 0; i < arr.length; i++) {
            /// Sorting in ascending order
            if (sortDirection == SortDirection.ASC) {
                uint256 index = _findSmallest(arr);
                sortedArr[i] = arr[index];

                /// Equivalent to removing an element from the array or swapping elements
                arr[index] = type(uint256).max;
            }

            /// Sorting in descending order
            if (sortDirection == SortDirection.DESC) {
                uint256 index = _findBiggest(arr);
                sortedArr[i] = arr[index];

                /// Equivalent to removing from the array or swapping elements
                arr[index] = type(uint256).min;
            }
        }
    }

    /**
     * @notice Find the smallest value in the array
     * @param arr Unsorted array of numbers
     */
    function _findSmallest(uint256[] memory arr) private pure returns (uint256 smallestIndex) {
        uint256 smallest = arr[0];
        smallestIndex = 0;

        for (uint256 i = 1; i < arr.length; i++) {
            if (arr[i] < smallest) {
                smallest = arr[i];
                smallestIndex = i;
            }
        }
    }

    /**
     * @notice Find the largest value in the array
     * @param arr Unsorted array of numbers
     */
    function _findBiggest(uint256[] memory arr) private pure returns (uint256 biggestIndex) {
        uint256 biggest = arr[0];
        biggestIndex = 0;

        for (uint256 i = 1; i < arr.length; i++) {
            if (arr[i] > biggest) {
                biggest = arr[i];
                biggestIndex = i;
            }
        }
    }
}
