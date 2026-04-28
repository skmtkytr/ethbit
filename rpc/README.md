# rpc

JSON-RPC 2.0 encoder/decoder for the Ethereum execution-layer API. Builds
canonical request bodies and parses response/notification bodies. There is
**no transport** — feed `encode_request` output to your HTTP/WS client and
pass the response body to `decode_response` / `parse_notification`.
Spec: <https://www.jsonrpc.org/specification>.

## Status

Covers the standard execution-client method namespaces:

- `eth_*` — block / state / tx / call / logs / filters
- `eth_subscribe`, `eth_unsubscribe`, plus `parse_notification` for
  WS-pushed `eth_subscription` envelopes
- `debug_*` — `traceTransaction`, `traceCall`, `traceBlock*`, `getRaw*`
- `trace_*` — Parity-style: `trace_block`, `trace_call`, `trace_callMany`,
  `trace_filter`, `trace_get`, `trace_rawTransaction`, `trace_replay*`,
  `trace_transaction`
- `net_*`, `web3_*`, `txpool_*`

Request bodies are built by deterministic string concatenation so byte-exact
tests are easy. Response decoding uses `moonbitlang/core/json`.
Convenience constructors return a `Request` with `id = 0`; callers should
override before sending.

## Import

```
// In your moon.pkg:
import {
  "skmtkytr/ethbit/rpc" @rpc,
}
```

## Quick example

```moonbit
// Build and encode a JSON-RPC request.
let req = @rpc.eth_get_balance(addr_bytes, "latest")
let body : String = @rpc.encode_request({ ..req, id: 1 })
// pump body into your HTTP client...

// Decode the response.
let resp = @rpc.decode_response(http_body).unwrap()
match resp {
  Ok(_id, result_json) => {
    let bal = @rpc.parse_hex_quantity(result_json).unwrap()
    // ...
  }
  Err(_id, err) => abort(err.message)
}

// WebSocket subscription.
let sub_req = @rpc.eth_subscribe(NewHeads)
// send encode_request(sub_req) over WS, then for each received frame:
let n = @rpc.parse_notification(frame_payload_string).unwrap()
// n.subscription : Bytes, n.result : Json
```

## API

### Core types and codec

| Symbol | Type | Description |
|---|---|---|
| `Request` | `struct { id, method, params }` | JSON-RPC request |
| `Response` | `enum Ok(Int, Json) \| Err(Int?, ErrorObject)` | parsed response |
| `ErrorObject` | `struct { code, message }` | – |
| `encode_request` | `Request -> String` | canonical body |
| `decode_response` | `String -> Response?` | – |

### Hex codec helpers

| Symbol | Type | Description |
|---|---|---|
| `parse_hex_quantity` | `Json -> @bigint.BigInt?` | "0x…" Quantity → BigInt |
| `parse_hex_bytes` | `Json -> Bytes?` | "0x…" Data → Bytes |
| `quantity_from_bytes` | `Bytes -> String` | BE bytes → "0x…" Quantity |
| `quantity_from_bigint` | `BigInt -> String` | – |
| `quantity_from_int` | `Int -> String` | – |
| `data_from_bytes` | `Bytes -> String` | bytes → "0x…" Data hex |

### Param objects

| Symbol | Type | Description |
|---|---|---|
| `TxCall` | `struct { from, to, gas, gas_price, max_priority_fee_per_gas, max_fee_per_gas, value, data }` | call object; `None` fields omitted |
| `LogFilter` | `struct { from_block, to_block, address, topics, block_hash }` | filter object |
| `TraceFilter` | `struct { from_block, to_block, from_address, to_address, after, count }` | trace filter |
| `tx_call_to_json`, `log_filter_to_json`, `trace_filter_to_json` | – | encoders |

### eth_* namespace (selected)

`eth_block_number`, `eth_chain_id`, `eth_get_balance`, `eth_get_transaction_count`,
`eth_send_raw_transaction`, `eth_call`, `eth_get_transaction_by_hash`,
`eth_get_code`, `eth_get_storage_at`, `eth_gas_price`,
`eth_max_priority_fee_per_gas`, `eth_fee_history`, `eth_blob_base_fee`,
`eth_protocol_version`, `eth_syncing`, `eth_accounts`, `eth_coinbase`,
`eth_mining`, `eth_hashrate`, `eth_get_block_by_hash`,
`eth_get_block_by_number`, `eth_get_block_receipts`,
`eth_get_block_transaction_count_by_hash/number`,
`eth_get_transaction_by_block_{hash,number}_and_index`,
`eth_get_transaction_receipt`, `eth_get_uncle*`, `eth_estimate_gas`,
`eth_create_access_list`, `eth_get_proof`, `eth_send_transaction`,
`eth_sign_transaction`, `eth_sign`, `eth_get_logs`, `eth_new_filter`,
`eth_new_block_filter`, `eth_new_pending_transaction_filter`,
`eth_uninstall_filter`, `eth_get_filter_changes`, `eth_get_filter_logs`.

### Subscriptions (WS)

| Symbol | Type | Description |
|---|---|---|
| `SubscriptionKind` | `enum { NewHeads, Logs(LogFilter), NewPendingTransactions, Syncing }` | – |
| `eth_subscribe` | `SubscriptionKind -> Request` | – |
| `eth_unsubscribe` | `Bytes -> Request` | – |
| `Notification` | `struct { subscription, result }` | – |
| `parse_notification` | `String -> Notification?` | – |

### debug_* / trace_* / net_* / web3_* / txpool_*

`debug_trace_transaction`, `debug_trace_call`, `debug_trace_block_by_hash`,
`debug_trace_block_by_number`, `debug_get_raw_transaction`,
`debug_get_raw_block`, `debug_get_raw_header`, `debug_get_raw_receipts`.

`trace_block`, `trace_call`, `trace_call_many`, `trace_filter`, `trace_get`,
`trace_raw_transaction`, `trace_replay_block_transactions`,
`trace_replay_transaction`, `trace_transaction`.

`net_listening`, `net_peer_count`, `net_version`, `web3_client_version`,
`web3_sha3`, `txpool_content`, `txpool_content_from`, `txpool_inspect`,
`txpool_status`.

## References

- JSON-RPC 2.0: <https://www.jsonrpc.org/specification>
- Ethereum JSON-RPC: <https://ethereum.org/en/developers/docs/apis/json-rpc/>
- geth pub/sub: <https://geth.ethereum.org/docs/interacting-with-geth/rpc/pubsub>
- Sibling packages: [`../ws`](../ws), [`../hex`](../hex)
