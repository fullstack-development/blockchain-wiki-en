// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

address constant NATIVE_CURRENCY = address(0);
uint64 constant MIN_LOCK_TIME = 1 days;
uint64 constant MIN_DIFFERENCE_BETWEEN_ORDERS = 1 hours;

struct Order {
    address recipient;
    address token;
    uint256 value;
    uint64 expiredTime;
}

contract SingleHTLC {
    using SafeERC20 for IERC20;

    mapping(address sender => mapping(bytes32 secretHash => Order order)) private _lockedOrders;
    mapping(bytes32 secretHash => bool isRedeemed) private _isSecretHashRedeemed;
    mapping(bytes32 secretHash => bool isClaimed) private _isSecretHashClaimed;
    mapping(bytes32 secretHash => mapping(address account => bool isClaimed)) private _isSecretHashRefunded;

    event Locked(Order order, bytes32 indexed secretHash, address indexed sender);
    event Redeemed(bytes secret, bytes32 secretHash, address indexed token, address indexed sender, uint256 value);
    event Claimed(bytes secret, bytes32 secretHash, address indexed token, address indexed sender, uint256 value);
    event Refunded(bytes32 secretHash, address indexed token, address indexed sender, uint256 value);

    error OrderHasLocked();
    error InsufficientAmount();
    error InvalidRecipient();
    error InvalidSecretHash();
    error InvalidValue();
    error InvalidExpiredTime();
    error TransferFailed();
    error InvalidSecret();
    error RefundHasNotExpiredYet();
    error ExpiredTimeShouldLessThanRecipientOrder();
    error OrderExpired();
    error SecretHashHasRedeemed();
    error SecretHashHasClaimed();
    error SecretHashHasRefunded();

    modifier validateLock(Order memory order, bytes32 secretHash) {
        if (_lockedOrders[msg.sender][secretHash].recipient != address(0)) {
            revert OrderHasLocked();
        }

        Order memory recipientOrder = _lockedOrders[order.recipient][secretHash];
        if (recipientOrder.recipient != address(0)) {
            if (recipientOrder.expiredTime - order.expiredTime < MIN_DIFFERENCE_BETWEEN_ORDERS) {
                revert ExpiredTimeShouldLessThanRecipientOrder();
            }
        }
        else if (order.expiredTime < block.timestamp + MIN_LOCK_TIME) {
            revert InvalidExpiredTime();
        }

        if (order.recipient == address(0)) {
            revert InvalidRecipient();
        }

        if (order.value == 0) {
            revert InvalidValue();
        }

        if (secretHash == bytes32(0)) {
            revert InvalidSecretHash();
        }

        _;
    }

    modifier validateRedeem(bytes memory secret) {
        bytes32 secretHash = keccak256(abi.encodePacked(secret));
        Order memory senderOrder = _lockedOrders[msg.sender][secretHash];
        Order memory recipientOrder = _lockedOrders[senderOrder.recipient][secretHash];

        if (recipientOrder.recipient != msg.sender) {
            revert InvalidRecipient();
        }

        if (recipientOrder.expiredTime < block.timestamp) {
            revert OrderExpired();
        }

        if (_isSecretHashRedeemed[secretHash]) {
            revert SecretHashHasRedeemed();
        }

        _;
    }

    modifier validateClaim(bytes memory secret) {
        bytes32 secretHash = keccak256(abi.encodePacked(secret));
        Order memory senderOrder = _lockedOrders[msg.sender][secretHash];
        Order memory recipientOrder = _lockedOrders[senderOrder.recipient][secretHash];

        if (recipientOrder.recipient != msg.sender) {
            revert InvalidRecipient();
        }

        if (_isSecretHashClaimed[secretHash]) {
            revert SecretHashHasClaimed();
        }

        _;
    }

    modifier validateRefund(bytes32 secretHash) {
        Order memory order = _lockedOrders[msg.sender][secretHash];
        if (order.recipient == address(0)) {
            revert InvalidRecipient();
        }

        if (_isSecretHashClaimed[secretHash]) {
            revert SecretHashHasClaimed();
        }

        if (_isSecretHashRedeemed[secretHash]) {
            revert SecretHashHasRedeemed();
        }

        if (order.expiredTime > uint64(block.timestamp)) {
            revert RefundHasNotExpiredYet();
        }

        if (_isSecretHashRefunded[secretHash][msg.sender]) {
            revert SecretHashHasRefunded();
        }

        _;
    }

    /**
     * @notice User asset blocking
     * @param order Information about blocked assets
     * @param secretHash Hashed secret phrase
     */
    function lock(Order memory order, bytes32 secretHash) validateLock(order, secretHash) external payable {
        _lockedOrders[msg.sender][secretHash] = order;

        _transferFrom(order.token, msg.sender, address(this), order.value);

        emit Locked(order, secretHash, msg.sender);
    }

    /**
     * @notice Secret revelation
     * @param secret Secret phrase. It was hashed to create orders by users
     * @dev Used by the first user. At the moment of revelation, the first user takes the assets of the second user
     */
    function redeem(bytes memory secret) external validateRedeem(secret) {
        bytes32 secretHash = keccak256(abi.encodePacked(secret));
        Order memory senderOrder = _lockedOrders[msg.sender][secretHash];
        Order memory recipientOrder = _lockedOrders[senderOrder.recipient][secretHash];

        _isSecretHashRedeemed[secretHash] = true;
        _transfer(recipientOrder.token, msg.sender, recipientOrder.value);

        emit Redeemed(secret, secretHash, recipientOrder.token, msg.sender, recipientOrder.value);
    }

    /**
     * @notice Allows the second user to take the asset
     * @param secret A secret phrase that must be known to unlock assets
     * @dev The second user learns the secret phrase after the first user reveals it by calling the redeem() function
     */
    function claim(bytes memory secret) external validateClaim(secret) {
        bytes32 secretHash = keccak256(abi.encodePacked(secret));
        Order memory senderOrder = _lockedOrders[msg.sender][secretHash];
        Order memory recipientOrder = _lockedOrders[senderOrder.recipient][secretHash];

        _isSecretHashClaimed[secretHash] = true;
        _transfer(recipientOrder.token, msg.sender, recipientOrder.value);

        emit Claimed(secret, secretHash, recipientOrder.token, msg.sender, recipientOrder.value);
    }

    /**
     * @notice Allows the user who locked the assets for a specific secret phrase to withdraw the funds
     * @dev Available only after the expiredTime. Becomes unavailable after the secret phrase has been revealed.
     */
    function refund(bytes32 secretHash) external validateRefund(secretHash) {
        Order memory senderOrder = _lockedOrders[msg.sender][secretHash];

        _isSecretHashRefunded[secretHash][msg.sender] = true;
        _transfer(senderOrder.token, msg.sender, senderOrder.value);

        emit Refunded(secretHash, senderOrder.token, msg.sender, senderOrder.value);
    }

    /// @notice Get information about blocked assets
    function getLockedOrder(address sender, bytes32 secretHash) external view returns (Order memory) {
        return _lockedOrders[sender][secretHash];
    }

    /**
     * @notice True if the secret phrase has been revealed, otherwise false
     * @param secretHash Hashed secret phrase
     */
    function isSecretHashRedeemed(bytes32 secretHash) external view returns (bool) {
        return _isSecretHashRedeemed[secretHash];
    }

    /**
     * @notice True if the assets were unlocked for the second user, otherwise false
     * @param secretHash Hashed secret phrase
     */
    function isSecretHashClaimed(bytes32 secretHash) external view returns (bool) {
        return _isSecretHashClaimed[secretHash];
    }

    /**
     * @notice True if the assets were returned, otherwise false
     * @param secretHash Hashed secret phrase
     * @param account The address of the user for whom the blocked assets are being checked
     */
    function isSecretHashRefunded(bytes32 secretHash, address account) external view returns (bool) {
        return _isSecretHashRefunded[secretHash][account];
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
