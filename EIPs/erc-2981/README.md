# ERC-2981: NFT Royalty Standard

**Author:** [Alexey Kutsenko](https://github.com/bimkon144) 👨‍💻

The goal of this article is to take a deep dive into the ERC-2981 standard, explain its role in providing royalties for NFT creators, analyze its advantages and limitations, explore possible ways to integrate it into existing contracts, and also look at how different marketplaces support this standard, alternative royalty management approaches, and creating contract wrappers.

## Why royalties matter for NFT creators

NFTs (Non-Fungible Tokens) are unique digital assets that, thanks to blockchain technology, can represent ownership rights to various objects: artworks, music tracks, in-game items, and much more. One of the key aspects of NFTs is the ability for creators to receive royalties from the resale of their assets. This guarantees a sustainable income for artists, musicians, and other creators.

**Main issues before standardization:**

- Incompatibility of royalty mechanisms between marketplaces. On one platform royalties work one way, on another — differently, and on a third there might be no royalties at all. You can't just take an NFT created on one marketplace with royalties and be sure that royalties will also be charged on another platform (and by the way, this standard didn't fully solve that problem either).

- Bypassing the royalty mechanism. Loopholes that allowed sellers and buyers to avoid paying royalties.

## What is ERC-2981?

### Standard Overview

[ERC-2981](https://eips.ethereum.org/EIPS/eip-2981) — is a standard for smart contracts developed to unify the mechanism for determining royalties on NFT sales. It facilitates interaction between content creators, token holders, and platforms by providing a simple way to describe royalty payment terms.

Main features:

- Compatibility:
   The standard supports ERC-721, ERC-1155, and any contract that inherits from the implementation of the standard, making it universal.

- Easy integration:
   Uses a unified interface to define royalty conditions, which can be easily integrated with platforms and marketplaces.

- Flexibility (at the implementation level):
   Although the standard itself only describes the basic mechanism, developers can implement additional features, such as dynamic royalties or more complex conditions.

- Scalability:
   The standard defines an interface that returns royalty information but does not require platforms to automatically pay them out. This simplifies adoption and doesn't impose additional restrictions.

### Technical Implementation

Let's look at an example of the standard implementation from OpenZeppelin

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Import the ERC2981 interface to implement standard royalty behavior. It declares the method for retrieving royaltyInfo.
import {IERC2981} from "../../interfaces/IERC2981.sol";

// Import the ERC165 interface and implementation to support interface checks.
import {IERC165, ERC165} from "../../utils/introspection/ERC165.sol";

/**
 * @dev Implementation of the ERC-2981 standard for managing royalty information.
 *
 * Royalty info can be set globally (for all tokens)
 * using the `_setDefaultRoyalty` method, and also for specific tokens
 * using the `_setTokenRoyalty` method. Token-specific settings
 * take precedence over the global one.
 *
 * Important: The ERC-2981 standard only describes how to provide royalty information
 * and does not enforce royalty payments. Actual payouts depend on
 * marketplace support for the standard.
 */
abstract contract ERC2981 is IERC2981, ERC165 {
    // Structure for storing royalty information
    struct RoyaltyInfo {
        address receiver; // Address of the royalty recipient
        uint96 royaltyFraction; // Royalty percentage (in basis points)
    }

    // Global royalty info (default for all tokens)
    RoyaltyInfo private _defaultRoyaltyInfo;

    // Mapping for individual royalty info (per token)
    mapping(uint256 tokenId => RoyaltyInfo) private _tokenRoyaltyInfo;

    error ERC2981InvalidDefaultRoyalty(uint256 numerator, uint256 denominator);
    error ERC2981InvalidDefaultRoyaltyReceiver(address receiver);
    error ERC2981InvalidTokenRoyalty(uint256 tokenId, uint256 numerator, uint256 denominator);
    error ERC2981InvalidTokenRoyaltyReceiver(uint256 tokenId, address receiver);

    /**
     * @dev Interface support, including ERC2981.
     * Returns `true` if the specified `interfaceId` is supported.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC165) returns (bool) {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Method for retrieving royalty information.
     * Returns the royalty recipient address and the royalty amount based on the sale price.
     * If there is no token-specific setting, the global one is used.
     */
    function royaltyInfo(
        uint256 tokenId,
        uint256 salePrice
    ) public view virtual returns (address receiver, uint256 amount) {
        // Get royalty info for a specific token
        RoyaltyInfo storage _royaltyInfo = _tokenRoyaltyInfo[tokenId];

        address royaltyReceiver = _royaltyInfo.receiver;
        uint96 royaltyFraction = _royaltyInfo.royaltyFraction;

        // If there is no token-specific info, use the global one
        if (royaltyReceiver == address(0)) {
            royaltyReceiver = _defaultRoyaltyInfo.receiver;
            royaltyFraction = _defaultRoyaltyInfo.royaltyFraction;
        }

        // Calculate royalty amount: (sale price * percentage) / denominator
        uint256 royaltyAmount = (salePrice * royaltyFraction) / _feeDenominator();

        return (royaltyReceiver, royaltyAmount);
    }


    /**
     * @dev Method returns the denominator used for royalty calculation.
     * Default is 10000, allowing percentages to be specified in basis points.
     */
    function _feeDenominator() internal pure virtual returns (uint96) {
        return 10000; // Basis points (1 = 0.01%)
    }

    /**
     * @dev Sets global royalty info (applied to all tokens).
     * Requirements:
     * - `receiver` must not be the zero address.
     * - `feeNumerator` must not exceed the denominator.
     */
    function _setDefaultRoyalty(address receiver, uint96 feeNumerator) internal virtual {
        uint256 denominator = _feeDenominator();
        if (feeNumerator > denominator) {
            revert ERC2981InvalidDefaultRoyalty(feeNumerator, denominator);
        }
        if (receiver == address(0)) {
            revert ERC2981InvalidDefaultRoyaltyReceiver(address(0));
        }

        _defaultRoyaltyInfo = RoyaltyInfo(receiver, feeNumerator);
    }

    /**
     * @dev Deletes the global royalty information.
     */
    function _deleteDefaultRoyalty() internal virtual {
        delete _defaultRoyaltyInfo;
    }

    /**
     * @dev Sets individual royalty information for a specific token.
     * Requirements:
     * - `receiver` must not be the zero address.
     * - `feeNumerator` must not exceed the denominator.
     */
    function _setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator) internal virtual {
        uint256 denominator = _feeDenominator();
        if (feeNumerator > denominator) {
            revert ERC2981InvalidTokenRoyalty(tokenId, feeNumerator, denominator);
        }
        if (receiver == address(0)) {
            revert ERC2981InvalidTokenRoyaltyReceiver(tokenId, address(0));
        }

        _tokenRoyaltyInfo[tokenId] = RoyaltyInfo(receiver, feeNumerator);
    }


    /**
     * @dev Deletes individual royalty information for a specific token,
     * reverting it to using the global royalty setting.
     */
    function _resetTokenRoyalty(uint256 tokenId) internal virtual {
        delete _tokenRoyaltyInfo[tokenId];
    }
}

```

Using the standard in your own contract:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Using the base ERC-721 contract
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// Importing the ERC-2981 implementation for royalties
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";

/**
 * @title SimplifiedERC721WithRoyalty
 * @dev Simplified ERC-721 implementation with ERC-2981 royalty support.
 */
contract SimplifiedERC721WithRoyalty is ERC721, ERC2981 {
    uint256 private _nextTokenId;

    /**
     * @dev Contract constructor.
     * @param name Token name.
     * @param symbol Token symbol.
     */
    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

    /**
     * @dev Mint a new token with royalty settings.
     * @param to Address of the token recipient.
     * @param royaltyReceiver Address to receive royalties.
     * @param royaltyFraction Royalty percentage in basis points (500 = 5%).
     */
    function mint(
        address to,
        address royaltyReceiver,
        uint96 royaltyFraction
    ) external {
        uint256 tokenId = _nextTokenId++; // Generate new token ID

        // Mint the token
        _mint(to, tokenId);

        // Set royalty for the token
        if (royaltyReceiver != address(0) && royaltyFraction > 0) {
            _setTokenRoyalty(tokenId, royaltyReceiver, royaltyFraction);
        }
    }

    /**
     * @dev Set a global royalty applicable to all tokens.
     * @param receiver Address of the royalty recipient.
     * @param feeNumerator Royalty percentage in basis points.
     */
    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external {
        _setDefaultRoyalty(receiver, feeNumerator);

    }

    /**
     * @dev Delete the global royalty setting.
     */
    function deleteDefaultRoyalty() external {
        _deleteDefaultRoyalty();
    }

    /**
     * @dev Remove royalty for a specific token, reverting to the global setting.
     * @param tokenId Token identifier.
     */
    function resetTokenRoyalty(uint256 tokenId) external {
        _resetTokenRoyalty(tokenId);
    }

    /**
     * @dev Override of the `supportsInterface` method to support ERC2981.
     * @param interfaceId Interface identifier.
     * @return Returns true if the interface is supported.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
```

Thus, this standard is another step towards maintaining fair royalties for NFT creators.

At the time of writing this article, the situation with ERC-2981 support looks like this:

| Marketplace      | ERC-2981 Support   | Notes                                                                                                 |
|------------------|--------------------|-------------------------------------------------------------------------------------------------------|
| **OpenSea**      | No                 | Does not support the ERC-2981 standard. Uses its own royalty configuration system at the collection level via the platform interface. |
| **Rarible**      | Yes                | Fully supports ERC-2981. Additionally, royalties can be set through the platform interface for older contracts. |
| **Magic Eden**   | Yes                | Supports ERC-2981 but also offers manual royalty configuration via the collection's admin panel.       |
| **Blur**         | No                 | Does not support ERC-2981. Allows users to set their own royalty percentage.                          |

### Adding ERC-2981 to Existing Contracts

Adding royalties to already deployed contracts that don’t support this feature is a challenging task, especially if the contract wasn’t originally designed to be upgradable. However, there are solutions that allow adapting such contracts to handle royalties. The main approaches are discussed below.

1. If the contract is upgradeable, ERC-2981 can be added — for example, using OpenZeppelin's implementation.

2. Creating a wrapper for existing tokens

One solution is to create a new smart contract that acts as a wrapper for the original tokens. This contract implements the ERC-2981 standard or custom royalty mechanisms.

How it works: Token holders send their tokens to the wrapper contract, effectively "staking" their assets. The new contract mints "wrapped" tokens that include royalty logic. These wrapped tokens can be traded on marketplaces that support the standard, and creators receive royalties with each resale.

This solution is not optimal because:

- It requires the NFT owner to interact with another contract.

- There is still the possibility of direct interaction with the original NFT smart contract, which allows bypassing royalties during transfers and potentially minting NFTs without royalties (depending on who has permission to mint NFTs).

## Conclusion

The ERC-2981 standard represents an important step in the development of the NFT ecosystem, allowing for a unified royalty mechanism and making it easier for content creators to implement royalties. The main advantages of the standard are its compatibility with popular token standards (ERC-721 and ERC-1155), flexibility in implementation, and ease of integration for new contracts. However, it also faces several limitations:

- Limited enforcement: The standard only provides a way to describe royalties, but does not guarantee automatic payments. This makes it dependent on the goodwill of marketplaces, which limits its functionality.

- No retroactive support: ERC-2981 cannot be applied to already deployed contracts, which complicates its adoption for existing collections. Solutions like wrappers require significant user effort and are rarely used in practice.

- Marketplace support issues: Not all popular platforms, such as Blur or OpenSea, support the standard. They offer royalty systems only within their own ecosystems, which doesn’t solve the broader issue of royalty standardization across all marketplaces. This creates fragmentation in the ecosystem, where royalties may be ignored when selling on certain platforms.

Despite these drawbacks, ERC-2981 remains a valuable tool for new projects, providing creators with a convenient way to set royalty conditions. However, to truly address royalty issues in existing collections and protect creator rights, new approaches are needed. Work in the area of royalties is ongoing, and alternative solutions are being explored.
