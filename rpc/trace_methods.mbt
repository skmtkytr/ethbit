// `trace_` namespace constructors (Parity-style; reth + erigon support).
//
// Unlike `debug_`, these are the OpenEthereum/Parity tracing API — the trace
// types are passed as a string array (any subset of "trace", "vmTrace",
// "stateDiff") and results are returned in a uniform shape. Reth implements
// a compatible subset; erigon implements the full set.
//
// `trace_filter` takes a single object argument; the struct fields with `None`
// and empty arrays are omitted from the JSON to match the on-the-wire shape
// that geth/erigon accept (and to keep the request body small).

///|
/// `trace_block(block_tag)` — return all traces for a block.
pub fn trace_block(block_tag : String) -> Request {
  { id: 0, method: "trace_block", params: [Json::string(block_tag)] }
}

///|
/// `trace_call(call, trace_types, block_tag)` — re-execute a call with the
/// chosen trace types, against the chain at `block_tag`.
pub fn trace_call(
  call : TxCall,
  trace_types : Array[String],
  block_tag : String,
) -> Request {
  {
    id: 0,
    method: "trace_call",
    params: [
      tx_call_to_json(call),
      Json::array(trace_types.map(Json::string)),
      Json::string(block_tag),
    ],
  }
}

///|
/// `trace_callMany(calls, block_tag)` — multi-call variant. Each entry pairs
/// a call with its desired trace types; the server replays all of them in the
/// declared order against `block_tag`'s state.
pub fn trace_call_many(
  calls : Array[(TxCall, Array[String])],
  block_tag : String,
) -> Request {
  let outer : Array[Json] = []
  for pair in calls {
    let (call, types) = pair
    outer.push(
      Json::array([tx_call_to_json(call), Json::array(types.map(Json::string))]),
    )
  }
  {
    id: 0,
    method: "trace_callMany",
    params: [Json::array(outer), Json::string(block_tag)],
  }
}

///|
/// `trace_filter(filter)` — search traces matching the given filter.
/// Fields with `None` and empty arrays are omitted from the on-the-wire JSON
/// so the body matches geth/erigon's canonical form (delegates to
/// `trace_filter_to_json` in `types.mbt`).
pub fn trace_filter(filter : TraceFilter) -> Request {
  { id: 0, method: "trace_filter", params: [trace_filter_to_json(filter)] }
}

///|
/// `trace_get(tx_hash, indices)` — return the trace at the given path inside
/// the transaction's call tree. `indices` is an array of child positions
/// (e.g. `[0,1]` = first sub-call's second sub-call).
pub fn trace_get(tx_hash : Bytes, indices : Array[Int]) -> Request {
  let idx_json : Array[Json] = indices.map(i => Json::number(i.to_double()))
  {
    id: 0,
    method: "trace_get",
    params: [Json::string(data_from_bytes(tx_hash)), Json::array(idx_json)],
  }
}

///|
/// `trace_rawTransaction(raw, trace_types)` — trace a not-yet-broadcast raw
/// signed tx. Useful for previewing the effect of a tx the client will send.
pub fn trace_raw_transaction(
  raw : Bytes,
  trace_types : Array[String],
) -> Request {
  {
    id: 0,
    method: "trace_rawTransaction",
    params: [
      Json::string(data_from_bytes(raw)),
      Json::array(trace_types.map(Json::string)),
    ],
  }
}

///|
/// `trace_replayBlockTransactions(block_tag, trace_types)` — re-execute every
/// tx in the block under the chosen tracers.
pub fn trace_replay_block_transactions(
  block_tag : String,
  trace_types : Array[String],
) -> Request {
  {
    id: 0,
    method: "trace_replayBlockTransactions",
    params: [
      Json::string(block_tag),
      Json::array(trace_types.map(Json::string)),
    ],
  }
}

///|
/// `trace_replayTransaction(tx_hash, trace_types)` — re-execute a single tx.
pub fn trace_replay_transaction(
  tx_hash : Bytes,
  trace_types : Array[String],
) -> Request {
  {
    id: 0,
    method: "trace_replayTransaction",
    params: [
      Json::string(data_from_bytes(tx_hash)),
      Json::array(trace_types.map(Json::string)),
    ],
  }
}

///|
/// `trace_transaction(tx_hash)` — return the call tree for a tx.
pub fn trace_transaction(tx_hash : Bytes) -> Request {
  {
    id: 0,
    method: "trace_transaction",
    params: [Json::string(data_from_bytes(tx_hash))],
  }
}
