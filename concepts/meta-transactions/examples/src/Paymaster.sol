// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {BasePaymaster} from "gsn/BasePaymaster.sol";
import "gsn/utils/GsnTypes.sol";

/**
 * @notice A smart contract where we will store funds for organizing transactions.
 * @dev We will use version 2.2.5. This contract is created for informational purposes only.
 * It is not tested and does not serve any real-world purpose.
 */
contract Paymaster is BasePaymaster {
    address private _target;

    event TargetSet(address target);
    event PostRelayed(address sender);

    error NotTargetContract(address target);

    /**
     * @notice This will be called before invoking a function on the target contract "Recipient."
 * @dev Here, a decision is made whether to pay for the transaction or not.
 * In our case, we will pay if the call matches the address of our target contract.
     */
    function preRelayedCall(
        GsnTypes.RelayRequest calldata relayRequest,
        bytes calldata, // signature
        bytes calldata, // approvalData
        uint256 // maxPossibleGas
    ) external view returns (bytes memory context, bool rejectOnRecipientRevert) {
        if (relayRequest.request.to != _target) {
            revert NotTargetContract(relayRequest.request.to);
        }

        return (abi.encode(relayRequest.request.from), true);
    }

    /**
     * @notice This will be called after invoking a function on the target contract "Recipient."
 * @dev Here, we already know the practically final gas cost and can add any logic as needed.
     */
    function postRelayedCall(
        bytes calldata context, // The address that we returned as the first parameter from the function preRelayedCall().
        bool, // success
        uint256, // gasUseWithoutPost - The cost of the gas for the request, excluding the cost of the gas used in postRelayedCall().
        GsnTypes.RelayData calldata // relayData
    ) external {
        emit PostRelayed(abi.decode(context, (address)));
    }

    function setTarget(address target) external onlyOwner {
        _target = target;

        emit TargetSet(target);
    }

    function versionPaymaster() external pure returns (string memory) {
        return "2.2.5";
    }
}
