// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {Counters} from "openzeppelin-contracts/utils/Counters.sol";
import {IOracle} from "./interfaces/IOracle.sol";

/**
 * @notice Example of an Oracle contract through which other contracts can receive off-chain data.
 * @dev Receives an on-chain request from the Client contract and generates a request to the oracle node for obtaining off-chain data.
 * It is expected that calling the executeRequest() function will deliver off-chain data to the requesting contract.
 */
contract Oracle is IOracle, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _requestIds;

    /// @notice List of requests to obtain off-chain data.
    mapping(uint256 => Request) private _requests;

    /// @notice List of addresses on behalf of which oracle nodes will be able to interact with the Oracle contract.
    mapping(address => bool) private _oracleNodes;

    function getRequestById(uint256 requestId) external view returns (Request memory) {
        return _requests[requestId];
    }

    /**
     * @notice Creates a request to obtain data and emits an event that will be caught by the oracle node off-chain.
 * @param oracleNode The address on behalf of which the oracle node can interact with the Oracle contract.
 * @param data Data for the request.
 * @param callback Data for forwarding the response.
     */
    function createRequest(address oracleNode, bytes memory data, Callback memory callback)
        external
        returns (uint256 requestId)
    {
        bool isTrusted = isOracleNodeTrusted(oracleNode);

        if (!isTrusted) {
            revert OracleNodeNotTrusted(oracleNode);
        }

        _requestIds.increment();
        requestId = _requestIds.current();

        _requests[requestId] = Request({
            oracleNode: oracleNode,
            callback: callback
        });

        emit RequestCreated(requestId, data);
    }

    /**
     * @notice Execution of a request to obtain off-chain data.
 * @dev Only the address set for the corresponding request can call the execute request function.
 * @param requestId The identifier of the request to obtain off-chain data.
 * @param data Off-chain data.
     */
    function executeRequest(uint256 requestId, bytes memory data) external {
        Request memory request = _requests[requestId];

        if (request.oracleNode == address(0)) {
            revert RequestNotFound(requestId);
        }

        if (msg.sender != request.oracleNode) {
            revert SenderShouldBeEqualOracleNodeRequest();
        }

        (bool success,) = request.callback.to
            .call(abi.encodeWithSelector(request.callback.functionSelector, data));

        if (!success) {
            revert ExecuteFailed(requestId);
        }

        emit RequestExecuted(requestId);
    }

    function isOracleNodeTrusted(address account) public view returns (bool) {
        return _oracleNodes[account];
    }

    function setOracleNode(address account) external onlyOwner {
        _oracleNodes[account] = true;

        emit OracleNodeSet(account);
    }

    function removeOracleNode(address account) external onlyOwner {
        delete _oracleNodes[account];

        emit OracleNodeRemoved(account);
    }
}
