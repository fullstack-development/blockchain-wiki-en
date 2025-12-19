# ERC-3643: T-REX - Token for Regulated EXchanges

**Author:** [Aleksei Kutsenko](https://github.com/bimkon144) 👨‍💻

## 1. Introduction

T-REX (Token for Regulated Exchanges) is a reference implementation of the [ERC-3643](https://eips.ethereum.org/EIPS/eip-3643) standard for issuing and managing tokens that represent real-world assets (securities, company shares, funds, real estate, etc.), while maintaining an ERC-20 compatible interface.

Unlike traditional ERC-20 tokens, which are initially **permissionless** and can move freely between any addresses, ERC-3643 (T-REX) is built around a **permissioned model**. Each token is linked to the holder's on-chain identity, and any operations with the token (mint, burn, transfer) go through an automatic verification layer — a combination of Identity Registry and Compliance — which determines whether the action is allowed based on regulatory rules and the issuer’s internal compliance policies.

![alt text](./images/common-architecture.png)

Motivation behind the standard: blockchain has proven effective for peer-to-peer transfers of cryptocurrencies, but regulated assets (securities/RWA) require built-in KYC/AML checks, holder control, the ability to freeze and recover tokens — all at the smart contract level, not through off-chain processes. ERC-3643 addresses this through a set of contracts with mandatory identity and compliance checks.

In this article, we look at T-REX specifically as a protocol:
- what contracts it includes;
- how identity, registry, compliance, and the token itself are connected;
- which roles are involved (issuer, agent, investor, KYC provider);
- how contracts interact during operations;
- how contracts are updated via the Implementation Authority;
- how to deploy tokens using TREXFactory and TREXGateway;

---

## 2. Terms

**Security token** – a token representing a regulated asset (security, share, fund).

**Permissioned token** – a token architecture where operations are only available to verified addresses and follow specific transfer rules.

**ERC-3643 (T-REX)** – a standard that defines how to implement a permissioned model on top of ERC-20.

**ONCHAINID** – a protocol for managing on-chain identities (ERC-734/ERC-735), linking a wallet address to a real person or organization.

**Claim** – an attestation about the identity holder, signed by a trusted provider. For example: "KYC passed", "Country of residence: USA", "Accredited investor".

**Claim Issuer** – an attestation provider (KYC service, bank, registrar, KYC intermediary) that signs and, if needed, revokes claims.

**Claim Topic** – the type of attestation (e.g., KYC_CLAIM, COUNTRY_CLAIM, INVESTOR_STATUS_CLAIM). Each token defines a required set of topics.

## 3. T-REX General Architecture

### 3.1. Architecture Diagram

T-REX consists of a set of interconnected smart contracts that work together to enable a permissioned token model. Below is a general architecture diagram:

![alt text](./images/t-rex-architecture.png)
Main system contracts:

**Permissioned token** – the core token contract implementing the ERC-3643 standard. It is method-compatible with ERC-20, while adding mandatory compliance checks before each operation (`transfer`, `mint`, `burn`). It supports admin operations: pause, address freezing (`freeze`), forced transfers (`forcedTransfer` – transfer of tokens by an admin without the owner's consent, e.g., by court order or due to sanctions), and access recovery (`recovery` – transferring tokens to a new address if the private key is lost, when the owner proves their identity through the on-chain identity).

[ONCHAINID](https://docs.onchainid.com/) – a separate protocol for managing on-chain identities (implements ERC-734/ERC-735 standards), specifically designed for use with ERC-3643. It stores claims signed by trusted issuers and provides methods for verifying them. It is not part of T-REX itself, but is critically important for the protocol’s operation.

**Identity Registry** – a registry that links wallet addresses to on-chain identities (ONCHAINID).

**Identity Registry Storage** – a separate contract for storing identity data. It allows multiple Identity Registries to connect to it, enabling centralized management of all identities through a single contract.

**Compliance + Modules** – a contract with pluggable compliance modules that defines business rules for the token: geo-restrictions, investor and balance limits, lockup/vesting periods.

**Trusted Issuers Registry** – a registry of trusted attestation providers (KYC providers, banks, registrars). It stores the list of addresses whose signatures on claims are considered valid for a specific token. Used during investor verification.

**Claim Topics Registry** – a registry of claim types required to hold the token. It defines which specific attestations (KYC passed, country of residence, investor status, etc.) an identity must have for an address to be eligible to hold the token.

**Claim Issuer** – the contract of a claim provider (e.g., a KYC provider or intermediary) that signs and, if needed, revokes claims. The Claim Issuer is added to the Trusted Issuers Registry, and its signatures are then verified via ONCHAINID and the Claim Topics Registry.

### 3.2. Contract Interaction During a `transfer` Operation

Now that we understand what each contract does, let's look at how they interact using the token transfer operation as an example. The steps below correspond to the numbers in the diagram:

1. **User** calls `token.transfer(to, amount)`, and the **Token** immediately performs basic checks (not paused, not frozen, sufficient balance).
2. The **Token** checks if the recipient address `to` is verified via `identityRegistry.isVerified()`.
   - The Identity Registry, in turn, retrieves the required claim topics using `getClaimTopics()` from the `ClaimTopicsRegistry` contract, and the trusted issuers using `getTrustedIssuersForClaimTopic()` from the `TrustedIssuersRegistry` contract;
   - The Identity Registry calls `getClaim()` on the user's ONCHAINID to retrieve the claim data, and then calls `isValidClaim()` on the `ClaimIssuer` contract to verify that the claim is valid and has not been revoked.
   - Note: Compliance rules may restrict operations for the sender as well, but the `isVerified()` check is only performed for the recipient.
3. The **Token** calls `compliance.canTransfer(from, to, amount)`.
4. **Compliance** runs `moduleCheck()`, evaluates the rules (geo restrictions, limits, lockup), and returns the decision to the **Token**.
5. If the check passes, the **Token** executes the transfer and notifies **Compliance** via `compliance.transferred(from, to, amount)` (to update counters/state related to the rules).

**Key principle:** all operations go through two layers of verification – Identity (who is allowed to hold the token) and Compliance (what rules apply to the operations).

To understand who controls and manages the contracts, we’ll first go over the roles of the participants in the system.

---

## 4. Participants and Roles

T-REX uses a role-based access control system, implemented via access modifiers in each contract. Below are the roles defined for all contracts in the architecture diagram.

### 4.1. Permissioned Token

The token owner **Owner** operates via the `onlyOwner` modifier and has access to the following functionality:
- `setName()`, `setSymbol()`, `setOnchainID()` – configure the token (name, symbol, ONCHAINID address)
- `setIdentityRegistry()`, `setCompliance()` – link the Identity Registry and Compliance contracts
- `addAgent()`, `removeAgent()` – manage agents (assign/remove TOKEN_AGENT)
- `transferOwnership()` – transfer token ownership

Thus, the Owner can set token information such as name and symbol, link separate registry and compliance contracts to the token, and add specific agents who can directly manage token issuance. The Owner can also add a separate ONCHAINID contract that serves as a unique identifier for the created token — essentially acting as the token’s passport.

**TOKEN_AGENT**, responsible for all functions with the `onlyAgent` modifier:
- `mint(address _to, uint256 _amount)` – mint tokens to a verified investor
- `burn(address _userAddress, uint256 _amount)` – burn tokens
- `pause()`, `unpause()` – pause/resume all token operations
- `setAddressFrozen(address _userAddress, bool _freeze)` – freeze/unfreeze an address (blocks all operations)
- `freezePartialTokens()`, `unfreezePartialTokens()` – freeze/unfreeze part of an address’s balance
- `forcedTransfer(address _from, address _to, uint256 _amount)` – forced transfer (allows bypassing compliance checks, e.g. by court order)
- `recoveryAddress(address _lostWallet, address _newWallet, address _investorOnchainID)` – recover tokens from a lost wallet to a new one (in case the private key is lost)
- Batch operations: `batchMint()`, `batchBurn()`, `batchSetAddressFrozen()`, `batchFreezePartialTokens()`, `batchForcedTransfer()`

Thus, the TOKEN_AGENT can perform all operational tasks: mint and burn tokens, manage the token state (pause), control investor access by freezing addresses or part of their balance, execute forced transfers in emergency situations, and recover access to tokens in case of lost private keys.

### 4.2. Identity Registry

The contract owner, **Owner**, operates via the `onlyOwner` modifier and has access to the following functionality:
- `setIdentityRegistryStorage()` – link the Identity Registry Storage contract
- `setClaimTopicsRegistry()` – link the Claim Topics Registry contract
- `setTrustedIssuersRegistry()` – link the Trusted Issuers Registry contract
- `addAgent()`, `removeAgent()` – manage agents (assign/remove IR_AGENT)
- `transferOwnership()` – transfer ownership

Thus, the Owner can configure the entire registry infrastructure: connect the data storage (`IdentityRegistryStorage`), define which claim types are required for the token (by linking the `ClaimTopicsRegistry` contract), specify the list of trusted KYC providers (by linking the `TrustedIssuersRegistry` contract), and assign agents for day-to-day operations like registering and updating investor data.

**IR_AGENT**, responsible for investor registration via the `onlyAgent` modifier:
- `registerIdentity(address _userAddress, IIdentity _identity, uint16 _country)` – register an investor with their ONCHAINID and country code
- `updateIdentity()` – update the investor’s ONCHAINID
- `updateCountry()` – update the investor’s country code
- `deleteIdentity()` – remove the investor’s record from the registry
- `batchRegisterIdentity()` – batch registration of multiple investors

Thus, the IR_AGENT handles investor onboarding: registers them in the system by linking wallet addresses to their on-chain identities, updates data when needed, and can remove records.

### 4.3. Claim Topics Registry

The registry owner **Owner** operates via the `onlyOwner` modifier and has access to the following functionality:
- `addClaimTopic(uint256 _claimTopic)` – add a claim topic (e.g., KYC_CLAIM)
- `removeClaimTopic()` – remove a claim topic
- `transferOwnership()` – transfer ownership

Thus, the Owner defines which specific claims an investor must have to hold the token. For example, it can require only KYC, or add additional requirements like accredited investor status or residency in a specific country. This allows flexible configuration of access criteria for the token.

### 4.4. Trusted Issuers Registry

The registry owner **Owner** operates via the `onlyOwner` modifier and has access to the following functionality:
- `addTrustedIssuer(IClaimIssuer _trustedIssuer, uint256[] _claimTopics)` – add a trusted issuer with claim topics (the types of claims they are authorized to issue)
- `removeTrustedIssuer()` – remove a trusted issuer
- `updateIssuerClaimTopics()` – update the claim topics assigned to an issuer
- `transferOwnership()` – transfer ownership

Thus, the Owner manages the list of trusted KYC providers who can issue claims for the token. Multiple providers can be added, each authorized to issue specific types of claims. For example, one provider may issue only basic KYC, while another may handle enhanced KYC and accreditation confirmation. This setup allows working with multiple partners and distributing verification responsibilities.

### 4.5. ONCHAINID (identity contract)

Let’s look at the main management keys (essentially, the roles).

The identity owner, via the **MANAGEMENT Key**, operates through the `onlyManager` modifier and has access to the following functionality:
- `addKey()`, `removeKey()` – manage keys (add/remove keys with any purpose)
- `approve()` – approve execution requests (this isn’t directly related to T-REX and is beyond the scope of this article)
- `addClaim()`, `removeClaim()` – manage claims

Thus, the MANAGEMENT Key has full control over the identity: it can add and remove any keys, approve transactions, and manage claims. Typically, this key is held by the backend that manages the investor’s identity on their behalf.

**CLAIM Key** – used with the `onlyClaimKey` modifier:
- `addClaim()`, `removeClaim()` – manage claims (add/remove claims)

Thus, the CLAIM Key can only manage claims and does not have access to key management. This allows for separation of responsibilities: the MANAGEMENT Key controls everything, while the CLAIM Key can be given to a separate service solely for handling claims.

### 4.6. Claim Issuer контракт

The Claim Issuer owner, via the **MANAGEMENT Key**, operates through the `onlyManager` modifier and has access to the following functionality:
- `revokeClaimBySignature(bytes signature)` – revoke a claim using its signature
- `revokeClaim(bytes32 claimId, address identity)` – revoke a claim using the claimId and the identity address
- Inherits all Identity functions (manage keys via `addKey()`, `removeKey()`, manage claims via `addClaim()`, `removeClaim()`)

Thus, the Claim Issuer can revoke previously issued claims on an investor’s ONCHAINID if the investor no longer meets the requirements (e.g., KYC has expired or violations are detected). This is critical for keeping data up to date and ensuring compliance with regulatory requirements. The Claim Issuer can also manage its own keys and add claims to its own identity, since it inherits the functionality of the Identity contract.

Thus, anyone can verify the validity of a claim signed by this Claim Issuer, which is essential for investor verification in the Identity Registry.

### 4.7. Compliance

The Compliance contract owner **Owner** operates via the `onlyOwner` modifier and has access to the following functionality:
- `addModule(address _module)` – add a compliance module (maximum 25 modules)
- `removeModule(address _module)` – remove a compliance module
- `callModuleFunction(bytes callData, address _module)` – call a module function for configuration
- `bindToken()`, `unbindToken()` – bind/unbind a token (can be called by the token itself during initial binding)
- `transferOwnership()` – transfer ownership

Thus, the Owner can flexibly configure compliance rules: add various modules (geo restrictions, limits, lockup, etc.), configure each module by calling its functions, and remove modules when needed. This allows adapting the rules to changing requirements without modifying the core token contract. Modules can be custom-developed based on compliance needs. Ready-to-use modules from Tokeny can be found [here](https://github.com/TokenySolutions/T-REX/tree/main/contracts/compliance/modular/modules).

**Token** – `onlyToken` modifier (only the linked token can call):
- `transferred(address _from, address _to, uint256 _value)` – callback after a transfer (used to update rule state)
- `created(address _to, uint256 _value)` – callback after minting (used to update rule state)
- `destroyed(address _from, uint256 _value)` – callback after burning (used to update rule state)

Thus, the token notifies the Compliance contract about all operations, allowing the connected modules to update their internal state (e.g., limit counters, time-based restrictions, etc.).

## 5. Detailed Breakdown of Contract Interactions

To better understand how contracts interact, let’s take a look at what happens when a user calls `transfer`.

**Permissioned Token**

The user calls `token.transfer(to, amount)`, and the [Token](https://github.com/ERC-3643/ERC-3643/blob/dab1660fe594e17e83d691137ba67272534732ac/contracts/token/Token.sol#L417) performs basic checks, then proceeds to run verification and compliance checks.

In the `transfer` method, basic checks are performed first, then `isVerified` and `canTransfer` are called. After a successful transfer, the `transferred` callback is triggered.

```solidity

function transfer(address _to, uint256 _amount) public override whenNotPaused returns (bool) {
    require(!_frozen[_to] && !_frozen[msg.sender], "wallet is frozen");
    // subtract frozen tokens from available balance
    require(_amount <= balanceOf(msg.sender) - (_frozenTokens[msg.sender]), "Insufficient Balance");
    // check verification only for recipient, compliance rules for both addresses
    if (_tokenIdentityRegistry.isVerified(_to) && _tokenCompliance.canTransfer(msg.sender, _to, _amount)) {
        _transfer(msg.sender, _to, _amount);
        // callback to update module state (counters, limits, etc.)
        _tokenCompliance.transferred(msg.sender, _to, _amount);
        return true;
    }
    revert("Transfer not possible");
}
```

From the Token, we move to the Identity Registry, which checks the verification status of the recipient’s address.

**Identity Registry**

The Token checks the recipient's verification status via [identityRegistry.isVerified()](https://github.com/ERC-3643/ERC-3643/blob/dab1660fe594e17e83d691137ba67272534732ac/contracts/registry/implementation/IdentityRegistry.sol#L174).

The `isVerified` method retrieves the address of the ONCHAINID contract using `identity()` (which internally uses IdentityRegistryStorage), then sequentially checks for the presence of all required claims:

1. Retrieves the list of required claim topics from the **Claim Topics Registry** (e.g., KYC_CLAIM)
2. For each required topic, gets the list of trusted **Claim Issuers** from the **Trusted Issuers Registry** (which KYC providers are authorized to issue that type of claim)
3. Through the user's **ONCHAINID/Identity contract**, fetches the claim data (signature, issuer, data)
4. Verifies with the **Claim Issuer** that the claim is valid and not revoked – this is critically important, as the Claim Issuer can revoke a claim (e.g., when KYC expires or issues are detected), and in that case, the user should no longer have access to the token. Why this is implemented through the issuer and not by removing the claim directly from the investor’s identity will be explained later.

```solidity
function isVerified(address _userAddress) external view override returns (bool) {
    // get Identity contract address from Storage
    if (address(identity(_userAddress)) == address(0)) {return false;}
    // get required claim topics from Claim Topics Registry
    uint256[] memory requiredClaimTopics = _tokenTopicsRegistry.getClaimTopics();
    if (requiredClaimTopics.length == 0) { return true; }

    uint256 foundClaimTopic;
    uint256 scheme;
    address issuer;
    bytes memory sig;
    bytes memory data;
    uint256 claimTopic;
    for (claimTopic = 0; claimTopic < requiredClaimTopics.length; claimTopic++) {
        // get trusted issuers for this claim topic from Trusted Issuers Registry
        IClaimIssuer[] memory trustedIssuers =
            _tokenIssuersRegistry.getTrustedIssuersForClaimTopic(requiredClaimTopics[claimTopic]);
        if (trustedIssuers.length == 0) {return false;}

        bytes32[] memory claimIds = new bytes32[](trustedIssuers.length);
        for (uint256 i = 0; i < trustedIssuers.length; i++) {
            claimIds[i] = keccak256(abi.encode(trustedIssuers[i], requiredClaimTopics[claimTopic]));
        }

        for (uint256 j = 0; j < claimIds.length; j++) {
            // get claim data from ONCHAINID/Identity contract
            (foundClaimTopic, scheme, issuer, sig, data, ) = identity(_userAddress).getClaim(claimIds[j]);

            if (foundClaimTopic == requiredClaimTopics[claimTopic]) {
                // verify claim validity and non-revocation through Claim Issuer
                try IClaimIssuer(issuer).isClaimValid(identity(_userAddress), requiredClaimTopics[claimTopic], sig, data)
                returns(bool _validity) {
                    if (_validity) { j = claimIds.length; }
                    if (!_validity && j == (claimIds.length - 1)) { return false; }
                } catch {
                    if (j == (claimIds.length - 1)) { return false; }
                }
            } else if (j == (claimIds.length - 1)) { return false; }
        }
    }
    return true;
}
```

Now we move on to the ClaimTopicsRegistry contract, which holds the claim topics.

**Claim Topics Registry**

It is called from the Identity Registry to retrieve the list of required claim topics for the token via [getClaimTopics()](https://github.com/ERC-3643/ERC-3643/blob/dab1660fe594e17e83d691137ba67272534732ac/contracts/registry/implementation/ClaimTopicsRegistry.sol#L106).

```solidity
function getClaimTopics() external view override returns (uint256[] memory) {
    return _claimTopics;
}
```

After receiving the list of required topics, the Identity Registry queries the list of trusted Claim Issuers for each topic — those authorized to issue that specific type of claim.

**Trusted Issuers Registry**

It is called from the Identity Registry to retrieve the list of trusted Claim Issuers authorized to issue claims for a specific claim topic via [getTrustedIssuersForClaimTopic()](https://github.com/ERC-3643/ERC-3643/blob/dab1660fe594e17e83d691137ba67272534732ac/contracts/registry/implementation/TrustedIssuersRegistry.sol#L166).

```solidity
function getTrustedIssuersForClaimTopic(uint256 claimTopic) external view override returns (IClaimIssuer[] memory) {
    return _claimTopicsToTrustedIssuers[claimTopic];
}
```

Now the Identity Registry knows which Claim Issuers are trusted for each topic. Next, it queries the user's Identity contract to retrieve the claim data signed by one of the trusted issuers.

**ONCHAINID / Identity contract**

It is called from the Identity Registry to retrieve claim data via [getClaim()](https://github.com/onchain-id/solidity/blob/main/contracts/Identity.sol#L450).
This method stores claims (ERC-734/735) and links the Claim Issuer and signature to the holder’s identity.

```solidity
function getClaim(bytes32 _claimId)
    public
    override
    view
    returns(
        uint256 topic,
        uint256 scheme,
        address issuer,
        bytes memory signature,
        bytes memory data,
        string memory uri
    )
{
    return (
        _claims[_claimId].topic,
        _claims[_claimId].scheme,
        _claims[_claimId].issuer,
        _claims[_claimId].signature,
        _claims[_claimId].data,
        _claims[_claimId].uri
    );
}
```

After retrieving the claim data from the Identity contract, the Identity Registry calls the Claim Issuer to verify that the claim is still valid and has not been revoked.

**Claim Issuer**

It is called from the Identity Registry to validate the claim via [isClaimValid()](https://github.com/onchain-id/solidity/blob/main/contracts/ClaimIssuer.sol#L46). This function checks the signature and whether the claim has been revoked.

```solidity
function isClaimValid(
    IIdentity _identity,
    uint256 claimTopic,
    bytes memory sig,
    bytes memory data)
public override(Identity, IClaimIssuer) view returns (bool claimValid)
{
    bytes32 dataHash = keccak256(abi.encode(_identity, claimTopic, data));
    // use abi.encodePacked to concatenate the message prefix and the message to sign
    bytes32 prefixedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", dataHash));

    // recover address of data signer
    address recovered = getRecoveredAddress(sig, prefixedHash);

    // take hash of recovered address
    bytes32 hashedAddr = keccak256(abi.encode(recovered));

    // check if issuer has CLAIM key (purpose 3) and claim is not revoked
    if (keyHasPurpose(hashedAddr, 3) && (isClaimRevoked(sig) == false)) {
        return true;
    }

    return false;
}
```

**Why is claim validity checked through a separate ClaimIssuer contract and not directly on the investor’s ONCHAINID?**

This is a critically important architectural choice for system security. The investor controls their ONCHAINID contract and can manage claims via the MANAGEMENT key: add or remove claims, and manage the keys of those who are allowed to add claims.

If claim validity were checked only through the investor’s ONCHAINID contract, then after a KYC provider revoked verification, the investor could simply remove the CLAIM key of the ClaimIssuer from their Identity contract.
The system would have no way of knowing the claim was revoked, because the check would rely solely on the ONCHAINID controlled by the investor. As a result, the investor would still retain access to the tokens, despite the revoked verification.

In the current architecture, verification is done through a separate **ClaimIssuer** contract, which maintains its own mapping of revoked claims (`revokedClaims`).
This means that even if the investor removes the ClaimIssuer’s CLAIM key from their ONCHAINID, the ClaimIssuer will still know that the claim was revoked, and `isClaimValid()` will return `false`. Revoking a claim is done by simply calling `revokeClaimBySignature()` or `revokeClaim()` on the ClaimIssuer contract:

```solidity
function revokeClaimBySignature(bytes calldata signature) external override delegatedOnly onlyManager {
    require(!revokedClaims[signature], "Conflict: Claim already revoked");

    revokedClaims[signature] = true;

    emit ClaimRevoked(signature);
}
```

Thus, control over claim validity remains with the ClaimIssuer (KYC provider), not the investor themselves, ensuring regulatory compliance and allowing for quick revocation of access when necessary.

**Identity Registry Storage**

Identity Registry Storage is a separate contract for storing identity data. It allows multiple Identity Registries to connect to it if there’s a need to manage all identities through a single contract. This enables updating the Identity Registry without changing identity data, and also allows reusing one storage contract across multiple registries.

After a successful verification check via `_tokenIdentityRegistry.isVerified(_to)`, the Token moves on to the second critical check — the compliance check. If verification confirms that the recipient is eligible to hold the token (has all required claims), the compliance layer checks whether the transfer operation itself is allowed based on the token’s business rules.

**Compliance + Modules**

The Token calls [compliance.canTransfer()](https://github.com/ERC-3643/ERC-3643/blob/dab1660fe594e17e83d691137ba67272534732ac/contracts/compliance/modular/ModularCompliance.sol#L245) to validate all compliance rules. The Compliance contract then sequentially checks all connected modules — each module must approve the operation.

```solidity
function canTransfer(address _from, address _to, uint256 _value) external view override returns (bool) {
    uint256 length = _modules.length;
    // check all modules - all must return true for transfer to be allowed
    for (uint256 i = 0; i < length; i++) {
        if (!IModule(_modules[i]).moduleCheck(_from, _to, _value, address(this))) {
            return false;
        }
    }
    return true;
}
```

Each module implements the `moduleCheck()` method, which verifies its specific rule. Let’s look at an example: the **SupplyLimitModule**, which restricts the maximum token supply via [moduleCheck()](https://github.com/TokenySolutions/T-REX/blob/main/contracts/compliance/modular/modules/SupplyLimitModule.sol#L134):

```solidity
function moduleCheck(
    address _from,
    address /*_to*/,
    uint256 _value,
    address _compliance
) external view override returns (bool) {
    // check if this is a mint operation (_from == address(0)) and if it would exceed supply limit
    if (_from == address(0) &&
        (IToken(IModularCompliance(_compliance).getTokenBound()).totalSupply() + _value) > _supplyLimits[_compliance]) {
        return false;
    }
    return true;
}
```

The module checks whether the operation would exceed the defined supply limit.
If it’s a mint operation (`_from == address(0)`) and the new totalSupply would exceed the cap, the module returns `false`, blocking the operation.

After a successful transfer, the Token calls the `transferred()` callback in the Compliance contract, which in turn calls `moduleTransferAction()` on all modules to update their internal state (limit counters, time-based restrictions, etc.).
For example, modules can update transfer counters, track lockup periods, or adjust investor-specific limits.

### 5.1. How to Upgrade Contracts

In the T-REX system, contract upgrades are critically important, since permissioned tokens operate in a regulated environment where compliance requirements and business rules can change over time.
Upgrades allow contracts to adapt to new regulations, add necessary features, fix discovered issues, and optimize system performance — all while keeping token addresses and user data unchanged.

**How are contract upgrades implemented?**

T-REX uses the **Implementation Authority** pattern, which works similarly to the **Beacon Proxy** pattern.
In this setup, proxy contracts do not store the implementation address directly — instead, they fetch it from a centralized contract (the Implementation Authority) on each call via the fallback function.
This allows the system logic to be safely upgraded without changing token or identity addresses, and enables updating all proxies at once through a single change in the Authority.

**Difference from the classic Beacon Proxy:**
- A classic Beacon stores a single implementation address
- Implementation Authority stores implementation addresses for all T-REX contracts (Token, Identity Registry, Compliance, etc.) and supports versioning (Major.Minor.Patch)

![alt text](./images/update-architecture.png)

**Upgrade Architecture:**

- **T-REX Implementation Authority** ([TREXImplementationAuthority](https://github.com/ERC-3643/ERC-3643/blob/dab1660fe594e17e83d691137ba67272534732ac/contracts/proxy/authority/TREXImplementationAuthority.sol)) – smart contract that stores the current implementation addresses of T-REX logic contracts (Token, Identity Registry, Compliance, etc.)
- **ONCHAINID Implementation Authority** – a similar smart contract for the ONCHAINID protocol, which manages versions of Identity contracts. ONCHAINID is a separate protocol (ERC-734/ERC-735), designed specifically for use with ERC-3643.
- **Proxies** – deployed contracts (tokens, identities, etc.) are proxies that delegate calls to the implementation addresses defined in their respective Authority.
- **Versioning** – both Authorities support version history (Major.Minor.Patch)

**How the upgrade process works:**

1. **Deploy new logic**: Develop and deploy a new version of the implementation contract (e.g., a fixed version of the Token contract)

2. **Update Authority**: Register the new version in `TREXImplementationAuthority` using the [addAndUseTREXVersion()](https://github.com/ERC-3643/ERC-3643/blob/dab1660fe594e17e83d691137ba67272534732ac/contracts/proxy/authority/TREXImplementationAuthority.sol#L302) method. After updating the Authority, all existing proxies **automatically** start using the new logic on the next call, since proxies fetch the implementation address from the Authority via the fallback function each time.

3. **Automatic proxy upgrade**: Proxy contracts fetch the implementation address from the Authority on every call via the fallback function. This means that after the Authority is updated, all proxies automatically use the new logic without needing to be explicitly upgraded.

**How the proxy gets the implementation from the Authority:**

Each proxy contract gets the implementation address from the Authority through its specific getter.
In `TREXImplementationAuthority`, there’s a dedicated method for each contract type:
`getTokenImplementation()`, `getCTRImplementation()`, `getIRImplementation()`, `getMCImplementation()`, `getTIRImplementation()`, `getIRSImplementation()`. Example: the proxy contract `ClaimTopicsRegistryProxy`:

```solidity
// ClaimTopicsRegistryProxy contract

contract ClaimTopicsRegistryProxy is AbstractProxy {
    constructor(address implementationAuthority) {
        require(implementationAuthority != address(0), "invalid argument - zero address");
        // store Authority address in storage slot
        _storeImplementationAuthority(implementationAuthority);
        emit ImplementationAuthoritySet(implementationAuthority);

        // get CTR implementation address from Authority
        address logic = (ITREXImplementationAuthority(getImplementationAuthority())).getCTRImplementation();

        // initialize implementation contract
        (bool success, ) = logic.delegatecall(abi.encodeWithSignature("init()"));
        require(success, "Initialization failed.");
    }

    fallback() external payable {
        // get CTR implementation address from Authority on each call
        address logic = (ITREXImplementationAuthority(getImplementationAuthority())).getCTRImplementation();

        // delegate call to implementation
        assembly {
            calldatacopy(0x0, 0x0, calldatasize())
            let success := delegatecall(sub(gas(), 10000), logic, 0x0, calldatasize(), 0, 0)
            let retSz := returndatasize()
            returndatacopy(0, 0, retSz)
            switch success
            case 0 {
                revert(0, retSz)
            }
            default {
                return(0, retSz)
            }
        }
    }
}
```

**Example of updating a version in TREXImplementationAuthority:**

```solidity
// Method addAndUseTREXVersion in TREXImplementationAuthority
function addAndUseTREXVersion(Version calldata _version, TREXContracts calldata _trex) external override {
    addTREXVersion(_version, _trex);
    useTREXVersion(_version);
}
```

**Changing the Implementation Authority for a specific token:**

If you need to change the Implementation Authority for a specific token (e.g., switch to a different Authority), use the `changeImplementationAuthority()` method. This will update the authority address across all related proxies.

```solidity
function changeImplementationAuthority(address _token, address _newImplementationAuthority) external override {
    // update Authority for all token contracts (Token, IR, MC, CTR, TIR, IRS)
    IProxy(_token).setImplementationAuthority(_newImplementationAuthority);
    IProxy(_ir).setImplementationAuthority(_newImplementationAuthority);
    IProxy(_mc).setImplementationAuthority(_newImplementationAuthority);
    // ...
}
```

### 5.2. TREXFactory

**What is TREXFactory used for?**

[TREXFactory](https://github.com/ERC-3643/ERC-3643/blob/dab1660fe594e17e83d691137ba67272534732ac/contracts/factory/TREXFactory.sol) is a factory contract that simplifies the deployment of the full T-REX Suite in a single transaction. Instead of manually deploying each contract and setting up the links between them, `TREXFactory` automatically deploys all required proxy contracts via CREATE2, configures their interconnections, assigns agents, attaches compliance modules, and transfers ownership to the specified owner.

**What TREXFactory deploys and configures:**

When `deployTREXSuite()` is called, the factory performs the following actions:

1. **Deploys contracts via CREATE2** (all proxies with deterministic addresses):
   - **TrustedIssuersRegistry** – registry of trusted issuers for claims
   - **ClaimTopicsRegistry** – registry of required claim topics
   - **ModularCompliance** – compliance contract with attached modules
   - **IdentityRegistryStorage** – identity storage (or uses an existing one if an address is provided)
   - **IdentityRegistry** – identity registry linked to TIR, CTR, and IRS
   - **Token** – core token contract linked to IR and Compliance
   - **ONCHAINID for the token** – created automatically via IdFactory (if not provided)

2. **Configuration setup**:
   - Add required claim topics to the CTR
   - Register trusted issuers and their allowed claim topics
   - Link Identity Registry to Identity Registry Storage
   - Assign IR_AGENT and TOKEN_AGENT roles
   - Attach and configure compliance modules
   - Transfer ownership of all contracts to the specified owner
   - Emit `TREXSuiteDeployed` event with the addresses of all deployed contracts

**Data structure for deployment:**

```solidity
// TokenDetails structure
struct TokenDetails {
    address owner;                    // owner of all deployed contracts
    string name;                      // token name
    string symbol;                    // token symbol
    uint8 decimals;                   // token decimals
    address irs;                      // IdentityRegistryStorage address (0 = deploy new)
    address ONCHAINID;                // token ONCHAINID address (0 = create new)
    address[] irAgents;               // IR_AGENT addresses (max 5)
    address[] tokenAgents;            // TOKEN_AGENT addresses (max 5)
    address[] complianceModules;      // compliance module addresses (max 30)
    bytes[] complianceSettings;       // module configuration call data
}

// ClaimDetails structure
struct ClaimDetails {
    uint256[] claimTopics;            // required claim topics (max 5)
    address[] issuers;                // trusted claim issuer addresses (max 5)
    uint256[][] issuerClaims;         // claim topics per issuer
}
```

**Example usage of TREXFactory:**

```solidity
// Prepare token details
ITREXFactory.TokenDetails memory tokenDetails = ITREXFactory.TokenDetails({
    owner: tokenOwner,                // will own all contracts
    name: "My Permissioned Token",
    symbol: "MST",
    decimals: 18,
    irs: address(0),                  // deploy new IRS (or pass existing address)
    ONCHAINID: address(0),            // will be created automatically
    irAgents: [agent1, agent2],        // addresses that can register investors
    tokenAgents: [agent3],             // addresses that can mint tokens
    complianceModules: [countryModule, supplyLimitModule],
    complianceSettings: [
        // encoded call data for module configuration
        abi.encodeWithSignature("batchAllowCountries(uint16[])", [840, 826]), // US, UK
        abi.encodeWithSignature("setSupplyLimit(uint256)", 1000000 * 10**18)
    ]
});

// Prepare claim details
ITREXFactory.ClaimDetails memory claimDetails = ITREXFactory.ClaimDetails({
    claimTopics: [
        uint256(keccak256("KYC_CLAIM"))
    ],
    issuers: [claimIssuer1, claimIssuer2],
    issuerClaims: [
        [uint256(keccak256("KYC_CLAIM"))],  // issuer1 can issue KYC
        [uint256(keccak256("KYC_CLAIM"))]   // issuer2 can issue KYC
    ]
});

// Deploy T-REX suite
trexFactory.deployTREXSuite("my-token-salt-001", tokenDetails, claimDetails);
```

**Deterministic addresses via CREATE2:**

The same `salt` + the same `TREXFactory` = identical contract addresses across all networks.

This allows you to:
- Predict the token address before deployment
- Use the same addresses across different EVM networks

>Important! To get deterministic deployment addresses when using the factory, all implementation contracts must first be deployed deterministically.

**Managing TREXFactory:**

```solidity
// Get Implementation Authority address
address authority = trexFactory.getImplementationAuthority();

// Get IdFactory address
address idFactory = trexFactory.getIdFactory();

// Get token address by salt
address token = trexFactory.getToken("my-token-salt-001");

// Check if token was deployed
address deployedToken = trexFactory.tokenDeployed("my-token-salt-001");

// Change Implementation Authority (only owner)
trexFactory.setImplementationAuthority(newAuthorityAddress);

// Change IdFactory (only owner)
trexFactory.setIdFactory(newIdFactoryAddress);
```

Thus, `TREXFactory` significantly simplifies the token deployment process by automating the creation and configuration of all necessary contracts in the T-REX protocol.

### 5.3. TREXGateway

**What is TREXGateway used for?**

[TREXGateway](https://github.com/ERC-3643/ERC-3643/blob/dab1660fe594e17e83d691137ba67272534732ac/contracts/factory/TREXGateway.sol) is a contract intended for public use and monetization of token deployment via `TREXFactory`. While `TREXFactory` can only be called by its owner, `TREXGateway` allows control over who can deploy tokens and enables charging deployment fees.

**Main purposes of TREXGateway:**

1. **Public deployment access**: Allow not only the factory owner but also other users to deploy tokens (either publicly or through approved deployers)
2. **Deployment monetization**: Charge fees for each token deployment, with the ability to set custom discounts for specific deployers
3. **Access control**: Manage who can deploy tokens (public mode or only approved deployers)
4. **Process simplification**: Automatically generate `salt` using the owner’s address and token name to make deployment easier for end users
5. **Batch operations**: Deploy up to 5 tokens in a single transaction

**How TREXGateway works:**

`TREXGateway` acts as an intermediate layer between users and the `TREXFactory`. When `deployTREXSuite()` is called through the Gateway, the following steps occur:

```solidity
function deployTREXSuite(ITREXFactory.TokenDetails memory _tokenDetails, ITREXFactory.ClaimDetails memory _claimDetails) public override {
    // 1. Check access control
    if(_publicDeploymentStatus == false && !isDeployer(msg.sender)) {
        revert PublicDeploymentsNotAllowed();
    }
    if(_publicDeploymentStatus == true && msg.sender != _tokenDetails.owner && !isDeployer(msg.sender)) {
        revert PublicCannotDeployOnBehalf();
    }

    // 2. Calculate and collect fee (if enabled)
    uint256 feeApplied = 0;
    if(_deploymentFeeEnabled == true) {
        if(_deploymentFee.fee > 0 && _feeDiscount[msg.sender] < 10000) {
            feeApplied = calculateFee(msg.sender);
            IERC20(_deploymentFee.feeToken).transferFrom(
                msg.sender,
                _deploymentFee.feeCollector,
                feeApplied
            );
        }
    }

    // 3. Generate salt automatically from owner + name
    string memory _salt = string(abi.encodePacked(
        Strings.toHexString(_tokenDetails.owner),
        _tokenDetails.name
    ));

    // 4. Call Factory to deploy
    ITREXFactory(_factory).deployTREXSuite(_salt, _tokenDetails, _claimDetails);

    // 5. Emit event with deployment info
    emit GatewaySuiteDeploymentProcessed(msg.sender, _tokenDetails.owner, feeApplied);
}
```

**Access control for deployment:**

The Gateway manages who can deploy tokens through two mechanisms:

**1. Public Deployment:**
- If `publicDeploymentStatus = true`, any user can deploy a token
- **Restriction**: The user can only deploy for themselves (`msg.sender == tokenDetails.owner`)
- To deploy on behalf of another address, the user must be an approved deployer (whitelisted)
- This prevents abuse where someone might deploy tokens for others without permission

**2. Whitelist Mode (Approved Deployers Only):**
- If `publicDeploymentStatus = false`, only addresses on the approved deployer list can deploy tokens
- The deployer list is managed via `addDeployer()` / `removeDeployer()` (callable only by the owner or agent)
- Supports batch addition/removal of up to 500 addresses per transaction
- This mode is used for stricter control over who can deploy tokens

**Management via AgentRole:**

The Gateway inherits from `AgentRole`, which introduces:
- **Owner**: Has full control over the Gateway (can configure fees, public status, and manage the factory)
- **Agents**: Can manage the deployer whitelist and discounts, but cannot modify fee settings or public deployment status

**Fee system:**

The Gateway supports a flexible fee structure for deployments:

```solidity
// Fee structure
struct Fee {
    uint256 fee;           // amount of fee tokens to pay for 1 deployment
    address feeToken;      // address of the token used to pay fees (ERC-20)
    address feeCollector;  // address collecting fees
}
```

**Fee configuration:**

```solidity
// Enable/disable deployment fees
gateway.enableDeploymentFee(true);

// Set fee details
gateway.setDeploymentFee(
    100 * 10**18,              // 100 tokens
    feeTokenAddress,            // ERC-20 token address
    feeCollectorAddress        // address to collect fees
);

// Get current fee details
Fee memory fee = gateway.getDeploymentFee();
bool isEnabled = gateway.isDeploymentFeeEnabled();
```

**Fee discounts:**

Custom fee discounts can be set for specific deployers (expressed in basis points, where 10,000 = 100%):

```solidity
// Apply 50% discount to deployer (5000 = 50%)
gateway.applyFeeDiscount(deployerAddress, 5000);

// Batch apply discounts
address[] memory deployers = [deployer1, deployer2];
uint16[] memory discounts = [2500, 7500]; // 25% and 75% discounts
gateway.batchApplyFeeDiscount(deployers, discounts);

// Calculate fee for specific deployer (with discount applied)
uint256 finalFee = gateway.calculateFee(deployerAddress);
```

**Example usage of TREXGateway:**

```solidity
// TREXGateway contract
// https://github.com/ERC-3643/ERC-3643/blob/dab1660fe594e17e83d691137ba67272534732ac/contracts/factory/TREXGateway.sol

// Prepare token details (same as for TREXFactory)
ITREXFactory.TokenDetails memory tokenDetails = ITREXFactory.TokenDetails({
    owner: msg.sender,              // will own all contracts
    name: "My Permissioned Token",
    symbol: "MST",
    decimals: 18,
    irs: address(0),
    ONCHAINID: address(0),
    irAgents: [agent1, agent2],
    tokenAgents: [agent3],
    complianceModules: [countryModule, supplyLimitModule],
    complianceSettings: [
        abi.encodeWithSignature("batchAllowCountries(uint16[])", [840, 826]),
        abi.encodeWithSignature("setSupplyLimit(uint256)", 1000000 * 10**18)
    ]
});

ITREXFactory.ClaimDetails memory claimDetails = ITREXFactory.ClaimDetails({
    claimTopics: [uint256(keccak256("KYC_CLAIM"))],
    issuers: [claimIssuer1],
    issuerClaims: [[uint256(keccak256("KYC_CLAIM"))]]
});

// Deploy through Gateway (salt is auto-generated from owner + name)
// Fee will be calculated and collected automatically if enabled
gateway.deployTREXSuite(tokenDetails, claimDetails);
```

**Batch deployment:**

The Gateway supports deploying up to 5 tokens in a single transaction:

```solidity
// Prepare arrays of token and claim details
ITREXFactory.TokenDetails[] memory tokenDetailsArray = new ITREXFactory.TokenDetails[](2);
ITREXFactory.ClaimDetails[] memory claimDetailsArray = new ITREXFactory.ClaimDetails[](2);

tokenDetailsArray[0] = tokenDetails1;
tokenDetailsArray[1] = tokenDetails2;
claimDetailsArray[0] = claimDetails1;
claimDetailsArray[1] = claimDetails2;

// Deploy multiple tokens in one transaction
gateway.batchDeployTREXSuite(tokenDetailsArray, claimDetailsArray);
```

**Automatic salt generation:**

Unlike `TREXFactory`, where the `salt` is passed explicitly, `TREXGateway` generates it automatically:

```solidity
// Salt generation in TREXGateway
// https://github.com/ERC-3643/ERC-3643/blob/dab1660fe594e17e83d691137ba67272534732ac/contracts/factory/TREXGateway.sol#L358
string memory _salt = string(abi.encodePacked(
    Strings.toHexString(_tokenDetails.owner),
    _tokenDetails.name
));
```

This means that for the same owner and token name, the same salt will always be generated, ensuring deterministic contract addresses.

**Managing TREXGateway:**

```solidity
// Get factory address
address factory = gateway.getFactory();

// Set factory address (only owner)
gateway.setFactory(newFactoryAddress);

// Transfer factory ownership (only owner)
gateway.transferFactoryOwnership(newFactoryOwner);

// Public deployment management
gateway.setPublicDeploymentStatus(true);  // enable public deployments
bool isPublic = gateway.getPublicDeploymentStatus();

// Deployer management
gateway.addDeployer(deployerAddress);
gateway.batchAddDeployer(deployerAddresses);  // up to 500 addresses
gateway.removeDeployer(deployerAddress);
gateway.batchRemoveDeployer(deployerAddresses);
bool isApproved = gateway.isDeployer(deployerAddress);
```

**When to use TREXGateway:**

- **Public token deployment service**: When you want to allow any user — or a specific list of deployers — to deploy tokens
- **Deployment monetization**: When you need to charge a fee for each token deployment
- **Simplified UX**: When you want to make deployment easier for end users (automatic salt, no need to deal with salt manually)
- **Batch operations**: When you need to deploy multiple tokens in a single transaction
- **Flexible discount system**: When you want to offer discounts to certain deployers (partners, VIP clients)

**When to use TREXFactory directly:**

- **Internal use**: When deployment is done only by the factory owner for their own tokens
- **Full control over salt**: When full control over the salt is needed for deterministic addresses (e.g., for cross-chain deployment)
- **No fees**: When a fee system and access control are not required
- **Custom logic**: When custom pre/post-deployment logic is needed that the Gateway doesn’t support

**Usage Architecture:**

The Gateway serves as a public interface for the Factory, adding a layer of access control, monetization, and simplification of the deployment process.

Thus, `TREXGateway` provides an additional layer of management and control over token deployment, making it more suitable for public use and monetization.

**Practical example:** [Tokeny](https://tokeny.com/t-rex-platform/) – the company that developed ERC-3643 and built a full platform based on the T-REX protocol. They wrapped all protocol contracts with a ready-to-use UI interface, allowing RWA projects to adopt the standard without needing deep technical knowledge. The platform gives issuers tools to manage the entire token lifecycle (deployment via TREXFactory/TREXGateway, compliance setup, investor management), and provides investors with a convenient dashboard to interact with their tokens. This demonstrates how the T-REX standard can be applied in practice to simplify the tokenization of real-world assets.

## Conclusion

T-REX (ERC-3643) shows what regulated securities can look like on public blockchains — not just a standard ERC-20 wrapped in off-chain compliance, but a protocol where KYC/AML, jurisdictions, limits, and corporate actions are formalized in smart contracts. The combination of Identity Registry, ONCHAINID, and ClaimIssuer creates an on-chain identity layer, while ModularCompliance allows regulatory rules to be defined as independent modules that can be updated without migrating the token. The architecture using Implementation Authority and proxies makes it possible to upgrade logic without changing contract addresses, and TREXFactory/TREXGateway turn a complex stack of contracts into a relatively manageable product. At the same time, the protocol remains compatible with the ERC-20 ecosystem and can, in theory, integrate with DeFi — if DeFi learns to handle compliance reverts and work with verified pools.

In practice, the standard is already being used to tokenize over $25 billion worth of assets. The ERC-3643 [Association](https://www.erc3643.org/members) brings together dozens of participants from the financial and tech sectors, including major banks, audit firms, infrastructure platforms, and blockchain developers. Real-world use cases include the issuance of green bonds, fund tokenization, and pilot projects for private equity tokenization.

The main limitations of T-REX lie not so much in the code, but in the surrounding environment.
First, there's the inevitable centralization around the roles of owner and agents, who can pause issuance, freeze addresses, and perform forced transfers. Second, there's the reliance on off-chain KYC providers: large players like Sumsub and others are still not ready to manage private keys and act as full-fledged ClaimIssuers on-chain — signing and revoking claims directly. As a result, an intermediate service often appears in practice, which receives off-chain KYC results and then issues or revokes on-chain claims on its own behalf. Effectively, this service becomes the key actor that connects off-chain verification with the investor’s on-chain status and maintains claim validity.

From an engineering perspective, T-REX already provides a mature foundation for RWA tokenization. The protocol has a clear separation of layers: identity, registries, compliance, and the token itself. This structure makes it possible to build market infrastructure and platform integrations on top, gradually shifting more and more KYC logic from off-chain processes into the blockchain — as traditional providers become more willing to work closer to an on-chain model.

### Links

- [ERC-3643 Standard](https://eips.ethereum.org/EIPS/eip-3643)
- [T-REX GitHub Repository](https://github.com/ERC-3643/ERC-3643)
- [OnchainID GitHub Repository](https://github.com/onchain-id/solidity)
- [ERC-3643 Official Website](https://www.erc3643.org/)
- [Tokeny Solutions](https://tokeny.com/)
