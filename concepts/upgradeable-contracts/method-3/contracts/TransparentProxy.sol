// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

/**
 * To understand the contracts better, it's best to deploy them using Remix.
Deployment order:

1. Deploy the Logic contract.
2. Deploy the Admin contract.
3. Deploy the LogicProxy contract with the addresses of Logic and Admin as parameters, and "0x" as the third parameter.
4. Deploy the LogicProxy contract with the ABI of the Logic contract using the built-in Remix functionality "Deploy at address." To do this, select "Logic" in the CONTRACT field and set the address of LogicProxy in the At field. Click on the "At" button. This will enable calling methods of the Logic contract for the LogicProxy contract.
5. Deploy the Logic2 contract. This contract will update the logic of the Logic contract by adding a new function increment().
6. On the Admin contract, call upgrade() and pass the addresses of LogicProxy and Logic2 as parameters.
7. Repeat step 4, but now for the Logic2 contract. Now we have an additional method increment(). The state of the proxy contract remains unchanged; it still holds the same values as before the implementation update.

/// Logic Contract
contract Logic {
    uint256 private _value;

    function store(uint256 _newValue) public {
        _value = _newValue;
    }

    function retrieve() public view returns (uint256) {
        return _value;
    }
}

/// Logic contract for updating.
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

/// Proxy contract
contract LogicProxy is TransparentUpgradeableProxy {
    constructor(address _logic, address admin_, bytes memory _data)
        TransparentUpgradeableProxy(_logic, admin_, _data)
    {}
}

/**
 * @notice /// Admin proxy contract
 * @dev Only the proxy admin can update the logic contract for the proxy.
 * Therefore, it is technically required to call the upgrade() method on the admin contract.
 */
contract Admin is ProxyAdmin {}
