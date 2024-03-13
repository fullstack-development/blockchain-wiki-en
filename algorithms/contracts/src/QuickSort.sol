// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/**
 * @title Quick Sort
 * @notice This contract implements the sort() function,
 * which performs the quicksort algorithm for an array of numbers
 */

contract QuickSort {
    error ArrayZero();

    /**
     * @notice Сортирует массив чисел
     * @param arr Массив чисел
     */
    function sort(uint256[] memory arr) external returns(uint256[] memory) {
        if (arr.length == 0) {
            revert ArrayZero();
        }

        /// Recursively execute quicksort.
/// For the initial call, specify the entire array range.
       _quickSort(arr, int256(0), int256(arr.length - 1));

       return arr;
    }

    /**
     * @notice Private quicksort function used for recursive calls.
* @param arr Array of numbers
* @param left Index of the left boundary of the array
* @param right Index of the right boundary of the array
     */
    function _quickSort(uint256[] memory arr, int256 left, int256 right) private {
        int256 i = left;
        int256 j = right;

        if (i==j) {
            return;
        }

* @notice Select the pivot element from the middle of the array
        uint256 pivot = arr[uint256(left + (right - left) / 2)];

        while (i <= j) {
            /// Find the index of an element greater than the pivot.
/// This element should be to the left of the pivot, but it currently is to the right.

            while (arr[uint256(i)] < pivot) {
                i++;
            }

           /// Find the index of an element smaller than the pivot.
/// This element should be to the right of the pivot, but it currently is to the left.

            while (pivot < arr[uint256(j)]) {
                j--;
            }

            if (i <= j) {
/// Swap the found elements.
                (arr[uint256(i)], arr[uint256(j)]) = (arr[uint256(j)], arr[uint256(i)]);

/// Reduces the range for the recursive call.
                i++;
                j--;
            }
        }

/// Make a recursive call.
        if (left < j) {
            _quickSort(arr, left, j);
        }

        if (i < right) {
            _quickSort(arr, i, right);
        }
    }
}
