# Interacting with the LayerZero v2 Protocol. Part 4. Omnichain Queries (lzRead)

**Author:** [Alexey Kutsenko](https://github.com/bimkon144) 👨‍💻

If you’ve already figured out classic LayerZero messages (push model: you send a message from one network and receive it on another), the next step is to learn how to read the state of other networks without deploying your own contracts there and without sending two messages back and forth.
For this, LayerZero v2 has **lzRead** — a request–response (pull) pattern: a contract on the source network sends a request (`lzSend`), and the response comes back to the source network and is processed in `lzReceive`.

![alt text](./images/preview.png)

In this article, we’ll look at how lzRead works, which contracts it consists of, and how to write and configure a contract to fetch prices from a Uniswap V3 pool — with a code walkthrough and deployment in [Remix](https://remix.ethereum.org/).

**Terminology:**

- **Origin chain** — the network where your contract is deployed and from which it requests data from another network.
- **Data chain (target chain)** — the network from which you read data.
- **Endpoint** — a system smart contract in each network provided by LayerZero, through which incoming and outgoing messages pass.
- **EID (Endpoint ID)** — a numeric identifier of a network in the LayerZero protocol.
- **Read Channel** — a separate message channel specifically for reads; its ID and supported paths are listed in the [deployment tables](https://docs.layerzero.network/v2/deployments/read-contracts).
- **DVN (Decentralized Verifier Network)** — a network of verifiers that confirm the correctness of the response.
- **ReadLib1002** — a message library for reads; lzRead requires compatible libraries and a DVN with access to archive nodes.

---

## How lzRead Works

lzRead allows a contract to request and receive state from other blockchains. At its core is the idea of **BQL (Blockchain Query Language)** — a unified way to formulate queries (what to read, from which network, at which block/time), receive responses, and process them if needed.

![lzRead flow diagram](./images/lzRead_diagram.svg)

Step by step:

1. **Building the query** — the application assembles a request: what data is needed, from which target network, and at which block or timestamp. The request is encoded into a standard command according to the BQL schema.
2. **Sending the request** — the command is sent through the LayerZero Endpoint via a dedicated read channel (not the regular messaging channel). The channel explicitly indicates that this is a request expecting a response, not just a state change.
3. **Data fetch and verification (DVN data fetch and verification)** — DVNs receive the request, fetch the data from an archive node of the required network, and, if needed, apply off-chain compute: **lzMap** (transforming responses from one or multiple networks) and **lzReduce** (aggregating multiple responses into a single result). Each DVN generates a cryptographic hash of the result to verify its integrity.
_In this article, we make a single request to a single network, so we don’t configure Compute; how to set up lzMap/lzReduce for multi-network or aggregation scenarios can be found in the [lzRead documentation](https://docs.layerzero.network/v2/developers/evm/lzread/overview#lzmap)._
4. **Response handling** — after verification by the required number of DVNs, the Endpoint delivers the final response back to the origin chain. The receiving contract processes it in `_lzReceive()`: decodes the payload and uses the returned data.

---

## Contract Architecture

![OApp Architecture](./images/oapp-architecture.png)

To allow a contract to send read requests and receive responses, it must inherit from [OAppRead.sol](https://github.com/LayerZero-Labs/LayerZero-v2/blob/ab9b083410b9359285a5756807e1b6145d4711a7/packages/layerzero-v2/evm/oapp/contracts/oapp/OAppRead.sol#L4). The inheritance chain is:

- [OAppRead.sol](https://github.com/LayerZero-Labs/LayerZero-v2/blob/ab9b083410b9359285a5756807e1b6145d4711a7/packages/layerzero-v2/evm/oapp/contracts/oapp/OAppRead.sol#L4) -> [OApp.sol](https://github.com/LayerZero-Labs/LayerZero-v2/blob/ab9b083410b9359285a5756807e1b6145d4711a7/packages/layerzero-v2/evm/oapp/contracts/oapp/OApp.sol)
- OApp -> [OAppReceiver.sol](https://github.com/LayerZero-Labs/LayerZero-v2/blob/ab9b083410b9359285a5756807e1b6145d4711a7/packages/layerzero-v2/evm/oapp/contracts/oapp/OAppReceiver.sol) и [OAppSender.sol](https://github.com/LayerZero-Labs/LayerZero-v2/blob/ab9b083410b9359285a5756807e1b6145d4711a7/packages/layerzero-v2/evm/oapp/contracts/oapp/OAppSender.sol)
- OAppReceiver, OAppSender -> [OAppCore.sol](https://github.com/LayerZero-Labs/LayerZero-v2/blob/ab9b083410b9359285a5756807e1b6145d4711a7/packages/layerzero-v2/evm/oapp/contracts/oapp/OAppCore.sol)
- OAppCore -> [Ownable](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol) (OpenZeppelin)

The contracts are pretty simple — it makes sense to look through them before the next step.

To implement lzRead, you need a contract that inherits from OAppRead and implements three parts: building the request, estimating the fee, and handling the response. In the next section, you’ll see an example of such a contract and its methods.

---

## Example OApp Contract (UniswapV3ObserveRead.sol)

We’ve already written a ready-to-use contract [UniswapV3ObserveRead.sol](./UniswapV3ObserveRead.sol). It requests, from another network (the data chain), the result of calling `observe()` on a Uniswap V3 pool — the cumulative tick and liquidity values over a specified time window. From these, you can compute **TWAP** (Time-Weighted Average Price) — the average asset price over the period — without deploying a contract on the pool’s network. The response is delivered back to our contract on the origin chain. The contract inherits **OAppRead** and **OAppOptionsType3**.

- **OAppRead** — sends the read request and receives the response in `_lzReceive`.
- **OAppOptionsType3** — a [library](https://github.com/LayerZero-Labs/LayerZero-v2/blob/main/packages/layerzero-v2/evm/oapp/contracts/oapp/libs/OAppOptionsType3.sol) for message options. The owner sets enforced options via **`setEnforcedOptions(EnforcedOptionParam[])`** for `(eid, msgType)` pairs; they are stored in `enforcedOptions[eid][msgType]`. **`combineOptions(eid, msgType, _extraOptions)`** builds the final options: it merges these enforced options with the caller’s options — passed as `_extraOptions` in `quoteObserve`/`readObserve` (on the executor side, the values are added together) — and forwards the result to `_lzSend` and `_quote`. For lzRead, options use the Type3 format: gas for response delivery, response size in bytes, and value for the executor; they are constructed via `addExecutorLzReadOption(gas, responseSizeBytes, value)`. If enforced options are already set with sufficient gas and response size, you can call with `_extraOptions = 0x`; otherwise, pass the encoded options.

When deploying, we pass five arguments:

```solidity
constructor(
    address _endpoint,
    uint32 _readChannel,
    uint32 _targetEid,
    address _targetPoolAddress,
    address _config              // the LzReadConfig contract — deploy it first
) OAppRead(_endpoint, _config) Ownable(_config) {
    READ_CHANNEL = _readChannel;
    targetEid = _targetEid;
    targetPoolAddress = _targetPoolAddress;
    _setPeer(READ_CHANNEL, AddressCast.toBytes32(address(this)));
}
```

- **_endpoint** — the Endpoint address on the deployment network (origin). It is taken from [Chains](https://docs.layerzero.network/v2/developers/evm/technical-reference/deployed-contracts) for the selected origin network.
- **_readChannel** — the read channel identifier. It is taken from the [table](https://docs.layerzero.network/v2/deployments/read-contracts) based on the origin and data chain pair.
- **_targetEid** — the EID of the target network (the one we read the pool from). It is taken from [Chains](https://docs.layerzero.network/v2/developers/evm/technical-reference/deployed-contracts) for the selected data chain.
- **_targetPoolAddress** — the address of the Uniswap V3 pool on the data chain.
- **_config** — the address of the [LzReadConfig.sol](./LzReadConfig.sol) contract (deploy it first). It is passed to both OAppRead and Ownable: the config contract immediately becomes the owner of the OApp, and the OApp address is not stored in the config. After deployment, call `setDelegate(_config)` on the OApp. Later (from the config owner): - change the delegate — `setOAppDelegate(oapp, delegate)`; - set/update the read channel — `setOAppReadChannel(oapp, channelId, active)` (`active = false` to disable receiving); - transfer ownership — `transferOAppOwnership(oapp, newOwner)`.

Inside the contract, `READ_CHANNEL`, `targetEid`, and `targetPoolAddress` are stored, and `_setPeer(READ_CHANNEL, AddressCast.toBytes32(address(this)))` is called — this tells the protocol to deliver responses for this read channel to this contract.

### Building a Read Request

The method builds a read command using the [ReadCodecV1](https://github.com/LayerZero-Labs/devtools/blob/39dc7f88a1627db4217144e50ee2f07b39935741/packages/oapp-evm/contracts/oapp/libs/ReadCodecV1.sol#L26) library (for encoding and decoding calls).

The goal is to encode a call to `observe(secondsAgos)` on a Uniswap V3 pool.

```solidity
function getCmd(uint32[] calldata secondsAgos) public view returns (bytes memory) {
    bytes memory callData =
        abi.encodeWithSelector(IUniswapV3PoolObserve.observe.selector, secondsAgos);

    EVMCallRequestV1[] memory req = new EVMCallRequestV1[](1);
    req[0] = EVMCallRequestV1({
        appRequestLabel: 1,                    // request tag
        targetEid: targetEid,                 // the EID of the network to read data from
        isBlockNum: false,                    // read by timestamp (true = by block number)
        blockNumOrTimestamp: uint64(block.timestamp),  // the timestamp at which the data will be read
        confirmations: 15,                     // how many block confirmations are required
        to: targetPoolAddress,                 // the contract address on the data chain
        callData: callData                     // the encoded method that will be called to retrieve the information
    });

    return ReadCodecV1.encode(0, req);        // version 0, a single request without Compute
}
```

- **secondsAgos** — an array of “how many seconds ago” values for `observe`; for example, `[3600, 0]` — data from one hour ago and “now”.

You can add multiple requests to the array (including requests to different networks).

### Estimating the Request Fee

Before sending the request, call a view function to determine how much native token (or LZ token) needs to be sent along with `readObserve`.

```solidity
function quoteObserve(
    uint32[] calldata secondsAgos,   // the same parameters that will be passed to `readObserve`
    bytes calldata _extraOptions,    // encoded options for the executor
    bool _payInLzToken                // true = pay in LZ token, false = pay in the network’s native token
) external view returns (MessagingFee memory fee);
```

**Why `_payInLzToken`:** you specify in advance how you will pay when calling `readObserve` — in the network’s native token or in the LZ token. The `fee` returns both values (`nativeFee` and `lzTokenFee`); use the one that matches your choice: - if `false`, check `fee.nativeFee` and pass this amount as `msg.value` in `readObserve`; - if `true`, use `fee.lzTokenFee`, and the LZ token payment goes through the protocol mechanism (approve + transfer). In the rest of this article, we assume payment in the native token (`_payInLzToken = false`).

A `fee` struct is returned (with fields `nativeFee` and `lzTokenFee`).

### Sending a Read Request: `readObserve`

Sends the read request built by `getCmd(secondsAgos)` to the read channel. Must be called as **payable**, with `msg.value >= fee.nativeFee` (the value returned by `quoteObserve`).

```solidity
function readObserve(
    uint32[] calldata secondsAgos,   // an array for `observe`, for example `[3600, 0]`
    bytes calldata _extraOptions     // the same options as in `quoteObserve` (see above; during testing, `0x`)
) external payable returns (MessagingReceipt memory receipt);
```

Returns a `MessagingReceipt` (for example, to track the transaction in a block explorer). The response will arrive asynchronously in `_lzReceive`.

### Receiving the Response: `_lzReceive`

Called by the protocol when the verified response is delivered to the origin chain. The `_message` contains the encoded return values of `observe()`: two arrays `(int56[] tickCumulatives, uint160[] secondsPerLiquidityCumulativeX128s)`.

```solidity
function _lzReceive(
    Origin calldata,       // message metadata (`srcEid`, `sender`, `nonce`)
    bytes32,               // guid message
    bytes calldata _message,  // response: abi-encoded (`int56[]`, `uint160[]`)
    address,                // executor
    bytes calldata
) internal override {
    (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s) =
        abi.decode(_message, (int56[], uint160[]));
    emit ObserveResult(tickCumulatives, secondsPerLiquidityCumulativeX128s);
}
```

We decode the payload and emit the `ObserveResult` event — this lets you verify that the data arrived.

## Application Configuration

Configuration comes in two types: at the **endpoint** level (send/receive libraries, ReadLib config with executor and DVN requirements) and at the **OApp** level (enforced options and, if needed, changing the read channel).

Endpoint configuration can only be called by the OApp itself or its **delegate**; OApp configuration (for example, `setEnforcedOptions`) can only be called by the **owner** of the OApp. For this reason, in the constructor of `UniswapV3ObserveRead.sol`, we assign our config contract as both the owner and the delegate.

The config contract helps set up these parameters: [LzReadConfig.sol](./LzReadConfig.sol).

Configuration can be performed by the deployer, the contract itself (when called from its address), or a delegate — via `setDelegate(address _delegate)` from [OAppCore.sol](https://github.com/LayerZero-Labs/LayerZero-v2/blob/ab9b083410b9359285a5756807e1b6145d4711a7/packages/layerzero-v2/evm/oapp/contracts/oapp/OAppCore.sol).

**Deployment and configuration order:**

1. Deploy [LzReadConfig.sol](./LzReadConfig.sol) with one argument: `_endpoint` (the Endpoint address for the network from the [table](https://docs.layerzero.network/v2/deployments/read-contracts)).
2. Deploy [UniswapV3ObserveRead.sol](./UniswapV3ObserveRead.sol), passing the same endpoint address and the address of the newly deployed config contract as constructor arguments.
3. **Configure both the endpoint and the OApp in a single call** — the config method `configureFull(_oapp, _readChannel, _readLib, _libConfig, _receiveGracePeriod, _enforced)` sets the send/receive libraries and the ReadLib configuration on the endpoint, and sets the enforced options (gas and response size for lzRead) on the OApp.
Arguments:
   - **_oapp** — the address of the deployed OApp (UniswapV3ObserveRead). Get it from Remix after deployment.
   - **_readChannel** — the read channel identifier for the network pair (origin → data chain). It is taken from the [Read Data Channels table](https://docs.layerzero.network/v2/deployments/read-contracts) for your origin and target networks.
   - **_readLib** — the address of the Read library (for example, ReadLib1002). It is also taken from the [same table](https://docs.layerzero.network/v2/deployments/read-contracts) for your network.
   - **_libConfig** — the ReadLib configuration on the endpoint: `(executor, requiredDVNCount, optionalDVNCount, optionalDVNThreshold, requiredDVNs[], optionalDVNs[])`. The addresses of **executor**, **requiredDVNs**, **optionalDVNs**, and the array of required DVNs can be selected from the [table](https://docs.layerzero.network/v2/deployments/read-contracts).
   - **_receiveGracePeriod** — the delay (in seconds) before the receive library becomes active; usually **0** (immediate).
   - **_enforced** — enforced options for lzRead: a struct with three fields. **eid** (`uint32`) = the same readChannel; **msgType** (`uint16`) = 1 for lzRead; **options** (`bytes`) — the encoded options (gas, response size in bytes, value).
   - **Options field:** Unfortunately, the LayerZero libraries do not expose a helper method to encode these parameters, so I created a small [tool](./tools/options-encoder.html) for you to encode them conveniently. Download the tool file and open it in your browser.

_In the OApp constructor, `_setPeer(READ_CHANNEL, ...)` is already called. You can change the read channel or disable receiving responses via the config: the config owner calls `LzReadConfig.setOAppReadChannel(oappAddress, channelId, active)` (`active = false` to disable)._

_An alternative to our manual deployment, configuration, and data reading approach is using the repository with a ready-made set of scripts — [LayerZero CLI](https://docs.layerzero.network/v2/get-started/create-lz-oapp/start)._

## Practice

Imagine this: on our origin network, **Base Sepolia**, there is no price available for the token that our contract needs. Using lzRead, we can request price data from another network — for example, from a Uniswap V3 pool contract on **Ethereum Sepolia**, where this token is already being traded.

Below is the step-by-step flow: deploy the contract on the origin chain, estimate the fee via `quoteObserve`, send the read request via `readObserve`, check the transaction in LayerZero Scan, and verify the result (the `ObserveResult` event).

_You can repeat the steps using the addresses listed below or substitute your own from the [list](https://docs.layerzero.network/v2/developers/evm/technical-reference/deployed-contracts), making sure that a Read Path exists for your network pair in the [Read Data Channels](https://docs.layerzero.network/v2/deployments/read-contracts) and that the data chain has a suitable Uniswap V3 pool with liquidity._

_Tip:_ after deployment, immediately click **Pin contract for current workspace** (the icon next to the contract address in Remix), and copy the addresses — when you switch networks, deployed contracts are reset. To call methods on an already deployed contract, go to the **Contract** tab, select the contract, and paste its address into **At Address**.

In this example: **origin** = Base Sepolia, **data chain** = Ethereum Sepolia.

1. Open [Remix](https://remix.ethereum.org/) and add the contracts [LzReadConfig.sol](./LzReadConfig.sol) and [UniswapV3ObserveRead.sol](./UniswapV3ObserveRead.sol).
2. Gather all the data for deployment:
- Get the Endpoint for the origin network from [this table](https://docs.layerzero.network/v2/deployments/deployed-contracts);
- Get the EID for the data chain [here](https://docs.layerzero.network/v2/deployments/deployed-contracts);
- Find the `targetPoolAddress` for the target network via [Uniswap deployments](https://docs.uniswap.org/contracts/v3/reference/deployments/ethereum-deployments). Make sure the `observe` call on the pool returns data;
- Find the `readChannel` in this [table](https://docs.layerzero.network/v2/deployments/read-contracts) by specifying the origin and target data networks;
- Find the `readLib` for the origin network [here](https://docs.layerzero.network/v2/deployments/read-contracts);
- Find the `libConfigParams` for the origin network there as well. It includes parameters such as: `executor`, `requiredDVNCount`, `optionalDVNCount`, `optionalDVNThreshold`, `requiredDVNs`, `optionalDVNs`;
- `enforced` uses the already known `readChannel`, `msgType = 1`, and `options`, which we encode using the dedicated tool created for this purpose;

   ![alt text](./images/set-config.png)
   ![alt text](./images/setconfig-dependencies.png)

3. Deploy first [LzReadConfig.sol](./LzReadConfig.sol) (argument: `endpoint`), then [UniswapV3ObserveRead.sol](./UniswapV3ObserveRead.sol) (`endpoint`, `readChannel`, `targetEid`, `targetPoolAddress`, and the `LzReadConfig` address).

   ![alt text](./images/remix-first-deploy.png)
   ![alt text](./images/remix-second-deploy.png)
4. Next, on LzReadConfig, call `configureFull(OApp, readChannel, readLib, libConfigParams, 0, enforcedParams)`.

   ![alt text](./images/configuration.png)


5. Estimate the fee: call `quoteObserve(secondsAgos, extraOptions, false)` on the deployed `UniswapV3ObserveRead.sol` contract. For example, `secondsAgos = [3600, 0]` to get a TWAP over the last hour. You can pass `0x` as `extraOptions` — enforced options are already set.

   ![Calling quoteObserve in Remix](./images/remix-quote-observe.png)

6. In Remix, set the **Value** field to `fee.nativeFee` (in Wei) and call `readObserve(secondsAgos, extraOptions)`.

   ![Value and calling `readObserve`](./images/remix-read-observe-value.png)

7. After the transaction is confirmed, you can check the status of your request in the explorer for the `UniswapV3ObserveRead.sol` address at [testnet.layerzeroscan.com](https://testnet.layerzeroscan.com/).

   ![LayerZero Scan: transaction page (Inflight → Delivered)](./images/layerzero-scan-delivered.png)

   ![LayerZero Scan: Response transaction](./images/layerzero-scan-response.png)

8. After the status becomes **Delivered**, `_lzReceive` will be called on the origin chain and the `ObserveResult` event will be emitted. You can verify this by following the link to the Response transaction in the logs section.

   ![Remix: `ObserveResult` event logs](./images/remix-observe-result-logs.png)

## Conclusion

With lzRead, your contract on one network can request data from another network and receive the response back — without deploying contracts there and without sending two separate messages back and forth. You build the request, send it through the read channel, and handle the response in `_lzReceive`.
As mentioned earlier, there is also additional functionality — Compute ([lzMap](https://docs.layerzero.network/v2/developers/evm/lzread/overview#lzmap), [lzReduce](https://docs.layerzero.network/v2/developers/evm/lzread/overview#lzreduce)).

---

## Links

- [Docs: Omnichain Queries (lzRead)](https://docs.layerzero.network/v2/developers/evm/lzread/overview)
- [Read Data Channels](https://docs.layerzero.network/v2/deployments/read-contracts)
- [EVM DVN and Executor Configuration](https://docs.layerzero.network/v2/developers/evm/configuration/dvn-executor-config)
- [The lzRead Deep Dive (MapReduce, BQL)](https://layerzero.network/blog/the-lzread-deep-dive)
- [GitHub: LayerZero v2](https://github.com/LayerZero-Labs/LayerZero-v2)
- [LayerZeroScan](https://layerzeroscan.com/) / [Testnet LayerZeroScan](https://testnet.layerzeroscan.com/)
