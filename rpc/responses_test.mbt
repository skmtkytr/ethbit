// Tests for the typed response decoders in responses.mbt.
//
// Each parser is exercised on:
//   1. happy path (realistic abridged real-world JSON)
//   2. missing required field returns None
//   3. wrong field type returns None
//   4. malformed hex returns None

// ---------- shared helpers ----------

fn p(body : String) -> Json {
  try @json.parse(body) catch {
    _ => abort("invalid test JSON literal")
  } noraise {
    j => j
  }
}

fn hh(s : String) -> Bytes {
  match @hex.decode(s) {
    Ok(b) => b
    Err(_) => abort("invalid test hex literal")
  }
}

// 256-byte (512-hex-char) bloom, used in receipts and blocks.
fn bloom_hex() -> String {
  "0x" + String::make(512, '0')
}

// 32-byte hash hex (66 chars including "0x").
fn h32(c : Char) -> String {
  "0x" + String::make(64, c)
}

// 20-byte address hex (42 chars).
fn h20(c : Char) -> String {
  "0x" + String::make(40, c)
}

// 8-byte block-nonce hex (18 chars).
fn h8(c : Char) -> String {
  "0x" + String::make(16, c)
}

// ---------- parse_log ----------

fn sample_log_json() -> String {
  // From the EIP-20 Transfer event spec.
  let s =
    #|{
    #|  "removed": false,
    #|  "logIndex": "0x1d",
    #|  "transactionIndex": "0x4",
    #|  "transactionHash": "0x4b3c1d8c0d8a8a8b8b8c0d8a8a8b8b8c0d8a8a8b8b8c0d8a8a8b8b8c0d8a8a8b",
    #|  "blockHash": "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
    #|  "blockNumber": "0x10",
    #|  "address": "0x52908400098527886e0f7030069857d2e4169ee7",
    #|  "data": "0x000000000000000000000000000000000000000000000000000000000000002a",
    #|  "topics": [
    #|    "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
    #|    "0x0000000000000000000000005aaeb6053f3e94c9b9a09f33669435e7ef1beaed",
    #|    "0x000000000000000000000000ab5801a7d398351b8be11c439e05c5b3259aec9b"
    #|  ]
    #|}
  s
}

test "parse_log: happy path populates all fields" {
  let log = match @rpc.parse_log(p(sample_log_json())) {
    Some(l) => l
    None => {
      fail("expected Some(Log)")
      return
    }
  }
  assert_eq(log.removed, false)
  assert_eq(log.log_index, Some(@bigint.BigInt::from_int(29))) // 0x1d
  assert_eq(log.transaction_index, Some(@bigint.BigInt::from_int(4)))
  assert_eq(log.block_number, Some(@bigint.BigInt::from_int(16))) // 0x10
  assert_eq(log.address, hh("0x52908400098527886e0f7030069857d2e4169ee7"))
  assert_eq(log.topics.length(), 3)
  assert_eq(log.data.length(), 32)
}

test "parse_log: pending log with missing block fields parses" {
  // Pending log: blockHash/blockNumber/transactionHash/...Index may be null.
  let body =
    #|{
    #|  "removed": false,
    #|  "logIndex": null,
    #|  "transactionIndex": null,
    #|  "transactionHash": null,
    #|  "blockHash": null,
    #|  "blockNumber": null,
    #|  "address": "0x52908400098527886e0f7030069857d2e4169ee7",
    #|  "data": "0x",
    #|  "topics": []
    #|}
  let log = match @rpc.parse_log(p(body)) {
    Some(l) => l
    None => {
      fail("expected Some")
      return
    }
  }
  assert_eq(log.log_index, None)
  assert_eq(log.block_hash, None)
  assert_eq(log.topics.length(), 0)
}

test "parse_log: missing required `address` returns None" {
  // Drop address from the sample.
  let body =
    #|{ "removed": false, "data": "0x", "topics": [] }
  match @rpc.parse_log(p(body)) {
    None => ()
    Some(_) => fail("expected None")
  }
}

test "parse_log: wrong type for `topics` returns None" {
  let body =
    #|{
    #|  "removed": false,
    #|  "address": "0x52908400098527886e0f7030069857d2e4169ee7",
    #|  "data": "0x",
    #|  "topics": "not-an-array"
    #|}
  match @rpc.parse_log(p(body)) {
    None => ()
    Some(_) => fail("expected None")
  }
}

test "parse_log: malformed hex in `data` returns None" {
  let body =
    #|{
    #|  "removed": false,
    #|  "address": "0x52908400098527886e0f7030069857d2e4169ee7",
    #|  "data": "0xZZ",
    #|  "topics": []
    #|}
  match @rpc.parse_log(p(body)) {
    None => ()
    Some(_) => fail("expected None")
  }
}

// ---------- parse_logs ----------

test "parse_logs: array of logs" {
  let body = "[" + sample_log_json() + "]"
  let logs = match @rpc.parse_logs(p(body)) {
    Some(ls) => ls
    None => {
      fail("expected Some")
      return
    }
  }
  assert_eq(logs.length(), 1)
}

test "parse_logs: non-array returns None" {
  match @rpc.parse_logs(p("{}")) {
    None => ()
    Some(_) => fail("expected None")
  }
}

// ---------- parse_transaction_info ----------

fn sample_tx_info_json() -> String {
  // type-2 with empty access list.
  let body =
    #|{
    #|  "hash": "$H32A",
    #|  "blockHash": "$H32B",
    #|  "blockNumber": "0x10",
    #|  "transactionIndex": "0x0",
    #|  "from": "$ADDR1",
    #|  "to": "$ADDR2",
    #|  "value": "0xde0b6b3a7640000",
    #|  "gas": "0x5208",
    #|  "maxFeePerGas": "0x6fc23ac00",
    #|  "maxPriorityFeePerGas": "0x59682f00",
    #|  "nonce": "0x0",
    #|  "input": "0x",
    #|  "v": "0x1",
    #|  "r": "$H32C",
    #|  "s": "$H32D",
    #|  "type": "0x2",
    #|  "chainId": "0x1",
    #|  "accessList": []
    #|}
  body
  .replace_all(old="$H32A", new=h32('a'))
  .replace_all(old="$H32B", new=h32('b'))
  .replace_all(old="$H32C", new=h32('c'))
  .replace_all(old="$H32D", new=h32('d'))
  .replace_all(old="$ADDR1", new=h20('1'))
  .replace_all(old="$ADDR2", new=h20('2'))
}

test "parse_transaction_info: happy path (type-2 + access list)" {
  let tx = match @rpc.parse_transaction_info(p(sample_tx_info_json())) {
    Some(t) => t
    None => {
      fail("expected Some")
      return
    }
  }
  // 0xde0b6b3a7640000 = 1e18 (1 ETH in wei)
  let one_eth = @bigint.BigInt::from_string("de0b6b3a7640000", radix=16)
  assert_eq(tx.value, one_eth)
  assert_eq(tx.gas, @bigint.BigInt::from_int(21000))
  assert_eq(tx.type_, 2)
  assert_eq(tx.chain_id, Some(@bigint.BigInt::from_int(1)))
  match tx.access_list {
    Some(al) => assert_eq(al.length(), 0)
    None => fail("expected accessList present")
  }
  assert_eq(tx.from_, hh(h20('1')))
  assert_eq(tx.to, Some(hh(h20('2'))))
  assert_eq(tx.gas_price, None)
  assert_eq(tx.blob_versioned_hashes, None)
}

test "parse_transaction_info: missing required `hash` returns None" {
  let body = sample_tx_info_json().replace_all(old="\"hash\":", new="\"_hash\":")
  match @rpc.parse_transaction_info(p(body)) {
    None => ()
    Some(_) => fail("expected None")
  }
}

test "parse_transaction_info: wrong type for `value` returns None" {
  let body = sample_tx_info_json().replace_all(
    old="\"0xde0b6b3a7640000\"",
    new="123",
  )
  match @rpc.parse_transaction_info(p(body)) {
    None => ()
    Some(_) => fail("expected None")
  }
}

test "parse_transaction_info: malformed hex in `gas` returns None" {
  let body = sample_tx_info_json().replace_all(old="\"0x5208\"", new="\"0xZZ\"")
  match @rpc.parse_transaction_info(p(body)) {
    None => ()
    Some(_) => fail("expected None")
  }
}

test "parse_transaction_info: contract creation has to=null" {
  // Replace "to" value with null.
  let body = sample_tx_info_json().replace_all(
    old="\"to\": \"" + h20('2') + "\"",
    new="\"to\": null",
  )
  let tx = match @rpc.parse_transaction_info(p(body)) {
    Some(t) => t
    None => {
      fail("expected Some")
      return
    }
  }
  assert_eq(tx.to, None)
}

// ---------- parse_transaction_receipt ----------

fn sample_receipt_json() -> String {
  let body =
    #|{
    #|  "transactionHash": "$H32A",
    #|  "transactionIndex": "0x4",
    #|  "blockHash": "$H32B",
    #|  "blockNumber": "0x10",
    #|  "from": "$ADDR1",
    #|  "to": "$ADDR2",
    #|  "cumulativeGasUsed": "0x12345",
    #|  "gasUsed": "0x5208",
    #|  "contractAddress": null,
    #|  "logs": [],
    #|  "logsBloom": "$BLOOM",
    #|  "type": "0x2",
    #|  "status": "0x1",
    #|  "effectiveGasPrice": "0x4a817c800"
    #|}
  body
  .replace_all(old="$H32A", new=h32('a'))
  .replace_all(old="$H32B", new=h32('b'))
  .replace_all(old="$ADDR1", new=h20('1'))
  .replace_all(old="$ADDR2", new=h20('2'))
  .replace_all(old="$BLOOM", new=bloom_hex())
}

test "parse_transaction_receipt: happy path (post-byzantium type-2)" {
  let r = match @rpc.parse_transaction_receipt(p(sample_receipt_json())) {
    Some(r) => r
    None => {
      fail("expected Some")
      return
    }
  }
  assert_eq(r.type_, 2)
  assert_eq(r.status, Some(@bigint.BigInt::from_int(1)))
  assert_eq(r.root, None)
  assert_eq(r.gas_used, @bigint.BigInt::from_int(21000))
  assert_eq(r.cumulative_gas_used, @bigint.BigInt::from_int(0x12345))
  assert_eq(r.contract_address, None)
  assert_eq(r.logs.length(), 0)
  assert_eq(r.logs_bloom.length(), 256)
  // 0x4a817c800 = 20_000_000_000
  assert_eq(
    r.effective_gas_price,
    @bigint.BigInt::from_string("4a817c800", radix=16),
  )
}

test "parse_transaction_receipt: missing required `gasUsed` returns None" {
  let body = sample_receipt_json().replace_all(
    old="\"gasUsed\":",
    new="\"_gasUsed\":",
  )
  match @rpc.parse_transaction_receipt(p(body)) {
    None => ()
    Some(_) => fail("expected None")
  }
}

test "parse_transaction_receipt: wrong type for `logs` returns None" {
  let body = sample_receipt_json().replace_all(
    old="\"logs\": []",
    new="\"logs\": \"oops\"",
  )
  match @rpc.parse_transaction_receipt(p(body)) {
    None => ()
    Some(_) => fail("expected None")
  }
}

test "parse_transaction_receipt: malformed hex in `effectiveGasPrice` returns None" {
  let body = sample_receipt_json().replace_all(
    old="\"0x4a817c800\"",
    new="\"0xZZZ\"",
  )
  match @rpc.parse_transaction_receipt(p(body)) {
    None => ()
    Some(_) => fail("expected None")
  }
}

// ---------- parse_withdrawal ----------

test "parse_withdrawal: happy path" {
  let body =
    #|{
    #|  "index": "0x10",
    #|  "validatorIndex": "0xff",
    #|  "address": "$ADDR",
    #|  "amount": "0x12345"
    #|}
  let body = body.replace_all(old="$ADDR", new=h20('a'))
  let w = match @rpc.parse_withdrawal(p(body)) {
    Some(x) => x
    None => {
      fail("expected Some")
      return
    }
  }
  assert_eq(w.index, @bigint.BigInt::from_int(16))
  assert_eq(w.validator_index, @bigint.BigInt::from_int(255))
  assert_eq(w.amount, @bigint.BigInt::from_int(0x12345))
  assert_eq(w.address, hh(h20('a')))
}

test "parse_withdrawal: missing field returns None" {
  let body =
    #|{ "index": "0x1", "validatorIndex": "0x2", "address": "0xaaaa" }
  match @rpc.parse_withdrawal(p(body)) {
    None => ()
    Some(_) => fail("expected None")
  }
}

test "parse_withdrawal: wrong type returns None" {
  let body =
    #|{ "index": 1, "validatorIndex": "0x2", "address": "0xaaaa", "amount": "0x1" }
  match @rpc.parse_withdrawal(p(body)) {
    None => ()
    Some(_) => fail("expected None")
  }
}

test "parse_withdrawal: malformed hex returns None" {
  let body =
    #|{ "index": "0xZZ", "validatorIndex": "0x2", "address": "0xaaaa", "amount": "0x1" }
  match @rpc.parse_withdrawal(p(body)) {
    None => ()
    Some(_) => fail("expected None")
  }
}

// ---------- parse_block ----------

fn sample_block_json() -> String {
  let body =
    #|{
    #|  "hash": "$H32A",
    #|  "parentHash": "$H32B",
    #|  "sha3Uncles": "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
    #|  "miner": "$ADDR",
    #|  "stateRoot": "$H32C",
    #|  "transactionsRoot": "$H32D",
    #|  "receiptsRoot": "$H32E",
    #|  "logsBloom": "$BLOOM",
    #|  "difficulty": "0x0",
    #|  "number": "0x10",
    #|  "gasLimit": "0x1c9c380",
    #|  "gasUsed": "0xa410",
    #|  "timestamp": "0x65abcdef",
    #|  "extraData": "0x",
    #|  "mixHash": "$H32F",
    #|  "nonce": "$N8",
    #|  "baseFeePerGas": "0x12a05f200",
    #|  "withdrawalsRoot": "$H32G",
    #|  "blobGasUsed": "0x0",
    #|  "excessBlobGas": "0x0",
    #|  "parentBeaconBlockRoot": "$H32H",
    #|  "size": "0x220",
    #|  "transactions": ["$H32A", "$H32B"],
    #|  "uncles": [],
    #|  "withdrawals": []
    #|}
  body
  .replace_all(old="$H32A", new=h32('a'))
  .replace_all(old="$H32B", new=h32('b'))
  .replace_all(old="$H32C", new=h32('c'))
  .replace_all(old="$H32D", new=h32('d'))
  .replace_all(old="$H32E", new=h32('e'))
  .replace_all(old="$H32F", new=h32('f'))
  .replace_all(old="$H32G", new=h32('1'))
  .replace_all(old="$H32H", new=h32('2'))
  .replace_all(old="$ADDR", new=h20('3'))
  .replace_all(old="$BLOOM", new=bloom_hex())
  .replace_all(old="$N8", new=h8('0'))
}

test "parse_block: happy path (Cancun, hash transactions)" {
  let blk = match @rpc.parse_block(p(sample_block_json())) {
    Some(b) => b
    None => {
      fail("expected Some")
      return
    }
  }
  assert_eq(blk.number, Some(@bigint.BigInt::from_int(16)))
  assert_eq(blk.gas_limit, @bigint.BigInt::from_int(0x1c9c380))
  assert_eq(blk.gas_used, @bigint.BigInt::from_int(0xa410))
  match blk.transactions {
    Hashes(hs) => assert_eq(hs.length(), 2)
    Full(_) => fail("expected Hashes variant")
  }
  match blk.withdrawals {
    Some(ws) => assert_eq(ws.length(), 0)
    None => fail("expected withdrawals present (empty array)")
  }
  assert_eq(
    blk.base_fee_per_gas,
    Some(@bigint.BigInt::from_string("12a05f200", radix=16)),
  )
  // 8-byte nonce
  assert_eq(blk.nonce.length(), 8)
}

test "parse_block: full transactions parses to Full variant" {
  let body = sample_block_json().replace_all(
    old="\"transactions\": [\"" + h32('a') + "\", \"" + h32('b') + "\"]",
    new="\"transactions\": [" + sample_tx_info_json() + "]",
  )
  let blk = match @rpc.parse_block(p(body)) {
    Some(b) => b
    None => {
      fail("expected Some")
      return
    }
  }
  match blk.transactions {
    Full(ts) => assert_eq(ts.length(), 1)
    Hashes(_) => fail("expected Full variant")
  }
}

test "parse_block: pending block (hash=null, number=null) parses" {
  let body = sample_block_json()
    .replace_all(old="\"hash\": \"" + h32('a') + "\"", new="\"hash\": null")
    .replace_all(old="\"number\": \"0x10\"", new="\"number\": null")
  let blk = match @rpc.parse_block(p(body)) {
    Some(b) => b
    None => {
      fail("expected Some")
      return
    }
  }
  assert_eq(blk.hash, None)
  assert_eq(blk.number, None)
}

test "parse_block: missing required `parentHash` returns None" {
  let body = sample_block_json().replace_all(
    old="\"parentHash\":",
    new="\"_parentHash\":",
  )
  match @rpc.parse_block(p(body)) {
    None => ()
    Some(_) => fail("expected None")
  }
}

test "parse_block: wrong type for `transactions` returns None" {
  let body = sample_block_json().replace_all(
    old="\"transactions\": [\"" + h32('a') + "\", \"" + h32('b') + "\"]",
    new="\"transactions\": \"nope\"",
  )
  match @rpc.parse_block(p(body)) {
    None => ()
    Some(_) => fail("expected None")
  }
}

test "parse_block: malformed hex in `gasLimit` returns None" {
  let body = sample_block_json().replace_all(
    old="\"gasLimit\": \"0x1c9c380\"",
    new="\"gasLimit\": \"0xZZZ\"",
  )
  match @rpc.parse_block(p(body)) {
    None => ()
    Some(_) => fail("expected None")
  }
}

// ---------- parse_fee_history ----------

test "parse_fee_history: happy path" {
  let body =
    #|{
    #|  "oldestBlock": "0x10",
    #|  "baseFeePerGas": ["0x12a05f200", "0x12a05f300"],
    #|  "gasUsedRatio": [0.5, 0.6],
    #|  "reward": [["0x59682f00"], ["0x59682f00"]]
    #|}
  let r = match @rpc.parse_fee_history(p(body)) {
    Some(x) => x
    None => {
      fail("expected Some")
      return
    }
  }
  assert_eq(r.oldest_block, @bigint.BigInt::from_int(16))
  assert_eq(r.base_fee_per_gas.length(), 2)
  assert_eq(r.gas_used_ratio.length(), 2)
  assert_eq(r.gas_used_ratio[0], 0.5)
  assert_eq(r.reward.length(), 2)
  assert_eq(r.reward[0].length(), 1)
  assert_eq(r.base_fee_per_blob_gas, None)
}

test "parse_fee_history: missing required `oldestBlock` returns None" {
  let body =
    #|{
    #|  "baseFeePerGas": ["0x1"],
    #|  "gasUsedRatio": [0.5],
    #|  "reward": []
    #|}
  match @rpc.parse_fee_history(p(body)) {
    None => ()
    Some(_) => fail("expected None")
  }
}

test "parse_fee_history: wrong type for `gasUsedRatio` returns None" {
  let body =
    #|{
    #|  "oldestBlock": "0x10",
    #|  "baseFeePerGas": ["0x1"],
    #|  "gasUsedRatio": "nope",
    #|  "reward": []
    #|}
  match @rpc.parse_fee_history(p(body)) {
    None => ()
    Some(_) => fail("expected None")
  }
}

test "parse_fee_history: malformed hex returns None" {
  let body =
    #|{
    #|  "oldestBlock": "0x10",
    #|  "baseFeePerGas": ["0xZZ"],
    #|  "gasUsedRatio": [0.5],
    #|  "reward": []
    #|}
  match @rpc.parse_fee_history(p(body)) {
    None => ()
    Some(_) => fail("expected None")
  }
}

test "parse_fee_history: post-Cancun fields populate Some" {
  let body =
    #|{
    #|  "oldestBlock": "0x10",
    #|  "baseFeePerGas": ["0x1"],
    #|  "gasUsedRatio": [0.5],
    #|  "reward": [["0x1"]],
    #|  "baseFeePerBlobGas": ["0x1"],
    #|  "blobGasUsedRatio": [0.25]
    #|}
  let r = match @rpc.parse_fee_history(p(body)) {
    Some(x) => x
    None => {
      fail("expected Some")
      return
    }
  }
  match r.base_fee_per_blob_gas {
    Some(arr) => assert_eq(arr.length(), 1)
    None => fail("expected Some")
  }
  match r.blob_gas_used_ratio {
    Some(arr) => assert_eq(arr[0], 0.25)
    None => fail("expected Some")
  }
}

// ---------- parse_syncing_status ----------

test "parse_syncing_status: false -> NotSyncing" {
  match @rpc.parse_syncing_status(p("false")) {
    Some(NotSyncing) => ()
    _ => fail("expected NotSyncing")
  }
}

test "parse_syncing_status: object -> Syncing(detail)" {
  let body =
    #|{ "startingBlock": "0x0", "currentBlock": "0x10", "highestBlock": "0x100" }
  match @rpc.parse_syncing_status(p(body)) {
    Some(Syncing(d)) => {
      assert_eq(d.starting_block, @bigint.BigInt::from_int(0))
      assert_eq(d.current_block, @bigint.BigInt::from_int(16))
      assert_eq(d.highest_block, @bigint.BigInt::from_int(256))
    }
    _ => fail("expected Syncing")
  }
}

test "parse_syncing_status: true returns None (not in spec)" {
  match @rpc.parse_syncing_status(p("true")) {
    None => ()
    _ => fail("expected None")
  }
}

test "parse_syncing_status: missing field in detail returns None" {
  let body =
    #|{ "startingBlock": "0x0", "currentBlock": "0x10" }
  match @rpc.parse_syncing_status(p(body)) {
    None => ()
    _ => fail("expected None")
  }
}

test "parse_syncing_status: malformed hex returns None" {
  let body =
    #|{ "startingBlock": "0xZZ", "currentBlock": "0x10", "highestBlock": "0x100" }
  match @rpc.parse_syncing_status(p(body)) {
    None => ()
    _ => fail("expected None")
  }
}

test "parse_syncing_status: number returns None" {
  match @rpc.parse_syncing_status(p("123")) {
    None => ()
    _ => fail("expected None")
  }
}

// ---------- parse_access_list_result ----------

test "parse_access_list_result: happy path" {
  let body =
    #|{
    #|  "accessList": [
    #|    {
    #|      "address": "$ADDR",
    #|      "storageKeys": ["$H32A", "$H32B"]
    #|    }
    #|  ],
    #|  "gasUsed": "0x5208"
    #|}
  let body = body
    .replace_all(old="$ADDR", new=h20('a'))
    .replace_all(old="$H32A", new=h32('1'))
    .replace_all(old="$H32B", new=h32('2'))
  let r = match @rpc.parse_access_list_result(p(body)) {
    Some(x) => x
    None => {
      fail("expected Some")
      return
    }
  }
  assert_eq(r.access_list.length(), 1)
  assert_eq(r.access_list[0].storage_keys.length(), 2)
  assert_eq(r.gas_used, @bigint.BigInt::from_int(21000))
  assert_eq(r.error, None)
}

test "parse_access_list_result: with error string" {
  let body =
    #|{ "accessList": [], "gasUsed": "0x5208", "error": "execution reverted" }
  let r = match @rpc.parse_access_list_result(p(body)) {
    Some(x) => x
    None => {
      fail("expected Some")
      return
    }
  }
  assert_eq(r.error, Some("execution reverted"))
}

test "parse_access_list_result: missing required `gasUsed` returns None" {
  let body =
    #|{ "accessList": [] }
  match @rpc.parse_access_list_result(p(body)) {
    None => ()
    Some(_) => fail("expected None")
  }
}

test "parse_access_list_result: wrong type for `accessList` returns None" {
  let body =
    #|{ "accessList": "nope", "gasUsed": "0x5208" }
  match @rpc.parse_access_list_result(p(body)) {
    None => ()
    Some(_) => fail("expected None")
  }
}

test "parse_access_list_result: malformed hex in storage key returns None" {
  let body =
    #|{
    #|  "accessList": [
    #|    { "address": "0xaaaa", "storageKeys": ["0xZZ"] }
    #|  ],
    #|  "gasUsed": "0x5208"
    #|}
  match @rpc.parse_access_list_result(p(body)) {
    None => ()
    Some(_) => fail("expected None")
  }
}

// ---------- parse_access_list (helper) ----------

test "parse_access_list: empty array" {
  match @rpc.parse_access_list(p("[]")) {
    Some(a) => assert_eq(a.length(), 0)
    None => fail("expected Some")
  }
}

test "parse_access_list: non-array returns None" {
  match @rpc.parse_access_list(p("{}")) {
    None => ()
    Some(_) => fail("expected None")
  }
}
