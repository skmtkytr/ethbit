// Typed response decoders for the standard Ethereum JSON-RPC method results.
//
// Each result type used by `eth_getLogs`, `eth_getTransactionByHash`,
// `eth_getTransactionReceipt`, `eth_getBlockBy*`, `eth_feeHistory`,
// `eth_syncing`, and `eth_createAccessList` has a corresponding struct here
// plus a `parse_<x>(json) -> <X>?` parser. Every parser is total — it
// returns `None` on any of:
//   - missing required field
//   - wrong JSON type for a field
//   - malformed hex (handled by `parse_hex_quantity` / `parse_hex_bytes`)
//   - odd-length Data bodies (rejected by `@hex.decode` inside
//     `parse_hex_bytes`)
//
// Field naming convention: MoonBit fields are snake_case; JSON keys are
// camelCase. Mapping is per-field — the parser does the translation. The
// JSON key `"from"` maps to the struct field `from_` because `from` is a
// MoonBit reserved word; same for `type` -> `type_`.
//
// Hex helpers come from `rpc.mbt`. Do NOT reimplement.

// ---------- structs ----------

///|
/// `eth_getFilterLogs` / `eth_getLogs` log entry. Pending logs (returned
/// from a block-by-hash query for a not-yet-mined log) lack `logIndex`,
/// `transactionIndex`, `transactionHash`, `blockHash`, `blockNumber`; those
/// fields are typed as Option.
pub(all) struct Log {
  removed : Bool
  log_index : @bigint.BigInt? // pending logs lack this
  transaction_index : @bigint.BigInt?
  transaction_hash : Bytes?
  block_hash : Bytes?
  block_number : @bigint.BigInt?
  address : Bytes
  data : Bytes
  topics : Array[Bytes]
}

///|
/// `eth_getTransactionByHash` / `eth_getTransactionByBlockHashAndIndex`
/// result. `from_` corresponds to the JSON `"from"` key (MoonBit
/// reserved word workaround). `type_` likewise for `"type"`.
///
/// Pending transactions lack `blockHash`, `blockNumber`, `transactionIndex`;
/// post-Berlin (type-1+) transactions add `accessList`; type-2+ add
/// `maxFeePerGas`/`maxPriorityFeePerGas`; type-3 adds
/// `maxFeePerBlobGas`/`blobVersionedHashes`.
pub(all) struct TransactionInfo {
  hash : Bytes
  block_hash : Bytes? // pending tx lacks this
  block_number : @bigint.BigInt? // pending tx lacks this
  transaction_index : @bigint.BigInt? // pending tx lacks this
  from_ : Bytes // JSON "from" — MoonBit reserved word
  to : Bytes? // null on contract creation
  value : @bigint.BigInt
  gas : @bigint.BigInt
  gas_price : @bigint.BigInt? // legacy / type-1
  max_fee_per_gas : @bigint.BigInt? // type-2 / type-3
  max_priority_fee_per_gas : @bigint.BigInt? // type-2 / type-3
  max_fee_per_blob_gas : @bigint.BigInt? // type-3
  nonce : @bigint.BigInt
  input : Bytes
  v : @bigint.BigInt
  r : Bytes
  s : Bytes
  type_ : Int // JSON "type" — MoonBit reserved word; 0/1/2/3
  chain_id : @bigint.BigInt?
  access_list : Array[@tx.AccessListEntry]? // type-1 and up
  blob_versioned_hashes : Array[Bytes]? // type-3 only
}

///|
/// `eth_getTransactionReceipt` result. `from_` / `type_` are the
/// reserved-word workarounds.
///
/// Post-Byzantium has `status`; pre-Byzantium has `root`. Type-3 adds
/// `blobGasUsed` / `blobGasPrice`.
pub(all) struct TransactionReceipt {
  transaction_hash : Bytes
  transaction_index : @bigint.BigInt
  block_hash : Bytes
  block_number : @bigint.BigInt
  from_ : Bytes // JSON "from"
  to : Bytes? // null on contract creation
  cumulative_gas_used : @bigint.BigInt
  gas_used : @bigint.BigInt
  contract_address : Bytes? // null unless contract creation
  logs : Array[Log]
  logs_bloom : Bytes // 256-byte Data
  type_ : Int // JSON "type"
  status : @bigint.BigInt? // post-Byzantium: 0 or 1
  root : Bytes? // pre-Byzantium intermediate state root
  effective_gas_price : @bigint.BigInt
  blob_gas_used : @bigint.BigInt? // type-3 only
  blob_gas_price : @bigint.BigInt? // type-3 only
}

///|
/// EIP-4895 withdrawal entry inside `eth_getBlockBy*`.
pub(all) struct Withdrawal {
  index : @bigint.BigInt
  validator_index : @bigint.BigInt
  address : Bytes
  amount : @bigint.BigInt
}

///|
/// `eth_getBlockBy*` `transactions` field is one of two shapes depending
/// on the second argument: an array of 32-byte hashes (when
/// `full_tx=false`) or an array of full TransactionInfo objects.
pub(all) enum BlockTransactions {
  Hashes(Array[Bytes])
  Full(Array[TransactionInfo])
}

///|
pub impl Eq for BlockTransactions with equal(a, b) {
  match (a, b) {
    (Hashes(x), Hashes(y)) => x == y
    (Full(x), Full(y)) => {
      if x.length() != y.length() {
        return false
      }
      // TransactionInfo doesn't derive Eq; rely on length only here. Tests
      // that need deeper inspection should pattern-match the variant.
      true
    }
    _ => false
  }
}

///|
/// `eth_getBlockBy*` result. `hash` and `number` are null on the pending
/// block. Post-merge `difficulty` is always 0 but still present on most
/// clients; we accept absence too.
pub(all) struct Block {
  hash : Bytes? // null on pending
  parent_hash : Bytes
  sha3_uncles : Bytes
  miner : Bytes
  state_root : Bytes
  transactions_root : Bytes
  receipts_root : Bytes
  logs_bloom : Bytes
  difficulty : @bigint.BigInt? // some clients omit post-merge
  number : @bigint.BigInt? // null on pending
  gas_limit : @bigint.BigInt
  gas_used : @bigint.BigInt
  timestamp : @bigint.BigInt
  extra_data : Bytes
  mix_hash : Bytes
  nonce : Bytes // 8-byte Data
  base_fee_per_gas : @bigint.BigInt? // EIP-1559+
  withdrawals_root : Bytes? // Shanghai+
  withdrawals : Array[Withdrawal]? // Shanghai+
  blob_gas_used : @bigint.BigInt? // Cancun+
  excess_blob_gas : @bigint.BigInt? // Cancun+
  parent_beacon_block_root : Bytes? // Cancun+
  size : @bigint.BigInt
  total_difficulty : @bigint.BigInt? // some clients omit
  transactions : BlockTransactions
  uncles : Array[Bytes]
}

///|
/// `eth_feeHistory` result.
pub(all) struct FeeHistoryResult {
  oldest_block : @bigint.BigInt
  base_fee_per_gas : Array[@bigint.BigInt]
  gas_used_ratio : Array[Double]
  reward : Array[Array[@bigint.BigInt]] // empty Array if no percentiles requested
  base_fee_per_blob_gas : Array[@bigint.BigInt]? // post-Cancun
  blob_gas_used_ratio : Array[Double]? // post-Cancun
}

///|
/// `eth_syncing` returns `false` when not syncing, otherwise an object
/// with the three block fields below.
pub(all) enum SyncingStatus {
  NotSyncing
  Syncing(SyncingDetail)
}

///|
pub(all) struct SyncingDetail {
  starting_block : @bigint.BigInt
  current_block : @bigint.BigInt
  highest_block : @bigint.BigInt
}

///|
/// `eth_createAccessList` result. Some clients tack on an `error` string
/// (e.g. when the call would revert); we expose it as an Option.
pub(all) struct AccessListResult {
  access_list : Array[@tx.AccessListEntry]
  gas_used : @bigint.BigInt
  error : String?
}

// ---------- helpers ----------

///|
/// Look up a key in a JSON object map. Returns the value or `None` if
/// absent.
fn read_field(m : Map[String, Json], key : String) -> Json? {
  m.get(key)
}

///|
/// Parse an optional Quantity field.
/// Return:
///   - `Some(Some(v))` — present, non-null, parsed OK
///   - `Some(None)` — absent or explicitly null (acceptable for optionals)
///   - `None` — present, non-null, but malformed (caller should fail)
fn opt_quantity(v : Json?) -> @bigint.BigInt?? {
  match v {
    None => Some(None)
    Some(Null) => Some(None)
    Some(j) =>
      match parse_hex_quantity(j) {
        Some(n) => Some(Some(n))
        None => None
      }
  }
}

///|
/// Parse an optional Data (hex bytes) field. Same three-state semantics
/// as `opt_quantity`.
fn opt_bytes(v : Json?) -> Bytes?? {
  match v {
    None => Some(None)
    Some(Null) => Some(None)
    Some(j) =>
      match parse_hex_bytes(j) {
        Some(b) => Some(Some(b))
        None => None
      }
  }
}

///|
/// Parse a single AccessListEntry JSON object:
///   { "address": "0x...", "storageKeys": ["0x...", ...] }
fn parse_access_list_entry(json : Json) -> @tx.AccessListEntry? {
  let m = match json {
    Object(m) => m
    _ => return None
  }
  let address = match read_field(m, "address") {
    Some(j) =>
      match parse_hex_bytes(j) {
        Some(b) => b
        None => return None
      }
    None => return None
  }
  let keys_json = match read_field(m, "storageKeys") {
    Some(Array(arr)) => arr
    _ => return None
  }
  let storage_keys : Array[Bytes] = []
  for k in keys_json {
    match parse_hex_bytes(k) {
      Some(b) => storage_keys.push(b)
      None => return None
    }
  }
  Some({ address, storage_keys })
}

///|
/// Parse a JSON array of AccessListEntry objects.
pub fn parse_access_list(json : Json) -> Array[@tx.AccessListEntry]? {
  let arr = match json {
    Array(a) => a
    _ => return None
  }
  let out : Array[@tx.AccessListEntry] = []
  for j in arr {
    match parse_access_list_entry(j) {
      Some(e) => out.push(e)
      None => return None
    }
  }
  Some(out)
}

// ---------- parsers ----------

///|
/// Parse a single `Log` object.
pub fn parse_log(json : Json) -> Log? {
  let m = match json {
    Object(m) => m
    _ => return None
  }
  let removed = match read_field(m, "removed") {
    Some(True) => true
    Some(False) => false
    _ => return None
  }
  let log_index = match opt_quantity(read_field(m, "logIndex")) {
    Some(v) => v
    None => return None
  }
  let transaction_index = match opt_quantity(read_field(m, "transactionIndex")) {
    Some(v) => v
    None => return None
  }
  let transaction_hash = match opt_bytes(read_field(m, "transactionHash")) {
    Some(v) => v
    None => return None
  }
  let block_hash = match opt_bytes(read_field(m, "blockHash")) {
    Some(v) => v
    None => return None
  }
  let block_number = match opt_quantity(read_field(m, "blockNumber")) {
    Some(v) => v
    None => return None
  }
  let address = match read_field(m, "address") {
    Some(j) =>
      match parse_hex_bytes(j) {
        Some(b) => b
        None => return None
      }
    None => return None
  }
  let data = match read_field(m, "data") {
    Some(j) =>
      match parse_hex_bytes(j) {
        Some(b) => b
        None => return None
      }
    None => return None
  }
  let topics_json = match read_field(m, "topics") {
    Some(Array(arr)) => arr
    _ => return None
  }
  let topics : Array[Bytes] = []
  for t in topics_json {
    match parse_hex_bytes(t) {
      Some(b) => topics.push(b)
      None => return None
    }
  }
  Some({
    removed,
    log_index,
    transaction_index,
    transaction_hash,
    block_hash,
    block_number,
    address,
    data,
    topics,
  })
}

///|
/// Convenience: parse a JSON array of Logs.
pub fn parse_logs(json : Json) -> Array[Log]? {
  let arr = match json {
    Array(a) => a
    _ => return None
  }
  let out : Array[Log] = []
  for j in arr {
    match parse_log(j) {
      Some(l) => out.push(l)
      None => return None
    }
  }
  Some(out)
}

///|
/// Parse a `TransactionInfo` object. Maps JSON `"from"` -> `from_` and
/// `"type"` -> `type_`.
pub fn parse_transaction_info(json : Json) -> TransactionInfo? {
  let m = match json {
    Object(m) => m
    _ => return None
  }
  let hash = match read_field(m, "hash") {
    Some(j) =>
      match parse_hex_bytes(j) {
        Some(b) => b
        None => return None
      }
    None => return None
  }
  let block_hash = match opt_bytes(read_field(m, "blockHash")) {
    Some(v) => v
    None => return None
  }
  let block_number = match opt_quantity(read_field(m, "blockNumber")) {
    Some(v) => v
    None => return None
  }
  let transaction_index = match opt_quantity(read_field(m, "transactionIndex")) {
    Some(v) => v
    None => return None
  }
  let from_ = match read_field(m, "from") {
    Some(j) =>
      match parse_hex_bytes(j) {
        Some(b) => b
        None => return None
      }
    None => return None
  }
  let to = match opt_bytes(read_field(m, "to")) {
    Some(v) => v
    None => return None
  }
  let value = match read_field(m, "value") {
    Some(j) =>
      match parse_hex_quantity(j) {
        Some(n) => n
        None => return None
      }
    None => return None
  }
  let gas = match read_field(m, "gas") {
    Some(j) =>
      match parse_hex_quantity(j) {
        Some(n) => n
        None => return None
      }
    None => return None
  }
  let gas_price = match opt_quantity(read_field(m, "gasPrice")) {
    Some(v) => v
    None => return None
  }
  let max_fee_per_gas = match opt_quantity(read_field(m, "maxFeePerGas")) {
    Some(v) => v
    None => return None
  }
  let max_priority_fee_per_gas = match opt_quantity(
      read_field(m, "maxPriorityFeePerGas"),
    ) {
    Some(v) => v
    None => return None
  }
  let max_fee_per_blob_gas = match opt_quantity(
      read_field(m, "maxFeePerBlobGas"),
    ) {
    Some(v) => v
    None => return None
  }
  let nonce = match read_field(m, "nonce") {
    Some(j) =>
      match parse_hex_quantity(j) {
        Some(n) => n
        None => return None
      }
    None => return None
  }
  let input = match read_field(m, "input") {
    Some(j) =>
      match parse_hex_bytes(j) {
        Some(b) => b
        None => return None
      }
    None => return None
  }
  let v_field = match read_field(m, "v") {
    Some(j) =>
      match parse_hex_quantity(j) {
        Some(n) => n
        None => return None
      }
    None => return None
  }
  let r = match read_field(m, "r") {
    Some(j) =>
      match parse_hex_bytes(j) {
        Some(b) => b
        None => return None
      }
    None => return None
  }
  let s = match read_field(m, "s") {
    Some(j) =>
      match parse_hex_bytes(j) {
        Some(b) => b
        None => return None
      }
    None => return None
  }
  // type field: present in modern responses (typed-tx envelope), absent
  // on some older legacy-only servers. Default to 0 if absent.
  let type_ = match read_field(m, "type") {
    Some(j) =>
      match parse_hex_quantity(j) {
        Some(n) => n.to_int()
        None => return None
      }
    None => 0
  }
  let chain_id = match opt_quantity(read_field(m, "chainId")) {
    Some(v) => v
    None => return None
  }
  // accessList: optional (legacy doesn't have it). Treat null and absent
  // as None, present-but-malformed as failure.
  let access_list = match read_field(m, "accessList") {
    None => None
    Some(Null) => None
    Some(j) =>
      match parse_access_list(j) {
        Some(a) => Some(a)
        None => return None
      }
  }
  // blobVersionedHashes: type-3 only.
  let blob_versioned_hashes = match read_field(m, "blobVersionedHashes") {
    None => None
    Some(Null) => None
    Some(Array(arr)) => {
      let out : Array[Bytes] = []
      for h in arr {
        match parse_hex_bytes(h) {
          Some(b) => out.push(b)
          None => return None
        }
      }
      Some(out)
    }
    Some(_) => return None
  }
  Some({
    hash,
    block_hash,
    block_number,
    transaction_index,
    from_,
    to,
    value,
    gas,
    gas_price,
    max_fee_per_gas,
    max_priority_fee_per_gas,
    max_fee_per_blob_gas,
    nonce,
    input,
    v: v_field,
    r,
    s,
    type_,
    chain_id,
    access_list,
    blob_versioned_hashes,
  })
}

///|
/// Parse a `TransactionReceipt` object.
pub fn parse_transaction_receipt(json : Json) -> TransactionReceipt? {
  let m = match json {
    Object(m) => m
    _ => return None
  }
  let transaction_hash = match read_field(m, "transactionHash") {
    Some(j) =>
      match parse_hex_bytes(j) {
        Some(b) => b
        None => return None
      }
    None => return None
  }
  let transaction_index = match read_field(m, "transactionIndex") {
    Some(j) =>
      match parse_hex_quantity(j) {
        Some(n) => n
        None => return None
      }
    None => return None
  }
  let block_hash = match read_field(m, "blockHash") {
    Some(j) =>
      match parse_hex_bytes(j) {
        Some(b) => b
        None => return None
      }
    None => return None
  }
  let block_number = match read_field(m, "blockNumber") {
    Some(j) =>
      match parse_hex_quantity(j) {
        Some(n) => n
        None => return None
      }
    None => return None
  }
  let from_ = match read_field(m, "from") {
    Some(j) =>
      match parse_hex_bytes(j) {
        Some(b) => b
        None => return None
      }
    None => return None
  }
  let to = match opt_bytes(read_field(m, "to")) {
    Some(v) => v
    None => return None
  }
  let cumulative_gas_used = match read_field(m, "cumulativeGasUsed") {
    Some(j) =>
      match parse_hex_quantity(j) {
        Some(n) => n
        None => return None
      }
    None => return None
  }
  let gas_used = match read_field(m, "gasUsed") {
    Some(j) =>
      match parse_hex_quantity(j) {
        Some(n) => n
        None => return None
      }
    None => return None
  }
  let contract_address = match opt_bytes(read_field(m, "contractAddress")) {
    Some(v) => v
    None => return None
  }
  let logs = match read_field(m, "logs") {
    Some(j) =>
      match parse_logs(j) {
        Some(ls) => ls
        None => return None
      }
    None => return None
  }
  let logs_bloom = match read_field(m, "logsBloom") {
    Some(j) =>
      match parse_hex_bytes(j) {
        Some(b) => b
        None => return None
      }
    None => return None
  }
  // type defaults to 0 for legacy receipts (some clients omit it).
  let type_ = match read_field(m, "type") {
    None => 0
    Some(j) =>
      match parse_hex_quantity(j) {
        Some(n) => n.to_int()
        None => return None
      }
  }
  let status = match opt_quantity(read_field(m, "status")) {
    Some(v) => v
    None => return None
  }
  let root = match opt_bytes(read_field(m, "root")) {
    Some(v) => v
    None => return None
  }
  let effective_gas_price = match read_field(m, "effectiveGasPrice") {
    Some(j) =>
      match parse_hex_quantity(j) {
        Some(n) => n
        None => return None
      }
    None => return None
  }
  let blob_gas_used = match opt_quantity(read_field(m, "blobGasUsed")) {
    Some(v) => v
    None => return None
  }
  let blob_gas_price = match opt_quantity(read_field(m, "blobGasPrice")) {
    Some(v) => v
    None => return None
  }
  Some({
    transaction_hash,
    transaction_index,
    block_hash,
    block_number,
    from_,
    to,
    cumulative_gas_used,
    gas_used,
    contract_address,
    logs,
    logs_bloom,
    type_,
    status,
    root,
    effective_gas_price,
    blob_gas_used,
    blob_gas_price,
  })
}

///|
/// Parse a single `Withdrawal` object.
pub fn parse_withdrawal(json : Json) -> Withdrawal? {
  let m = match json {
    Object(m) => m
    _ => return None
  }
  let index = match read_field(m, "index") {
    Some(j) =>
      match parse_hex_quantity(j) {
        Some(n) => n
        None => return None
      }
    None => return None
  }
  let validator_index = match read_field(m, "validatorIndex") {
    Some(j) =>
      match parse_hex_quantity(j) {
        Some(n) => n
        None => return None
      }
    None => return None
  }
  let address = match read_field(m, "address") {
    Some(j) =>
      match parse_hex_bytes(j) {
        Some(b) => b
        None => return None
      }
    None => return None
  }
  let amount = match read_field(m, "amount") {
    Some(j) =>
      match parse_hex_quantity(j) {
        Some(n) => n
        None => return None
      }
    None => return None
  }
  Some({ index, validator_index, address, amount })
}

///|
/// Parse a `Block` object. Handles both transaction-list shapes (hashes
/// vs. full TransactionInfo objects) by inspecting the first element.
pub fn parse_block(json : Json) -> Block? {
  let m = match json {
    Object(m) => m
    _ => return None
  }
  let hash = match opt_bytes(read_field(m, "hash")) {
    Some(v) => v
    None => return None
  }
  let parent_hash = match read_field(m, "parentHash") {
    Some(j) =>
      match parse_hex_bytes(j) {
        Some(b) => b
        None => return None
      }
    None => return None
  }
  let sha3_uncles = match read_field(m, "sha3Uncles") {
    Some(j) =>
      match parse_hex_bytes(j) {
        Some(b) => b
        None => return None
      }
    None => return None
  }
  let miner = match read_field(m, "miner") {
    Some(j) =>
      match parse_hex_bytes(j) {
        Some(b) => b
        None => return None
      }
    None => return None
  }
  let state_root = match read_field(m, "stateRoot") {
    Some(j) =>
      match parse_hex_bytes(j) {
        Some(b) => b
        None => return None
      }
    None => return None
  }
  let transactions_root = match read_field(m, "transactionsRoot") {
    Some(j) =>
      match parse_hex_bytes(j) {
        Some(b) => b
        None => return None
      }
    None => return None
  }
  let receipts_root = match read_field(m, "receiptsRoot") {
    Some(j) =>
      match parse_hex_bytes(j) {
        Some(b) => b
        None => return None
      }
    None => return None
  }
  let logs_bloom = match read_field(m, "logsBloom") {
    Some(j) =>
      match parse_hex_bytes(j) {
        Some(b) => b
        None => return None
      }
    None => return None
  }
  let difficulty = match opt_quantity(read_field(m, "difficulty")) {
    Some(v) => v
    None => return None
  }
  let number = match opt_quantity(read_field(m, "number")) {
    Some(v) => v
    None => return None
  }
  let gas_limit = match read_field(m, "gasLimit") {
    Some(j) =>
      match parse_hex_quantity(j) {
        Some(n) => n
        None => return None
      }
    None => return None
  }
  let gas_used = match read_field(m, "gasUsed") {
    Some(j) =>
      match parse_hex_quantity(j) {
        Some(n) => n
        None => return None
      }
    None => return None
  }
  let timestamp = match read_field(m, "timestamp") {
    Some(j) =>
      match parse_hex_quantity(j) {
        Some(n) => n
        None => return None
      }
    None => return None
  }
  let extra_data = match read_field(m, "extraData") {
    Some(j) =>
      match parse_hex_bytes(j) {
        Some(b) => b
        None => return None
      }
    None => return None
  }
  let mix_hash = match read_field(m, "mixHash") {
    Some(j) =>
      match parse_hex_bytes(j) {
        Some(b) => b
        None => return None
      }
    None => return None
  }
  let nonce = match read_field(m, "nonce") {
    Some(j) =>
      match parse_hex_bytes(j) {
        Some(b) => b
        None => return None
      }
    None => return None
  }
  let base_fee_per_gas = match opt_quantity(read_field(m, "baseFeePerGas")) {
    Some(v) => v
    None => return None
  }
  let withdrawals_root = match opt_bytes(read_field(m, "withdrawalsRoot")) {
    Some(v) => v
    None => return None
  }
  let withdrawals = match read_field(m, "withdrawals") {
    None => None
    Some(Null) => None
    Some(Array(arr)) => {
      let out : Array[Withdrawal] = []
      for w in arr {
        match parse_withdrawal(w) {
          Some(x) => out.push(x)
          None => return None
        }
      }
      Some(out)
    }
    Some(_) => return None
  }
  let blob_gas_used = match opt_quantity(read_field(m, "blobGasUsed")) {
    Some(v) => v
    None => return None
  }
  let excess_blob_gas = match opt_quantity(read_field(m, "excessBlobGas")) {
    Some(v) => v
    None => return None
  }
  let parent_beacon_block_root = match opt_bytes(
      read_field(m, "parentBeaconBlockRoot"),
    ) {
    Some(v) => v
    None => return None
  }
  let size = match read_field(m, "size") {
    Some(j) =>
      match parse_hex_quantity(j) {
        Some(n) => n
        None => return None
      }
    None => return None
  }
  let total_difficulty = match opt_quantity(read_field(m, "totalDifficulty")) {
    Some(v) => v
    None => return None
  }
  let transactions = match read_field(m, "transactions") {
    Some(Array(arr)) => {
      // Empty array: treat as Hashes([]) by convention.
      if arr.length() == 0 {
        BlockTransactions::Hashes([])
      } else {
        // Inspect the first element. String -> hashes; Object -> full.
        match arr[0] {
          String(_) => {
            let hs : Array[Bytes] = []
            for h in arr {
              match parse_hex_bytes(h) {
                Some(b) => hs.push(b)
                None => return None
              }
            }
            BlockTransactions::Hashes(hs)
          }
          Object(_) => {
            let txs : Array[TransactionInfo] = []
            for t in arr {
              match parse_transaction_info(t) {
                Some(ti) => txs.push(ti)
                None => return None
              }
            }
            BlockTransactions::Full(txs)
          }
          _ => return None
        }
      }
    }
    _ => return None
  }
  let uncles = match read_field(m, "uncles") {
    Some(Array(arr)) => {
      let out : Array[Bytes] = []
      for u in arr {
        match parse_hex_bytes(u) {
          Some(b) => out.push(b)
          None => return None
        }
      }
      out
    }
    _ => return None
  }
  Some({
    hash,
    parent_hash,
    sha3_uncles,
    miner,
    state_root,
    transactions_root,
    receipts_root,
    logs_bloom,
    difficulty,
    number,
    gas_limit,
    gas_used,
    timestamp,
    extra_data,
    mix_hash,
    nonce,
    base_fee_per_gas,
    withdrawals_root,
    withdrawals,
    blob_gas_used,
    excess_blob_gas,
    parent_beacon_block_root,
    size,
    total_difficulty,
    transactions,
    uncles,
  })
}

///|
/// Parse an `eth_feeHistory` result.
pub fn parse_fee_history(json : Json) -> FeeHistoryResult? {
  let m = match json {
    Object(m) => m
    _ => return None
  }
  let oldest_block = match read_field(m, "oldestBlock") {
    Some(j) =>
      match parse_hex_quantity(j) {
        Some(n) => n
        None => return None
      }
    None => return None
  }
  let base_fee_per_gas = match read_field(m, "baseFeePerGas") {
    Some(Array(arr)) => {
      let out : Array[@bigint.BigInt] = []
      for v in arr {
        match parse_hex_quantity(v) {
          Some(n) => out.push(n)
          None => return None
        }
      }
      out
    }
    _ => return None
  }
  let gas_used_ratio = match read_field(m, "gasUsedRatio") {
    Some(Array(arr)) => {
      let out : Array[Double] = []
      for v in arr {
        match v {
          Number(d, ..) => out.push(d)
          _ => return None
        }
      }
      out
    }
    _ => return None
  }
  // reward: missing means caller didn't request percentiles. Treat
  // missing/null as empty array for ergonomics; present but malformed
  // fails.
  let reward = match read_field(m, "reward") {
    None => []
    Some(Null) => []
    Some(Array(arr)) => {
      let outer : Array[Array[@bigint.BigInt]] = []
      for inner in arr {
        match inner {
          Array(ia) => {
            let row : Array[@bigint.BigInt] = []
            for v in ia {
              match parse_hex_quantity(v) {
                Some(n) => row.push(n)
                None => return None
              }
            }
            outer.push(row)
          }
          _ => return None
        }
      }
      outer
    }
    Some(_) => return None
  }
  let base_fee_per_blob_gas = match read_field(m, "baseFeePerBlobGas") {
    None => None
    Some(Null) => None
    Some(Array(arr)) => {
      let out : Array[@bigint.BigInt] = []
      for v in arr {
        match parse_hex_quantity(v) {
          Some(n) => out.push(n)
          None => return None
        }
      }
      Some(out)
    }
    Some(_) => return None
  }
  let blob_gas_used_ratio = match read_field(m, "blobGasUsedRatio") {
    None => None
    Some(Null) => None
    Some(Array(arr)) => {
      let out : Array[Double] = []
      for v in arr {
        match v {
          Number(d, ..) => out.push(d)
          _ => return None
        }
      }
      Some(out)
    }
    Some(_) => return None
  }
  Some({
    oldest_block,
    base_fee_per_gas,
    gas_used_ratio,
    reward,
    base_fee_per_blob_gas,
    blob_gas_used_ratio,
  })
}

///|
/// Parse an `eth_syncing` result. Accepts either the boolean `false`
/// (NotSyncing) or the detail object (Syncing). Boolean `true` is not
/// part of the spec but rejected explicitly.
pub fn parse_syncing_status(json : Json) -> SyncingStatus? {
  match json {
    False => Some(SyncingStatus::NotSyncing)
    True => None // not in spec
    Object(m) => {
      let starting_block = match read_field(m, "startingBlock") {
        Some(j) =>
          match parse_hex_quantity(j) {
            Some(n) => n
            None => return None
          }
        None => return None
      }
      let current_block = match read_field(m, "currentBlock") {
        Some(j) =>
          match parse_hex_quantity(j) {
            Some(n) => n
            None => return None
          }
        None => return None
      }
      let highest_block = match read_field(m, "highestBlock") {
        Some(j) =>
          match parse_hex_quantity(j) {
            Some(n) => n
            None => return None
          }
        None => return None
      }
      Some(SyncingStatus::Syncing({ starting_block, current_block, highest_block }))
    }
    _ => None
  }
}

///|
/// Parse an `eth_createAccessList` result.
pub fn parse_access_list_result(json : Json) -> AccessListResult? {
  let m = match json {
    Object(m) => m
    _ => return None
  }
  let access_list = match read_field(m, "accessList") {
    Some(j) =>
      match parse_access_list(j) {
        Some(a) => a
        None => return None
      }
    None => return None
  }
  let gas_used = match read_field(m, "gasUsed") {
    Some(j) =>
      match parse_hex_quantity(j) {
        Some(n) => n
        None => return None
      }
    None => return None
  }
  let error = match read_field(m, "error") {
    None => None
    Some(Null) => None
    Some(String(s)) => Some(s)
    Some(_) => return None
  }
  Some({ access_list, gas_used, error })
}
