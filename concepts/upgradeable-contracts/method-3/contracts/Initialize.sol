// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/**
 * To understand the contracts better, it's best to deploy them using Remix.

Deployment order:

1. Deploy the Logic contract. Try calling initialize() on the deployed contract, but our protection will prevent this action.
2. Deploy the Admin contract.
3. Deploy the LogicProxy contract with the addresses of Logic and Admin as parameters, and "0x" as the third parameter.
4. Deploy the LogicProxy contract with the ABI of the Logic contract using the built-in Remix functionality "Deploy at address." This will enable calling methods of the Logic contract for the LogicProxy contract.
5. Call the initialize() function on the last deployed LogicProxy contract (deployed with the ABI of the Logic contract). Ensure that the transaction is successful. Try calling the initialize() function again to verify that the transaction returns an error.

To upgrade the implementation, call the upgrade() method on the Admin contract.
 */

/// Logic SC
contract Logic is Initializable {
    uint256 private _defaultValue;
    uint256 private _value;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        /// This will not allow initializing the logic contract without using the proxy.
        _disableInitializers();
    }

    /**
     * @notice Initialization function.
 * @param defaultValue Default value.
 * @dev Uses a modifier from the Initializable.sol contract by OpenZeppelin.

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

/// Proxy contract
contract LogicProxy is TransparentUpgradeableProxy {
    constructor(address _logic, address admin_, bytes memory _data)
        TransparentUpgradeableProxy(_logic, admin_, _data)
    {}
}

/**
 * @notice Contract for Proxy Admin
 * @dev Only the Proxy Admin can update the logic contract for the proxy.
 * Therefore, it is technically required to call the upgrade() method on the Admin contract.
 */
contract Admin is ProxyAdmin {}
