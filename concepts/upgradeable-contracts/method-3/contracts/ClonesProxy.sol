
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * To understand the contracts, it's best to deploy them using Remix.
 * Deployment order:
 * 1. Deploy the Pair contract
 * 2. Deploy the Factory contract (address Pair)
 * 3. Call the createPair method on the Factory contract. You can use any token addresses as parameters.
 * 4. Ensure that a new instance (clone) of the Pair contract is successfully created


interface IPair {
    function initialize(address _tokenA, address _tokenB) external;
}

contract Pair {
    address public factory;
    IERC20 public token0;
    IERC20 public token1;

    function initialize(address _tokenA, address _tokenB) external {
        require(factory == address(0), "UniswapV2: FORBIDDEN");

        factory = msg.sender;
        token0 = IERC20(_tokenA);
        token1 = IERC20(_tokenB);
    }

    function getReserves() public view returns (uint112 reserve0, uint112 reserve1) {/** */}
    function mint(address to) external returns (uint256 liquidity) {/** */}
    function burn(address to) external returns (uint256 amount0, uint256 amount1) {/** */}
    function swap(uint256 amount0Out, uint256 amount1Out, address to) external {/** */}
}

contract Factory {
    address public pairImplementation;
    mapping(address => mapping(address => address)) private _pairs;

    event PairCreated(address tokenA, address tokenB, address pair);

    constructor(address _pairImplementation) {
        pairImplementation = _pairImplementation;
    }

    function createPair(address _tokenA, address _tokenB) external returns (address pair) {
        require(getPair(_tokenA, _tokenB) == address(0), "Pair has been created already");

        // Deploy the Pair contract based on the deployed Pair contract using the clones library
        bytes32 salt = keccak256(abi.encodePacked(_tokenA, _tokenB));
        pair = Clones.cloneDeterministic(pairImplementation, salt);

        // Initialize the Pair contract. Pass the tokens and additionally set the factory address for the Pair
        IPair(pair).initialize(_tokenA, _tokenB);

        _pairs[_tokenA][_tokenB] = pair;

        emit PairCreated(_tokenA, _tokenB, pair);
    }

    function getPair(address tokenA, address tokenB) public view returns (address) {
        return _pairs[tokenA][tokenB] != address(0) ? _pairs[tokenA][tokenB] : _pairs[tokenB][tokenA];
    }
}
