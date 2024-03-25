// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/// @notice SC with a main logic
contract Logic {
    address public initAddress;
    uint256 private _value;

    /**
     * @notice Used to set data on the contract during initialization
     * @dev Essentially a replacement for constructor()
     */
    function initialize(address _initAddress) public {
        initAddress = _initAddress;
    }

    /**
     * @notice Allows writing a value to the state
     * @param _newValue New value to write to the state
     */
    function store(uint256 _newValue) public {
        _value = _newValue;
    }

    /**
     * @notice Allows getting a value from the state
     * @return _value Value from the state
     */
    function retrieve() public view returns (uint256) {
        return _value;
    }
}

/**
 * @notice Proxy Contract
 * @dev Has no implementation. Will delegate calls to the logic contract.
 * The actual storage of data will be on the proxy contract.
 * Interaction with the logic contract only through calls to the proxy contract
 */
contract Proxy {
    struct AddressSlot {
        address value;
    }

    /**
     * @notice Internal variable to determine the location to store information about the logic contract address
     * @dev According to EIP-1967, the slot can be calculated as bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1));
     * We choose a pseudo-random slot and write the address of the logic contract to this slot. This slot position should be random enough
     * so that no variable in the logic contract ever occupies this slot.
     */
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    constructor(address logic) {
        _setImplementation(logic);
    }

    /// @notice Returns the address of the logic contract set for the proxy contract.
    function getImplementation() external view returns (address) {
        return _getImplementation();
    }

    /// @notice Sets the address of the logic contract for the proxy contract.
    function setImplementation(address _newLogic) external {
        _setImplementation(_newLogic);
    }

    function _delegate(address _implementation) internal {
        // Assembly is required because it is impossible to access the return value slot in regular Solidity
        assembly {
            // Copy msg.data to gain full control over the memory for this call.
            calldatacopy(0, 0, calldatasize())

            // Calling the implementation contract
            let result := delegatecall(gas(), _implementation, 0, calldatasize(), 0, 0)

            // Copying the returned data
            returndatacopy(0, 0, returndatasize())

            switch result
            // Revert if the returned data is equal to zero.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    /**
     * @notice Returns the address of the logic contract set for the proxy contract
     * @dev The logic address is stored in a designated slot to prevent it from being accidentally overwritten
     */
    function _getImplementation() internal view returns (address) {
        return getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }

    /**
     * @notice Sets the address of the logic contract for the proxy contract
     * @dev The logic address is stored in a designated slot to prevent it from being accidentally overwritten
     */
    function _setImplementation(address newImplementation) private {
        getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
    }

    /**
      * @notice Returns a storage slot of arbitrary type
      * @param slot Pointer to the storage memory slot
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly {
            r.slot := slot
        }
    }

    /// @dev Any calls to functions of the logic contract through the proxy will be delegated thanks to processing inside the fallback
    fallback() external {
        _delegate(_getImplementation());
    }
}
