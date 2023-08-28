// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IVestingToken, Vesting} from "./IVestingToken.sol";

/**
 * @title Contract Factory for Creating Share Tokens
 * @notice The main task of this smart contract is to create instances of share tokens
 * and set vesting schedules for them.
 * @dev The code is provided for informational purposes only and has not been tested.
 * Unnecessary code, including some checks, getters/setters, and events, has been removed from the contract.

 */
contract VestingManager {
    address private _vestingImplementation;

    constructor(address implementation) {
        _vestingImplementation = implementation;
    }

    /**
     * @notice The main function for creating an instance of a share token.
     * Since this is the creation of an ERC20 token, we set the name and symbol.
     * Specify the address of the token that will be locked for vesting.
     * Specify the address that will be able to mint share tokens (for example, a sale contract).
     * Pass the vesting schedule.
     */
    function createVesting(
        string calldata name,
        string calldata symbol,
        address baseToken,
        address minter,
        Vesting calldata vesting
    ) external returns (address vestingToken) {
        vestingToken = _createVestingToken(name, symbol, minter, baseToken);

        IVestingToken(vestingToken).setVestingSchedule(
            vesting.startTime,
            vesting.cliff,
            vesting.schedule
        );
    }

    function _createVestingToken(
        string calldata name,
        string calldata symbol,
        address minter,
        address baseToken
    ) private returns (address vestingToken) {
        vestingToken = Clones.clone(_vestingImplementation);

        IVestingToken(vestingToken).initialize(name, symbol, minter, baseToken);
    }
}
