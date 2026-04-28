// Shared types for the JSON-RPC `eth_*` namespace.
//
// `TxCall` mirrors the call-object accepted by `eth_call`, `eth_estimateGas`,
// `eth_createAccessList`, `eth_sendTransaction` and `eth_signTransaction`.
// Every field is optional — `None` means "omit from the JSON object".
//
// `LogFilter` mirrors the filter object accepted by `eth_getLogs`,
// `eth_newFilter` and `eth_getFilterLogs`. Empty `address`/`topics` arrays
// are omitted (matching viem's behavior).
//
// Conversion helpers (`tx_call_to_json`, `log_filter_to_json`) emit a
// `Json::object(...)` whose insertion order is fixed so byte-exact tests are
// easy to write. `Map` in moonbitlang/core is a linked hash map, so the
// key order in the output JSON matches the order keys were inserted here.

///|
/// Call-object used by `eth_call`, `eth_estimateGas`, `eth_createAccessList`,
/// `eth_sendTransaction`, `eth_signTransaction`.
///
/// All fields are `Option`-typed; a `None` field is omitted from the
/// serialized JSON.
///
/// `to: None` denotes contract creation. `from`, `to` are address bytes
/// (typically 20). `data` is the call/init data. Quantity fields are
/// `BigInt` and emitted as JSON-RPC "Quantity" hex strings (no leading
/// zeros, `"0x0"` for zero).
///
/// `access_list` and `chain_id` are intentionally omitted from this v0
/// type; add later if needed.
pub(all) struct TxCall {
  from : Bytes?
  to : Bytes?
  gas : @bigint.BigInt?
  gas_price : @bigint.BigInt?
  max_priority_fee_per_gas : @bigint.BigInt?
  max_fee_per_gas : @bigint.BigInt?
  value : @bigint.BigInt?
  data : Bytes?
}

///|
/// Filter object for `eth_getLogs` / `eth_newFilter` / `eth_getFilterLogs`.
///
/// `from_block`, `to_block` are JSON-RPC block tags ("latest", "earliest",
/// "0xN" hex). When `Some`, they are emitted as `"fromBlock"`/`"toBlock"`.
///
/// `address` is an array of contract addresses (each entry must be 20-byte
/// `Bytes`). An empty array is omitted from the JSON. Non-empty arrays are
/// emitted as a JSON array — the spec also allows a single string, but we
/// always pick the array form for uniformity.
///
/// `topics` is a positional list. Each inner array is the OR-set of
/// possible 32-byte topic values for that position. Empty outer array is
/// omitted; non-empty positions emit nested arrays.
///
/// `block_hash` is mutually exclusive with `from_block`/`to_block` per the
/// spec, but this type does not enforce that. Callers are responsible.
pub(all) struct LogFilter {
  from_block : String?
  to_block : String?
  address : Array[Bytes]
  topics : Array[Array[Bytes]]
  block_hash : Bytes?
}

///|
/// Filter object passed to `trace_filter` (Parity-style trace API).
///
/// All fields are optional or "empty-allowed"; the `trace_filter_to_json`
/// encoder drops `None` fields and empty arrays so the resulting JSON
/// matches the canonical on-the-wire form geth/erigon accept.
///
/// - `from_block` / `to_block`: block tag or quantity hex (e.g. `"0x10"`,
///   `"latest"`). Both default to `"latest"` on the server when omitted.
/// - `from_address` / `to_address`: filter for traces whose top-level call
///   `from`/`to` is in the provided set.
/// - `after`: pagination offset (number of matches to skip).
/// - `count`: max number of traces to return.
pub(all) struct TraceFilter {
  from_block : String?
  to_block : String?
  from_address : Array[Bytes]
  to_address : Array[Bytes]
  after : Int?
  count : Int?
}

///|
/// Encode a BigInt as a JSON-RPC "Quantity" hex string: `"0x0"` for zero,
/// otherwise `"0x"` + lowercase hex with no leading zeros. Negative
/// values are not valid in JSON-RPC quantities; this helper does not
/// guard against them — callers must not pass negative numbers.
pub fn quantity_from_bigint(n : @bigint.BigInt) -> String {
  if n.is_zero() {
    "0x0"
  } else {
    "0x" + n.to_string(radix=16)
  }
}

///|
/// Encode an `Int` as a JSON-RPC "Quantity" hex string.
pub fn quantity_from_int(n : Int) -> String {
  quantity_from_bigint(@bigint.BigInt::from_int(n))
}

///|
/// Convert a `TxCall` to a `Json::object`, omitting `None` fields.
///
/// Field insertion order (when present): `from`, `to`, `gas`, `gasPrice`,
/// `maxPriorityFeePerGas`, `maxFeePerGas`, `value`, `data`.
pub fn tx_call_to_json(call : TxCall) -> Json {
  let m : Map[String, Json] = {}
  match call.from {
    Some(b) => m["from"] = Json::string(@hex.encode(b))
    None => ()
  }
  match call.to {
    Some(b) => m["to"] = Json::string(@hex.encode(b))
    None => ()
  }
  match call.gas {
    Some(n) => m["gas"] = Json::string(quantity_from_bigint(n))
    None => ()
  }
  match call.gas_price {
    Some(n) => m["gasPrice"] = Json::string(quantity_from_bigint(n))
    None => ()
  }
  match call.max_priority_fee_per_gas {
    Some(n) => m["maxPriorityFeePerGas"] = Json::string(quantity_from_bigint(n))
    None => ()
  }
  match call.max_fee_per_gas {
    Some(n) => m["maxFeePerGas"] = Json::string(quantity_from_bigint(n))
    None => ()
  }
  match call.value {
    Some(n) => m["value"] = Json::string(quantity_from_bigint(n))
    None => ()
  }
  match call.data {
    Some(b) => m["data"] = Json::string(@hex.encode(b))
    None => ()
  }
  Json::object(m)
}

///|
/// Convert a `LogFilter` to a `Json::object`. Empty `address`/`topics`
/// arrays and `None` block fields are omitted (viem-compatible).
///
/// Field insertion order: `fromBlock`, `toBlock`, `address`, `topics`,
/// `blockHash`.
pub fn log_filter_to_json(filter : LogFilter) -> Json {
  let m : Map[String, Json] = {}
  match filter.from_block {
    Some(s) => m["fromBlock"] = Json::string(s)
    None => ()
  }
  match filter.to_block {
    Some(s) => m["toBlock"] = Json::string(s)
    None => ()
  }
  if filter.address.length() > 0 {
    let arr : Array[Json] = []
    for b in filter.address {
      arr.push(Json::string(@hex.encode(b)))
    }
    m["address"] = Json::array(arr)
  }
  if filter.topics.length() > 0 {
    let outer : Array[Json] = []
    for inner in filter.topics {
      let inner_arr : Array[Json] = []
      for t in inner {
        inner_arr.push(Json::string(@hex.encode(t)))
      }
      outer.push(Json::array(inner_arr))
    }
    m["topics"] = Json::array(outer)
  }
  match filter.block_hash {
    Some(b) => m["blockHash"] = Json::string(@hex.encode(b))
    None => ()
  }
  Json::object(m)
}

///|
/// Convert a `TraceFilter` to a `Json::object`. `None` fields and empty
/// `from_address`/`to_address` arrays are omitted (geth/erigon-compatible).
///
/// Field insertion order: `fromBlock`, `toBlock`, `fromAddress`,
/// `toAddress`, `after`, `count`.
pub fn trace_filter_to_json(filter : TraceFilter) -> Json {
  let m : Map[String, Json] = {}
  match filter.from_block {
    Some(s) => m["fromBlock"] = Json::string(s)
    None => ()
  }
  match filter.to_block {
    Some(s) => m["toBlock"] = Json::string(s)
    None => ()
  }
  if filter.from_address.length() > 0 {
    let arr : Array[Json] = []
    for b in filter.from_address {
      arr.push(Json::string(@hex.encode(b)))
    }
    m["fromAddress"] = Json::array(arr)
  }
  if filter.to_address.length() > 0 {
    let arr : Array[Json] = []
    for b in filter.to_address {
      arr.push(Json::string(@hex.encode(b)))
    }
    m["toAddress"] = Json::array(arr)
  }
  match filter.after {
    Some(n) => m["after"] = Json::number(n.to_double())
    None => ()
  }
  match filter.count {
    Some(n) => m["count"] = Json::number(n.to_double())
    None => ()
  }
  Json::object(m)
}
