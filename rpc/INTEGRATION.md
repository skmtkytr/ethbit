# rpc — integration with a live node

This package is **transport-free**. It builds and parses JSON-RPC bodies; it
does not open sockets. To talk to a real node you pair `rpc` with whatever
HTTP / WebSocket client your target supports.

## Reference endpoint

The fixture tests in `sepolia_fixtures_test.mbt` were captured from
<https://ethereum-sepolia-rpc.publicnode.com> (Sepolia, no auth required).
Any standard JSON-RPC node will work — Alchemy / Infura / a self-hosted
geth / reth / erigon / your local Anvil. Replace the URL.

## Workflow

```
                  build               POST                parse
@rpc.Request  ──>  body String  ──>  network  ──>  body String  ──>  @rpc.Response
        encode_request                                  decode_response
                                                              │
                                                              ▼
                                                  parse_<type> per method
                                                  (parse_block, parse_transaction_info,
                                                   parse_transaction_receipt, parse_log,
                                                   parse_fee_history, parse_syncing_status,
                                                   parse_access_list_result,
                                                   parse_hex_quantity, parse_hex_bytes …)
```

## Smoke test from the shell

Pick any method. Field order and ID can vary between clients; the body
below is what `encode_request` produces, but the spec doesn't require it.

```fish
set URL https://ethereum-sepolia-rpc.publicnode.com

# eth_chainId — should return 0xaa36a7 (Sepolia = 11155111)
curl -sS -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}' \
  $URL

# eth_blockNumber
curl -sS -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' \
  $URL

# eth_getBalance for vitalik.eth (Sepolia balance varies)
curl -sS -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_getBalance",
       "params":["0xd8da6bf26964af9d7eed9e03e53415d37aa96045","latest"]}' \
  $URL

# eth_feeHistory: last 4 blocks, 25th and 75th percentile reward
curl -sS -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_feeHistory",
       "params":["0x4","latest",[25,75]]}' \
  $URL

# eth_getTransactionByHash for a known Sepolia tx
curl -sS -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_getTransactionByHash",
       "params":["0xf63d7d591f84a07f02805339e48f63d407f7323b3917c3a49b624474b4b290fc"]}' \
  $URL
```

## End-to-end shape (MoonBit pseudocode)

The transport layer is the user's responsibility. Sketch:

```moonbit
// 1. build the request
let req = @rpc.eth_get_balance(address_bytes, "latest")
let body = @rpc.encode_request(req)

// 2. send via your transport. Possible host calls:
//    - in JS:    const res = await fetch(url, {method:'POST',
//                                              headers:{'Content-Type':'application/json'},
//                                              body}); const text = await res.text();
//    - in Node:  https.request / undici
//    - in native: a sockets / TLS lib of your choosing
//    - via FFI:  the host imports above
let response_body : String = host_post(url, body)

// 3. decode and parse
match @rpc.decode_response(response_body) {
  Some(@rpc.Response::Ok(_, result)) =>
    match @rpc.parse_hex_quantity(result) {
      Some(wei) => println("balance: \{wei} wei")
      None => println("malformed quantity")
    }
  Some(@rpc.Response::Err(_, e)) =>
    println("rpc error \{e.code}: \{e.message}")
  None =>
    println("body was not a valid JSON-RPC response")
}
```

For each method, dispatch to the matching `parse_<type>`:

| Method | Result parser |
|---|---|
| `eth_chainId`, `eth_blockNumber`, `eth_gasPrice`, `eth_getBalance`, `eth_getTransactionCount`, `eth_estimateGas`, `eth_blobBaseFee`, `eth_maxPriorityFeePerGas` | `parse_hex_quantity` |
| `eth_getCode`, `eth_getStorageAt`, `eth_call`, `eth_sendRawTransaction`, `web3_sha3` | `parse_hex_bytes` |
| `eth_getBlockByHash`, `eth_getBlockByNumber` | `parse_block` |
| `eth_getTransactionByHash`, `eth_getTransactionByBlockHashAndIndex`, `eth_getTransactionByBlockNumberAndIndex` | `parse_transaction_info` |
| `eth_getTransactionReceipt` | `parse_transaction_receipt` |
| `eth_getLogs` | `parse_logs` |
| `eth_feeHistory` | `parse_fee_history` |
| `eth_syncing` | `parse_syncing_status` |
| `eth_createAccessList` | `parse_access_list_result` |

For raw / generic results (e.g. `eth_accounts` returning `Array[String]`),
the `Json` value from `Response::Ok` is right there — pattern-match on it
directly without going through a typed parser.

## Subscription (WebSocket)

The `rpc` package's WS layer is also encoder/decoder only:

```moonbit
let req = @rpc.eth_subscribe(@rpc.SubscriptionKind::NewHeads)
let body = @rpc.encode_request(req)
// send over WebSocket; the server replies with a regular Response::Ok
// containing the subscription id. Subsequent inbound frames are handled
// by parse_notification:
match @rpc.parse_notification(frame_body) {
  Some(notif) => handle(notif.subscription, notif.result)
  None => /* maybe a regular response, fall through to decode_response */
}
```

The WebSocket frame layer itself is in the [`ws`](../ws/README.md) package
(handshake + frame parse/build). The TCP/TLS layer below that is per-target.

## Refreshing the Sepolia fixtures

`sepolia_fixtures_test.mbt` pins a handful of real responses. If the
endpoint goes away or you want to validate against a different chain:

1. Pick a recent block / tx on the chain. Vitalik's mainnet address
   `0xd8da6bf26964af9d7eed9e03e53415d37aa96045` is convenient because
   it is rarely zero on any fork.
2. Hit each method via `curl` against your endpoint.
3. Paste the response bodies into `sepolia_fixtures_test.mbt` (each one is
   a single-line `#|...` literal).
4. Re-run `moon test -p skmtkytr/ethbit/rpc -F 'sepolia*'`.

The fixtures are pinned values, so changes in chain state do not invalidate
the tests.

## Built-in fetch transport (js + native)

A `fetch_post` / `fetch_request` pair is exposed on both backends with
the same callback API:

```moonbit
@rpc.fetch_post(url, body, on_ok, on_err)        // raw POST
@rpc.fetch_request(url, request, on_ok, on_err)  // encode + POST + decode
```

| target | implementation | requirements |
|---|---|---|
| `js` | host `fetch` global via `extern "js"` | Node 18+ / Bun / Deno / browser |
| `native` | libcurl via `extern "c"` + native-stub | libcurl headers + `-lcurl` link |

Semantics:
- The js variant is non-blocking from the JS event loop's perspective —
  callbacks fire when the Promise settles.
- The native variant blocks during `curl_easy_perform` and invokes the
  callback inline before returning.

The wasm and wasm-gc backends do not have a built-in transport. Bring
your own (host imports / WASI).

Working example: [`examples/rpc-fetch`](../examples/rpc-fetch/main.mbt).
Run it on either target:

```fish
moon run --target js     examples/rpc-fetch
moon run --target native examples/rpc-fetch
```

Output (live against Sepolia, identical on both):
```
eth_chainId           = 11155111
eth_blockNumber       = 10753729
balance(vitalik) wei  = 57229714527866035076
```

### Linker flags for native

A package that uses `@rpc.fetch_*` on native must add `-lcurl` to its own
link flags so the libcurl symbols resolve at the final binary's link step.
The `rpc` package already does this for itself, but downstream consumers
must opt in:

```
// in your application's moon.pkg
options(
  "is-main": true,
  link: {
    "native": {
      "stub-cc-link-flags": "-lcurl",
    },
  },
)
```

`stub-cc-link-flags` (rather than the more obvious `cc-link-flags`) keeps
moon's `tcc -run` fast-path enabled. With `cc-link-flags` moon falls back
to the system `cc` to produce a real `.exe`, which still works but is
slightly slower to build.

## What's NOT here

- HTTP / WebSocket clients on native and wasm-gc targets. Tracked in
  [`TODO.md`](../TODO.md).
- Long-poll / batching helpers. JSON-RPC 2.0 batch (an array of requests)
  is not yet supported by `encode_request` / `decode_response`.
- Throttling, retry, request signing. Out of scope for this package.
