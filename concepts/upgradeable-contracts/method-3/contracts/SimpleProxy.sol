// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/// @notice A cantract with implementation logic
contract Logic {
    address public initAddress;
    uint256 private _value;

    /**
     * @notice Used to set data on the contract during initialization.
 * @dev In reality, it's simply a replacement for constructor().
     */
    function initialize(address _initAddress) public {
        initAddress = _initAddress;
    }

    /**
     * @notice Allows writing a value to the state.
 * @param _newValue The new value to be written to the state.
     */
    function store(uint256 _newValue) public {
        _value = _newValue;
    }

    /**
     * @notice Allows retrieving a value from the state.
     * @return _value A value from state 
     */
    function retrieve() public view returns (uint256) {
        return _value;
    }
}

/**
 * @notice Proxy Contract
 * @dev It does not have its own implementation. It will delegate calls to the logic contract.
 * The actual data storage will be on the proxy contract.
 * Interaction with the logic contract can only happen through calls to the proxy contract.
 */
contract Proxy {
    struct AddressSlot {
        address value;
    }

    /**
     * @notice Internal variable used to determine the storage location for the address of the logic contract.
 * @dev According to EIP-1967, the slot can be calculated as bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1).
 * We choose a pseudo-random slot and store the address of the logic contract in this slot. The slot position should be random enough to ensure that no variable in the logic contract ever occupies this slot.
     */
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    constructor(address logic) {
        _setImplementation(logic);
    }

    /// @notice Returns the address of the set logic contract for the proxy contract.
    function getImplementation() external view returns (address) {
        return _getImplementation();
    }

    /// @notice Sets the address of the logic contract for the proxy contract.
    function setImplementation(address _newLogic) external {
        _setImplementation(_newLogic);
    }

    function _delegate(address _implementation) internal {
        // An assembly insertion is required because it is not possible to directly access the slot to return the value in regular Solidity.
        assembly {
            // Copying msg.data and gain full control over the memory for this invocation.
            calldatacopy(0, 0, calldatasize())

            // calling the implementation contract.
            let result := delegatecall(gas(), _implementation, 0, calldatasize(), 0, 0)

            // Copying the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // Do revert, If the returned data is equal to zero.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    /**
     * @notice Returns the address of the set logic contract for the proxy contract.
 * @dev The logic address is stored in a specifically allocated slot to prevent accidentally overwriting the value.
     */
    function _getImplementation() internal view returns (address) {
        return getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }

    /**
     * @notice Sets the address of the logic contract for the proxy contract.
 * @dev The logic address is stored in a specifically allocated slot to prevent accidentally overwriting the value.
     */
    function _setImplementation(address newImplementation) private {
        getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
    }

    /**
     * @notice Returns the content of an arbitrary storage memory slot.
 * @param slot Pointer to the storage memory slot.
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly {
            r.slot := slot
        }
    }

/// @dev Any calls to functions of the logic contract through the proxy will be delegated thanks to the handling inside the fallback function.
fallback() external {
        _delegate(_getImplementation());
    }
}
