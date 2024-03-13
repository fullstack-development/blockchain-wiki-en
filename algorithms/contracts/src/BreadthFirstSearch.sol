// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title Breadth-First Search
 * @notice The contract implements a search() function that performs breadth-first search.
 * @dev To organize the search, you need to create a graph.
 * The addNode() function creates nodes in the graph.
 * The addEdge() function creates edges in the graph (connections between nodes).
 * Important! All nodes in the graph are numbered in the order they are added.
 * This is necessary to know the total number of nodes for conducting the search and keeping track of visited nodes.
 */

contract BreadthFirstSearch {
    using Counters for Counters.Counter;

    struct Node {
        string name;
        uint256[] neighbors;
    }

    mapping(uint256 => Node) private _graph;
    Counters.Counter private _nodeCount;

    /**
     * @notice Creates nodes in the graph
     * @param name The name of the node
     */
    function addNode(string memory name) external {
        Node storage newNode = _graph[_nodeCount.current()];
        newNode.name = name;

        _nodeCount.increment();
    }

    /**
     * @notice Adds a connection between nodes in the graph
     * @param from The starting node of the connection
     * @param to The ending node of the connection
     */
    function addEdge(uint256 from, uint256 to) external {
        _graph[from].neighbors.push(to);
    }

    /**
     * @notice Invokes the breadth-first search algorithm
     * @param start The identifier of the node to start the search from
     * @param goal The identifier of the node to find
     * @dev Essentially, this function checks the possibility of reaching one node in the graph from another
     */
    function search(uint256 start, uint256 goal) external view returns (bool) {
        /// An array to keep track of visited nodes. This helps to prevent cycling
        bool[] memory visited = new bool[](_nodeCount.current());

        /// An array to organize the search queue.
        /// As we check each node, we will add the connections of this node to the end of the queue for later examination.
        uint256[] memory queue = new uint256[](_nodeCount.current());

        /// Counters for navigating through the queue array. They will help in adding nodes to the queue and extracting them from the queue.
        uint256 front = 0;
        uint256 back = 0;

        /// Place the initial element in the queue
        queue[back++] = start;

        /// Mark the node as visited
        visited[start] = true;

        while (front != back) {
            uint256 current = queue[front++];

            if (current == goal) {
                /// If the target value equals the value of the graph node, the value is found
                return true;
            }

            /// Extract all neighboring nodes of the examined graph node
            uint256[] memory neighbors = _graph[current].neighbors;

            for (uint256 i = 0; i < neighbors.length; ++i) {
                uint256 neighbor = neighbors[i];

                if (!visited[neighbor]) {
                    /// Mark the neighboring node as checked
                    visited[neighbor] = true;

                    /// Add the neighboring node to the queue
                    queue[back++] = neighbor;
                }
            }
        }

        return false;
    }
}
