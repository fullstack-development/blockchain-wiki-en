// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/**
 * @title Dijkstra's Algorithm
 * @notice This contract implements the search() function,
 * which performs the search for the shortest path to any point in the graph.
 */

contract Dijkstra {
/**
 * @notice Calls the shortest path search algorithm
 * @param graph The graph in which the search will be performed
 * @param startNodeId The identifier of the node from which the search will start
 * @dev We assume that all nodes in the graph are numbered from 0 to graph.length
 * If it is impossible to reach a node, the return value will be equal to type(uint256).max
 */

function search(uint256[][] memory graph, uint256 startNodeId) public pure returns (uint256[] memory) {
    /// Array to keep track of the minimum distance to reach a node
    uint256[] memory nodeWeights = new uint256[](graph.length);
    /// Array to keep track of visited nodes. This helps avoid cycling
    bool[] memory visited = new bool[](graph.length);

/// Set all initial values to the maximum possible. 
/// This is necessary for finding the minimum path to each node in the graph.
for (uint256 i = 0; i < graph.length; i++) {
    nodeWeights[i] = type(uint256).max;

        }

/// The distance from the starting node to itself is zero. We establish this immediately.
        nodeWeights[startNodeId] = 0;

/// Traverse all nodes in the graph
        uint256 count = graph.length;
        while(count > 0) {
/// Find the minimum path to the nearest neighboring node in the graph and set that node as the starting node
            startNodeId = _findMinWeight(nodeWeights, visited);
            visited[startNodeId] = true;

/// Calculate all possible distances to the nearest neighboring nodes
            for (uint256 endNodeId = 0; endNodeId < graph.length; endNodeId++) {
                if (
                    !visited[endNodeId]
                    && graph[startNodeId][endNodeId] != 0
                    && nodeWeights[startNodeId] != type(uint256).max
                    && nodeWeights[startNodeId] + graph[startNodeId][endNodeId] < nodeWeights[endNodeId]
                ) {
/// Update the distance if it's smaller than what was set previously
                    nodeWeights[endNodeId] = nodeWeights[startNodeId] + graph[startNodeId][endNodeId];
                }
            }

            count--;
        }

        return nodeWeights;
    }

    function _findMinWeight(uint256[] memory nodeWeights, bool[] memory visited)
        private
        pure
        returns (uint256 nodeId)
    {
        uint256 minWeight = type(uint256).max;

        for (uint256 i = 0; i < nodeWeights.length; i++) {
            if (!visited[i] && nodeWeights[i] <= minWeight) {
                minWeight = nodeWeights[i];
                nodeId = i;
            }
        }
    }
}
