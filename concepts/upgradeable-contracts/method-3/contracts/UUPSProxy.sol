// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

/// Logic contract
contract Logic is UUPSUpgradeable, OwnableUpgradeable {
    uint256 private _value;

    /**
     * @dev The upgradeable contracts do not have a constructor, we need to use the initialize() function.
 * Additionally, we need to initialize the Ownable contract because it is also upgradeable.
 * The one who calls initialize() will become the owner of the Logic contract and will be able to upgrade the implementation for the proxy.
     */
    function initialize() external initializer {
       __Ownable_init();
   }

    function store(uint256 _newValue) public {
        _value = _newValue;
    }

    function retrieve() public view returns (uint256) {
        return _value;
    }

    /**
     * @notice Checking the ability to upgrade the contract.
 * @dev According to the abstract contract UUPSUpgradeable, it is mandatory for us to override this function.
 * By using our own implementation of the function, we will determine the ability to upgrade the logic contract for the proxy contract.
 * In the context of this example, only the owner of the logic contract can upgrade it.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}

/// Proxy contact
contract LogicProxy is ERC1967Proxy {
    constructor(
        address _logic,
        bytes memory _data
    ) ERC1967Proxy(_logic, _data) {}

    /// @notice Возвращает адрес установленного контракта логики для прокси
    function getImplemetation() public view returns (address) {
        return _implementation();
    }
}
