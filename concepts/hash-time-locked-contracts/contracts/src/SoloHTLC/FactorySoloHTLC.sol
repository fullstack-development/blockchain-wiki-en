// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {SoloHTLC, LockOrder, NATIVE_CURRENCY} from "./SoloHTLC.sol";

/**
 * @title Factory for hash time-locked contracts
 * @notice The smart contract was created for educational purposes to demonstrate the creation of an HTLC
 * @dev Serves as the entry point for the user. Calls the `createHTLC()` function
 * After this, a separate HTLC smart contract is created for the user, where the assets are locked at the moment of creation
 * To lock ERC-20 tokens, it is necessary to call `approve()` before creating the HTLC.
 */
contract FactorySoloHTLC {
    event HTLCCreated(address indexed creator, address htlc);

    /**
     * @notice Creation of a hash time-locked contract
     * @param lockOrder Information about the locked assets
     * @param salt Used to create a contract via the `create2` opcode
     */
    function createHTLC(LockOrder memory lockOrder, uint256 salt) external payable returns (address htlcAddress) {
        bytes memory bytecode = abi.encodePacked(type(SoloHTLC).creationCode, abi.encode(lockOrder));
        htlcAddress = getHTLCAddress(bytecode, salt);

        assembly {
            // create(v, p, n)
            // v = amount of ETH to send
            // p = pointer in memory to start of code
            // n = size of code
            htlcAddress := create2(callvalue(), add(bytecode, 0x20), mload(bytecode), salt)

            if iszero(extcodesize(htlcAddress)) { revert(0, 0) }
        }

        emit HTLCCreated(msg.sender, htlcAddress);
    }

    /**
     * @notice Returns the future address of the HTLC contract
     * @param bytecode The bytecode of the HTLC smart contract
     * @param salt A random number for creating a contract via `create2`
     */
    function getHTLCAddress(bytes memory bytecode, uint256 salt)
        public
        view
        returns (address)
    {
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                keccak256(bytecode)
            )
        );

        return address(uint160(uint256(hash)));
    }
}
