// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

/**
 * To understand contracts, it's best to deploy them using Remix.
 * Deployment order:
 *      1. Deploy the Logic contract
 *      2. Deploy the LogicProxy contract using the command: `LogicProxy(address Logic, address InitialOwner, 0x)`
 *      3. Link the ABI of the Logic contract with LogicProxy using the "Deploy at address" feature in Remix.
 *         To do this, select Logic in the CONTRACT field and set the address of LogicProxy in "At Address". Press "At address"
 *         This allows calling methods of the Logic contract on the LogicProxy
 *      4. Deploy the Logic2 contract. This contract will update the logic of the Logic contract by adding a new function increment()
 *      5. Call the "getAdmin()" function on the LogicProxy contract to get the address of the admin contract, then link the ProxyAdmin ABI
 *         with this address as done in step 3
 *      6. On the ProxyAdmin contract, call upgradeAndCall(address LogicProxy, address Logic2, 0x) passing the addresses of LogicProxy, Logic2, and data (can be zero 0x)
 *      7. Repeat step 3 but for the Logic2 contract. Now an additional method, increment(), is available.
 *         Meanwhile, the state of the proxy remains unchanged, storing the same values as before the implementation update.
 */

/// Logic contract
contract Logic {
    uint256 private _value;

    function store(uint256 _newValue) public {
        _value = _newValue;
    }

    function retrieve() public view returns (uint256) {
        return _value;
    }
}

/// Logic contract for updates
contract Logic2 {
    uint256 private _value;

    function store(uint256 _newValue) public {
        _value = _newValue;
    }

    function increment() public {
        _value += 1;
    }

    function retrieve() public view returns (uint256) {
        return _value;
    }
}

/// proxy contract
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
