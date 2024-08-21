// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

address constant NATIVE_CURRENCY = address(0);
uint64 constant MIN_LOCK_TIME = 1 days;

struct LockOrder {
    address sender;
    address recipient;
    bytes32 secretHash;
    address token;
    uint256 value;
    uint64 expiredTime;
}

/**
 * @title Hash time locked contract
 * @notice The smart contract was created for educational purposes to demonstrate the operation of HTLC.
 * @dev The user locks the assets at the moment of contract creation by specifying the hash of the secret phrase.
 * Knowing the secret phrase, another user will be able to unlock the assets.
 * If this does not happen, the first user can return the assets after the lock time expires
 */
contract SoloHTLC {
    using SafeERC20 for IERC20;

    LockOrder private _lockOrder;

    event Locked(LockOrder lockOrder);
    event Claimed(bytes secret, LockOrder lockOrder);
    event Refunded(LockOrder lockOrder);

    error InsufficientAmount();
    error InvalidSender();
    error InvalidRecipient();
    error InvalidSecretHash();
    error InvalidValue();
    error InvalidExpiredTime();
    error TransferFailed();
    error InvalidSecret();
    error ClaimHasExpired();
    error RefundHasNotExpiredYet();

    modifier validateLock(LockOrder memory lockOrder) {
        if (lockOrder.sender == address(0)) {
            revert InvalidSender();
        }

        if (lockOrder.recipient == address(0)) {
            revert InvalidRecipient();
        }

        if (lockOrder.secretHash == bytes32(0)) {
            revert InvalidSecretHash();
        }

        if (lockOrder.value == 0) {
            revert InvalidValue();
        }

        if (lockOrder.expiredTime < block.timestamp + MIN_LOCK_TIME) {
            revert InvalidExpiredTime();
        }

        _;
    }

    modifier validateClaim(bytes memory secret) {
        if (keccak256(abi.encodePacked(secret)) != _lockOrder.secretHash) {
            revert InvalidSecret();
        }

        if (msg.sender != _lockOrder.recipient) {
            revert InvalidRecipient();
        }

        if (_lockOrder.expiredTime <= uint64(block.timestamp)) {
            revert ClaimHasExpired();
        }

        _;
    }

    modifier validateRefund() {
        if (msg.sender != _lockOrder.sender) {
            revert InvalidSender();
        }

        if (_lockOrder.expiredTime > uint64(block.timestamp)) {
            revert RefundHasNotExpiredYet();
        }

        _;
    }

    /**
     * @notice Constructor. Locks the user's assets at the moment of contract initialization
     * @param lockOrder Information about the locked assets
     */
    constructor(LockOrder memory lockOrder) validateLock(lockOrder) payable {
        _lockOrder = lockOrder;

        _transferFrom(lockOrder.token, lockOrder.sender, address(this), lockOrder.value);

        emit Locked(lockOrder);
    }

    /**
     * @notice Allows the recipient of the asset to withdraw the funds
     * @param secret The secret phrase that must be known to unlock the assets
     */
    function claim(bytes memory secret) external validateClaim(secret) {
        _transfer(_lockOrder.token, _lockOrder.recipient, _lockOrder.value);

        emit Claimed(secret, _lockOrder);
    }

    /**
     * @notice Allows the creator of the locked assets to withdraw the funds
     * @dev Available only after the `expiredTime` has been reached
     */
    function refund() external validateRefund {
        _transfer(_lockOrder.token, _lockOrder.sender, _lockOrder.value);

        emit Refunded(_lockOrder);
    }

    /// @notice Retrieve information about the locked assets
    function getLockOrder() external view returns (LockOrder memory) {
        return _lockOrder;
    }

    function _transfer(address token, address to, uint256 value) private {
        if (token == NATIVE_CURRENCY) {
            (bool success,) = to.call{value: value}("");
            if (!success) {
                revert TransferFailed();
            }
        }
        else {
            IERC20(token).safeTransfer(to, value);
        }
    }

    function _transferFrom(address token, address from, address to, uint256 value) private {
        if (token == NATIVE_CURRENCY) {
            if (msg.value != value) {
                revert InsufficientAmount();
            }
        }
        else {
            IERC20(token).safeTransferFrom(from, to, value);
        }
    }
}
