// Convenience constructors for the rest of the `eth_*` JSON-RPC namespace
// (the seven most common ones live in `rpc.mbt`).
//
// Every constructor returns a `Request` with `id = 0` as a placeholder;
// callers should mutate `id` to whatever counter their transport uses
// before passing the value to `encode_request`.
//
// Naming: snake_case in MoonBit, camelCase in the wire `method` field.
// All address/hash arguments take `Bytes` (no validation of length here);
// block tags and pre-formatted hex strings take `String`.

// ---------- state queries ----------

///|
/// `eth_getCode(address, block_tag)`.
pub fn eth_get_code(address : Bytes, block_tag : String) -> Request {
  {
    id: 0,
    method: "eth_getCode",
    params: [Json::string(@hex.encode(address)), Json::string(block_tag)],
  }
}

///|
/// `eth_getStorageAt(address, key_hex, block_tag)`. `key_hex` is the
/// pre-formatted storage slot hex string ("0x..." 32 bytes typically).
/// Pass through verbatim — callers are responsible for the format.
pub fn eth_get_storage_at(
  address : Bytes,
  key_hex : String,
  block_tag : String,
) -> Request {
  {
    id: 0,
    method: "eth_getStorageAt",
    params: [
      Json::string(@hex.encode(address)),
      Json::string(key_hex),
      Json::string(block_tag),
    ],
  }
}

///|
/// `eth_gasPrice()`.
pub fn eth_gas_price() -> Request {
  { id: 0, method: "eth_gasPrice", params: [] }
}

///|
/// `eth_maxPriorityFeePerGas()`.
pub fn eth_max_priority_fee_per_gas() -> Request {
  { id: 0, method: "eth_maxPriorityFeePerGas", params: [] }
}

///|
/// `eth_feeHistory(block_count, newest_block, reward_percentiles)`.
/// `block_count` is encoded as a Quantity hex string; percentiles are
/// emitted as JSON numbers (e.g. `25.0` -> `25`, `25.5` -> `25.5`).
pub fn eth_fee_history(
  block_count : Int,
  newest_block : String,
  reward_percentiles : Array[Double],
) -> Request {
  let pct : Array[Json] = []
  for p in reward_percentiles {
    pct.push(Json::number(p))
  }
  {
    id: 0,
    method: "eth_feeHistory",
    params: [
      Json::string(quantity_from_int(block_count)),
      Json::string(newest_block),
      Json::array(pct),
    ],
  }
}

///|
/// `eth_blobBaseFee()` (EIP-7516).
pub fn eth_blob_base_fee() -> Request {
  { id: 0, method: "eth_blobBaseFee", params: [] }
}

///|
/// `eth_protocolVersion()`.
pub fn eth_protocol_version() -> Request {
  { id: 0, method: "eth_protocolVersion", params: [] }
}

///|
/// `eth_syncing()`.
pub fn eth_syncing() -> Request {
  { id: 0, method: "eth_syncing", params: [] }
}

///|
/// `eth_accounts()`.
pub fn eth_accounts() -> Request {
  { id: 0, method: "eth_accounts", params: [] }
}

///|
/// `eth_coinbase()`.
pub fn eth_coinbase() -> Request {
  { id: 0, method: "eth_coinbase", params: [] }
}

///|
/// `eth_mining()`.
pub fn eth_mining() -> Request {
  { id: 0, method: "eth_mining", params: [] }
}

///|
/// `eth_hashrate()`.
pub fn eth_hashrate() -> Request {
  { id: 0, method: "eth_hashrate", params: [] }
}

// ---------- block queries ----------

///|
/// `eth_getBlockByHash(hash, full_tx)`. `full_tx=true` returns full
/// transaction objects, otherwise just hashes.
pub fn eth_get_block_by_hash(hash : Bytes, full_tx : Bool) -> Request {
  {
    id: 0,
    method: "eth_getBlockByHash",
    params: [Json::string(@hex.encode(hash)), Json::boolean(full_tx)],
  }
}

///|
/// `eth_getBlockByNumber(block_tag, full_tx)`.
pub fn eth_get_block_by_number(block_tag : String, full_tx : Bool) -> Request {
  {
    id: 0,
    method: "eth_getBlockByNumber",
    params: [Json::string(block_tag), Json::boolean(full_tx)],
  }
}

///|
/// `eth_getBlockReceipts(block_tag_or_hash)`. The argument is passed
/// through verbatim — callers may pass a block tag ("latest"), a number
/// hex ("0x10"), or a 32-byte block hash hex.
pub fn eth_get_block_receipts(block_tag_or_hash : String) -> Request {
  {
    id: 0,
    method: "eth_getBlockReceipts",
    params: [Json::string(block_tag_or_hash)],
  }
}

///|
/// `eth_getBlockTransactionCountByHash(hash)`.
pub fn eth_get_block_transaction_count_by_hash(hash : Bytes) -> Request {
  {
    id: 0,
    method: "eth_getBlockTransactionCountByHash",
    params: [Json::string(@hex.encode(hash))],
  }
}

///|
/// `eth_getBlockTransactionCountByNumber(block_tag)`.
pub fn eth_get_block_transaction_count_by_number(
  block_tag : String,
) -> Request {
  {
    id: 0,
    method: "eth_getBlockTransactionCountByNumber",
    params: [Json::string(block_tag)],
  }
}

// ---------- transaction queries ----------

///|
/// `eth_getTransactionByBlockHashAndIndex(hash, index)`.
pub fn eth_get_transaction_by_block_hash_and_index(
  hash : Bytes,
  index : Int,
) -> Request {
  {
    id: 0,
    method: "eth_getTransactionByBlockHashAndIndex",
    params: [
      Json::string(@hex.encode(hash)),
      Json::string(quantity_from_int(index)),
    ],
  }
}

///|
/// `eth_getTransactionByBlockNumberAndIndex(block_tag, index)`.
pub fn eth_get_transaction_by_block_number_and_index(
  block_tag : String,
  index : Int,
) -> Request {
  {
    id: 0,
    method: "eth_getTransactionByBlockNumberAndIndex",
    params: [Json::string(block_tag), Json::string(quantity_from_int(index))],
  }
}

///|
/// `eth_getTransactionReceipt(hash)`.
pub fn eth_get_transaction_receipt(hash : Bytes) -> Request {
  {
    id: 0,
    method: "eth_getTransactionReceipt",
    params: [Json::string(@hex.encode(hash))],
  }
}

// ---------- uncle queries (post-merge no-ops) ----------

///|
/// `eth_getUncleByBlockHashAndIndex(hash, index)`. Always returns null
/// post-merge but the method is still in the spec.
pub fn eth_get_uncle_by_block_hash_and_index(
  hash : Bytes,
  index : Int,
) -> Request {
  {
    id: 0,
    method: "eth_getUncleByBlockHashAndIndex",
    params: [
      Json::string(@hex.encode(hash)),
      Json::string(quantity_from_int(index)),
    ],
  }
}

///|
/// `eth_getUncleByBlockNumberAndIndex(block_tag, index)`.
pub fn eth_get_uncle_by_block_number_and_index(
  block_tag : String,
  index : Int,
) -> Request {
  {
    id: 0,
    method: "eth_getUncleByBlockNumberAndIndex",
    params: [Json::string(block_tag), Json::string(quantity_from_int(index))],
  }
}

///|
/// `eth_getUncleCountByBlockHash(hash)`.
pub fn eth_get_uncle_count_by_block_hash(hash : Bytes) -> Request {
  {
    id: 0,
    method: "eth_getUncleCountByBlockHash",
    params: [Json::string(@hex.encode(hash))],
  }
}

///|
/// `eth_getUncleCountByBlockNumber(block_tag)`.
pub fn eth_get_uncle_count_by_block_number(block_tag : String) -> Request {
  {
    id: 0,
    method: "eth_getUncleCountByBlockNumber",
    params: [Json::string(block_tag)],
  }
}

// ---------- call / sim ----------

///|
/// `eth_estimateGas(call, block_tag)`.
pub fn eth_estimate_gas(call : TxCall, block_tag : String) -> Request {
  {
    id: 0,
    method: "eth_estimateGas",
    params: [tx_call_to_json(call), Json::string(block_tag)],
  }
}

///|
/// `eth_createAccessList(call, block_tag)`.
pub fn eth_create_access_list(call : TxCall, block_tag : String) -> Request {
  {
    id: 0,
    method: "eth_createAccessList",
    params: [tx_call_to_json(call), Json::string(block_tag)],
  }
}

///|
/// `eth_getProof(address, storage_keys, block_tag)`.
pub fn eth_get_proof(
  address : Bytes,
  storage_keys : Array[Bytes],
  block_tag : String,
) -> Request {
  let keys : Array[Json] = []
  for k in storage_keys {
    keys.push(Json::string(@hex.encode(k)))
  }
  {
    id: 0,
    method: "eth_getProof",
    params: [
      Json::string(@hex.encode(address)),
      Json::array(keys),
      Json::string(block_tag),
    ],
  }
}

// ---------- tx submission ----------

///|
/// `eth_sendTransaction(call)`.
pub fn eth_send_transaction(call : TxCall) -> Request {
  { id: 0, method: "eth_sendTransaction", params: [tx_call_to_json(call)] }
}

///|
/// `eth_signTransaction(call)`.
pub fn eth_sign_transaction(call : TxCall) -> Request {
  { id: 0, method: "eth_signTransaction", params: [tx_call_to_json(call)] }
}

///|
/// `eth_sign(address, data)`.
pub fn eth_sign(address : Bytes, data : Bytes) -> Request {
  {
    id: 0,
    method: "eth_sign",
    params: [
      Json::string(@hex.encode(address)),
      Json::string(@hex.encode(data)),
    ],
  }
}

// ---------- logs / filters ----------

///|
/// `eth_getLogs(filter)`.
pub fn eth_get_logs(filter : LogFilter) -> Request {
  { id: 0, method: "eth_getLogs", params: [log_filter_to_json(filter)] }
}

///|
/// `eth_newFilter(filter)`.
pub fn eth_new_filter(filter : LogFilter) -> Request {
  { id: 0, method: "eth_newFilter", params: [log_filter_to_json(filter)] }
}

///|
/// `eth_newBlockFilter()`.
pub fn eth_new_block_filter() -> Request {
  { id: 0, method: "eth_newBlockFilter", params: [] }
}

///|
/// `eth_newPendingTransactionFilter()`.
pub fn eth_new_pending_transaction_filter() -> Request {
  { id: 0, method: "eth_newPendingTransactionFilter", params: [] }
}

///|
/// `eth_uninstallFilter(filter_id)`.
pub fn eth_uninstall_filter(filter_id : @bigint.BigInt) -> Request {
  {
    id: 0,
    method: "eth_uninstallFilter",
    params: [Json::string(quantity_from_bigint(filter_id))],
  }
}

///|
/// `eth_getFilterChanges(filter_id)`.
pub fn eth_get_filter_changes(filter_id : @bigint.BigInt) -> Request {
  {
    id: 0,
    method: "eth_getFilterChanges",
    params: [Json::string(quantity_from_bigint(filter_id))],
  }
}

///|
/// `eth_getFilterLogs(filter_id)`.
pub fn eth_get_filter_logs(filter_id : @bigint.BigInt) -> Request {
  {
    id: 0,
    method: "eth_getFilterLogs",
    params: [Json::string(quantity_from_bigint(filter_id))],
  }
}
