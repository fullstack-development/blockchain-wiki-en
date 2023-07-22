// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

/**
 * Deployment order for testing in Remix:

1. Deploy the Logic contract.
2. Deploy the Beacon contract with the address of Logic as a parameter.
3. Deploy the LogicProxy contract with Beacon's address and "0x" as parameters.
4. Deploy the new Logic2 contract.
5. Call upgradeTo(address Logic2) on the Beacon contract.
6. Call the getImplementation() function on each LogicProxy contract to verify the change of the logic contract.
 */

/// Logic SC
contract Logic {
    uint256 private _value;

    function store(uint256 _newValue) public {
        _value = _newValue;
    }

    function retrieve() public view returns (uint256) {
        return _value;
    }
}

/// SC for Logic upgrade
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

// Beacon SC
contract Beacon is UpgradeableBeacon {
    // To upgrade the logic for all proxy contracts, you need to call the upgradeTo() function on the Beacon contract.
    constructor(address _implementation) UpgradeableBeacon(_implementation) {}
}

/// Proxy contract
contract LogicProxy is BeaconProxy {
    constructor(
        address _beacon,
        bytes memory _data
    ) BeaconProxy(_beacon, _data) {}

    /// @notice Returns the address of the set logic contract for the proxy.
    function getImplemetation() public view returns (address) {
        return _implementation();
    }

    /// @notice Returns the address of the Beacon contract.
    function getBeacon() public view returns (address) {
        return _beacon();
    }
}
