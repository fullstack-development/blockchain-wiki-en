// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title Queue
 * @notice Library for implementing a queue data structure
 * @dev It can be used as follows:
 * using Queue for Queue.Info;
 * Queue.Info private _queue;
 */
library Queue {
    struct Info {
        uint256 first;
        uint256 last;
        mapping(uint256 => string) items;
    }

    error ZeroQueue();

    /**
     * @notice Add item to queue
     * @param queue Queue storage, represented by the Info structure
     * @param item Item to add to queue
     */
    function enqueue(Info storage queue, string calldata item) external {
        queue.last += 1;

        queue.items[queue.last] = item;
    }

    /**
     * @notice Remove an element from the queue
     * @param queue Queue storage, represented by the Info structure
     * @return item First element in the queue
     */
    function dequeue(Info storage queue) external returns (string memory item) {
        uint256 first = queue.first;
        uint256 last = queue.last;

        if (last <= first) {
            revert ZeroQueue();
        }

        item = queue.items[first + 1];

        delete queue.items[first + 1];
        queue.first += 1;
    }

    /**
     * @notice Number of elements in the queue
     * @param queue Queue storage, represented by the Info structure
     */
    function length(Info storage queue) external view returns (uint256) {
        return queue.last - queue.first;
    }
}