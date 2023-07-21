// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {BaseRelayRecipient} from "gsn/BaseRelayRecipient.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {Context} from "openzeppelin-contracts/utils/Context.sol";

/**
 * @notice A contract where we want to implement the Gas Station Network functionality.
 * @dev We will use version 2.2.5. This contract is created for informational purposes only.
 * It is not tested and does not serve any real-world purpose.
 */
contract Recipient is BaseRelayRecipient, Ownable {
    mapping(address => bool) private _flag;

    event FlagSet(address realSender, address sender);
    event TrustedForwarderSet(address forwarder);

    constructor(address forwarder) {
// Set the address of the contract that will be allowed to proxy calls on behalf of GSN.
_setTrustedForwarder(forwarder);
    }

    function setFlag(bool value) public {
        _flag[_msgSender()] = value;

        emit FlagSet(msg.sender, _msgSender());
    }

    /**
     * @notice Sets the address of the contract that will be allowed to proxy calls on behalf of GSN.
 * @param forwarder The address of the contract.
     */
    function setTrustedForwarder(address forwarder) external onlyOwner{
        _setTrustedForwarder(forwarder);

        emit TrustedForwarderSet(forwarder);
    }

    function versionRecipient() external override pure returns (string memory) {
        return "2.2.5";
    }

    /// @notice We are re-determining the _msgData() function. This is necessary to determine calls from the Forwarder contract.


    function _msgData() internal view override(Context, BaseRelayRecipient) returns (bytes calldata ret) {
        return super._msgData();
    }

    /// @notice We are re-determining the _msgSender(). This is necessary to determine calls from the Forwarder contract.
    function _msgSender() internal view override(Context, BaseRelayRecipient) returns (address sender) {
        return super._msgSender();
    }
}
