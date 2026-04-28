// `debug_` namespace constructors (geth/reth-style).
//
// These methods are not part of standard Ethereum JSON-RPC but are widely
// implemented by execution clients for tracing and raw-encoded read access:
//   - debug_traceTransaction / debug_traceCall / debug_traceBlockByHash /
//     debug_traceBlockByNumber: produce per-tx execution traces. The optional
//     `tracer` selects a built-in tracer ("callTracer", "structLog" default,
//     "prestateTracer", etc.) and is passed as `{"tracer": "<name>"}` in the
//     trailing config object slot.
//   - debug_getRawTransaction / debug_getRawBlock / debug_getRawHeader /
//     debug_getRawReceipts: return the consensus-encoded RLP for the
//     corresponding object — useful for verifying a node's encoding matches
//     what we produce locally.
//
// All returned `Request`s have id=0 as a placeholder; callers should override
// with their own counter before sending.

///|
/// `debug_traceTransaction(tx_hash, [{"tracer": "<name>"}]?)`.
/// When `tracer` is `None` the params array contains just the tx hash so the
/// node uses its default tracer (struct/opcode log). When `Some("callTracer")`
/// (or any other tracer name) the second param is `{"tracer": "<name>"}`.
pub fn debug_trace_transaction(
  tx_hash : Bytes,
  tracer : String?,
) -> Request {
  let params : Array[Json] = [Json::string(data_from_bytes(tx_hash))]
  match tracer {
    Some(name) => {
      let cfg : Map[String, Json] = { "tracer": Json::string(name) }
      params.push(Json::object(cfg))
    }
    None => ()
  }
  { id: 0, method: "debug_traceTransaction", params }
}

///|
/// `debug_traceCall(call, block_tag, [{"tracer": "<name>"}]?)`.
/// `block_tag` accepts the usual quantity tags ("latest", "pending", etc.) or
/// a hex block number. Tracer slot follows the same convention as
/// `debug_trace_transaction`.
pub fn debug_trace_call(
  call : TxCall,
  block_tag : String,
  tracer : String?,
) -> Request {
  let params : Array[Json] = [
    tx_call_to_json(call),
    Json::string(block_tag),
  ]
  match tracer {
    Some(name) => {
      let cfg : Map[String, Json] = { "tracer": Json::string(name) }
      params.push(Json::object(cfg))
    }
    None => ()
  }
  { id: 0, method: "debug_traceCall", params }
}

///|
/// `debug_traceBlockByHash(hash, [{"tracer": "<name>"}]?)`.
pub fn debug_trace_block_by_hash(
  hash : Bytes,
  tracer : String?,
) -> Request {
  let params : Array[Json] = [Json::string(data_from_bytes(hash))]
  match tracer {
    Some(name) => {
      let cfg : Map[String, Json] = { "tracer": Json::string(name) }
      params.push(Json::object(cfg))
    }
    None => ()
  }
  { id: 0, method: "debug_traceBlockByHash", params }
}

///|
/// `debug_traceBlockByNumber(block_tag, [{"tracer": "<name>"}]?)`.
pub fn debug_trace_block_by_number(
  block_tag : String,
  tracer : String?,
) -> Request {
  let params : Array[Json] = [Json::string(block_tag)]
  match tracer {
    Some(name) => {
      let cfg : Map[String, Json] = { "tracer": Json::string(name) }
      params.push(Json::object(cfg))
    }
    None => ()
  }
  { id: 0, method: "debug_traceBlockByNumber", params }
}

///|
/// `debug_getRawTransaction(tx_hash)` — returns the RLP-encoded signed tx.
pub fn debug_get_raw_transaction(tx_hash : Bytes) -> Request {
  {
    id: 0,
    method: "debug_getRawTransaction",
    params: [Json::string(data_from_bytes(tx_hash))],
  }
}

///|
/// `debug_getRawBlock(block_tag)` — returns the RLP-encoded block.
pub fn debug_get_raw_block(block_tag : String) -> Request {
  { id: 0, method: "debug_getRawBlock", params: [Json::string(block_tag)] }
}

///|
/// `debug_getRawHeader(block_tag)` — returns the RLP-encoded block header.
pub fn debug_get_raw_header(block_tag : String) -> Request {
  { id: 0, method: "debug_getRawHeader", params: [Json::string(block_tag)] }
}

///|
/// `debug_getRawReceipts(block_tag)` — returns the RLP-encoded receipts list.
pub fn debug_get_raw_receipts(block_tag : String) -> Request {
  {
    id: 0,
    method: "debug_getRawReceipts",
    params: [Json::string(block_tag)],
  }
}
