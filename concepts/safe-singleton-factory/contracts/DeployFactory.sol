// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract OurMultichainContract {
    address public owner;

    constructor(address _owner) {
        owner = _owner;
    }
}

contract DeployFactory {
    error AlreadyDeployed();

    /// @notice Address of the Singleton Factory
    address constant SAFE_SINGLETON_FACTORY = 0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7;

    /// @notice Any fixed salt
    bytes32 constant SALT = keccak256(bytes("any salt"));

    /// @notice Address of the owner, it will be "hardcoded" into the bytecode  
    /// Changing it will result in a different resulting address
    address public immutable owner = 0x32bb35Fc246CB3979c4Df996F18366C6c753c29c;

    /// @notice Address of the deployed smart contract
    address public immutable ourMultichainContract;

    constructor() {
        /// Step 1. Call Singleton Factory directly
        (bool success, bytes memory result) = SAFE_SINGLETON_FACTORY.call(
            abi.encodePacked(SALT, type(OurMultichainContract).creationCode, abi.encode(owner))
        );

        /// Step 2. Check that the contract is not deployed yet
        if (!success) {
            revert AlreadyDeployed();
        }

        /// Step 3. Retrieve the address of the deployed contract
        ourMultichainContract = address(bytes20(result));
    }
}
