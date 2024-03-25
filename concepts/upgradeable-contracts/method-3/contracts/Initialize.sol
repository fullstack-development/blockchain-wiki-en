// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/**
 * To understand the contracts, it's best to deploy them using Remix.
 * Deployment order:
 *      1. Deploy the Logic contract. Try calling initialize() on the deployed contract.
 *         Our protection will prevent this action
 *      2. Deploy the LogicProxy contract (address Logic, address InitialOwner, 0x)
 *      3. Connect the ABI of the Logic contract with LogicProxy using the built-in Remix functionality "Deploy at address".
 *         To do this, select "Logic" in the CONTRACT field, and set the address of LogicProxy in "At Address". Click on the "At address" button.
 *         This allows calling Logic contract methods for LogicProxy
 *      4. Call the initialize() function on the Logic contract (from step 3, this contract allows the proxy to call Logic methods)
 *         Ensure that the transaction is successful. Call the initialize() function again. Ensure that the transaction returns an error
 */

/// Logic Contract
contract Logic is Initializable {
    uint256 private _defaultValue;
    uint256 private _value;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        /// This prevents initializing the logic contract bypassing the proxy
        _disableInitializers();
    }

    /**
     * @noticeInitialization function.
     * @param defaultValue Default value
     * @dev Utilizes a modifier from the Initializable.sol contract by OpenZeppelin
     */
    function initialize(uint256 defaultValue) external initializer {
        _defaultValue = defaultValue;
    }

    function store(uint256 _newValue) public {
        _value = _newValue;
    }

    function retrieve() public view returns (uint256) {
        if (_value != 0) {
            return _value;
        }

        return _defaultValue;
    }
}

/// proxy smart contract
contract LogicProxy is TransparentUpgradeableProxy {
    constructor(address _logic, address _initialOwner, bytes memory _data)
        TransparentUpgradeableProxy(_logic, _initialOwner, _data)
    {}

    function getAdmin() external view returns (address) {
        return ERC1967Utils.getAdmin();
    }

    function getImplementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    receive() external payable {}
}
