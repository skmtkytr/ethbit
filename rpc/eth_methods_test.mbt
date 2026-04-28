// Byte-exact tests for the `eth_*` constructors added in `eth_methods.mbt`.
// Each test mutates `id` to 1 (the public default is 0) before encoding and
// asserts the full canonical JSON-RPC body byte-for-byte.

fn h_eth(s : String) -> Bytes {
  match @hex.decode(s) {
    Ok(b) => b
    Err(_) => abort("invalid hex literal in test")
  }
}

///|
/// Build the canonical JSON-RPC body for a request after forcing id=1.
fn enc1(req : @rpc.Request) -> String {
  let req1 : @rpc.Request = { id: 1, method: req.method, params: req.params }
  @rpc.encode_request(req1)
}

// ---------- state queries ----------

test "eth_get_code: address + block_tag" {
  let addr = h_eth("0x52908400098527886E0F7030069857D2E4169EE7")
  let req = @rpc.eth_get_code(addr, "latest")
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"eth_getCode","params":["0x52908400098527886e0f7030069857d2e4169ee7","latest"]}
  assert_eq(enc1(req), expected)
}

test "eth_get_storage_at: address + key + block_tag" {
  let addr = h_eth("0x52908400098527886E0F7030069857D2E4169EE7")
  let req = @rpc.eth_get_storage_at(addr, "0x0", "latest")
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"eth_getStorageAt","params":["0x52908400098527886e0f7030069857d2e4169ee7","0x0","latest"]}
  assert_eq(enc1(req), expected)
}

test "eth_gas_price: no params" {
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"eth_gasPrice","params":[]}
  assert_eq(enc1(@rpc.eth_gas_price()), expected)
}

test "eth_max_priority_fee_per_gas: no params" {
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"eth_maxPriorityFeePerGas","params":[]}
  assert_eq(enc1(@rpc.eth_max_priority_fee_per_gas()), expected)
}

test "eth_fee_history: int -> hex, percentiles as numbers" {
  let req = @rpc.eth_fee_history(4, "latest", [25.0, 75.0])
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"eth_feeHistory","params":["0x4","latest",[25,75]]}
  assert_eq(enc1(req), expected)
}

test "eth_fee_history: empty percentiles list" {
  let req = @rpc.eth_fee_history(1, "0x10", [])
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"eth_feeHistory","params":["0x1","0x10",[]]}
  assert_eq(enc1(req), expected)
}

test "eth_blob_base_fee: no params" {
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"eth_blobBaseFee","params":[]}
  assert_eq(enc1(@rpc.eth_blob_base_fee()), expected)
}

test "eth_protocol_version: no params" {
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"eth_protocolVersion","params":[]}
  assert_eq(enc1(@rpc.eth_protocol_version()), expected)
}

test "eth_syncing: no params" {
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"eth_syncing","params":[]}
  assert_eq(enc1(@rpc.eth_syncing()), expected)
}

test "eth_accounts: no params" {
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"eth_accounts","params":[]}
  assert_eq(enc1(@rpc.eth_accounts()), expected)
}

test "eth_coinbase: no params" {
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"eth_coinbase","params":[]}
  assert_eq(enc1(@rpc.eth_coinbase()), expected)
}

test "eth_mining: no params" {
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"eth_mining","params":[]}
  assert_eq(enc1(@rpc.eth_mining()), expected)
}

test "eth_hashrate: no params" {
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"eth_hashrate","params":[]}
  assert_eq(enc1(@rpc.eth_hashrate()), expected)
}

// ---------- block queries ----------

test "eth_get_block_by_hash: hash + true" {
  let hash = h_eth("0x" + String::make(64, 'a'))
  let req = @rpc.eth_get_block_by_hash(hash, true)
  let expected =
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"eth_getBlockByHash\",\"params\":[\"0x" +
    String::make(64, 'a') +
    "\",true]}"
  assert_eq(enc1(req), expected)
}

test "eth_get_block_by_number: hex tag + true" {
  let req = @rpc.eth_get_block_by_number("0x10", true)
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"eth_getBlockByNumber","params":["0x10",true]}
  assert_eq(enc1(req), expected)
}

test "eth_get_block_by_number: latest + false" {
  let req = @rpc.eth_get_block_by_number("latest", false)
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"eth_getBlockByNumber","params":["latest",false]}
  assert_eq(enc1(req), expected)
}

test "eth_get_block_receipts: passthrough string" {
  let req = @rpc.eth_get_block_receipts("0x10")
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"eth_getBlockReceipts","params":["0x10"]}
  assert_eq(enc1(req), expected)
}

test "eth_get_block_transaction_count_by_hash" {
  let hash = h_eth("0x" + String::make(64, 'b'))
  let req = @rpc.eth_get_block_transaction_count_by_hash(hash)
  let expected =
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"eth_getBlockTransactionCountByHash\",\"params\":[\"0x" +
    String::make(64, 'b') +
    "\"]}"
  assert_eq(enc1(req), expected)
}

test "eth_get_block_transaction_count_by_number" {
  let req = @rpc.eth_get_block_transaction_count_by_number("pending")
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"eth_getBlockTransactionCountByNumber","params":["pending"]}
  assert_eq(enc1(req), expected)
}

// ---------- transaction queries ----------

test "eth_get_transaction_by_block_hash_and_index: index hex" {
  let hash = h_eth("0x" + String::make(64, 'c'))
  let req = @rpc.eth_get_transaction_by_block_hash_and_index(hash, 0)
  let expected =
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"eth_getTransactionByBlockHashAndIndex\",\"params\":[\"0x" +
    String::make(64, 'c') +
    "\",\"0x0\"]}"
  assert_eq(enc1(req), expected)
}

test "eth_get_transaction_by_block_number_and_index" {
  let req = @rpc.eth_get_transaction_by_block_number_and_index("latest", 5)
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"eth_getTransactionByBlockNumberAndIndex","params":["latest","0x5"]}
  assert_eq(enc1(req), expected)
}

test "eth_get_transaction_receipt" {
  let hash = h_eth("0x" + String::make(64, 'd'))
  let req = @rpc.eth_get_transaction_receipt(hash)
  let expected =
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"eth_getTransactionReceipt\",\"params\":[\"0x" +
    String::make(64, 'd') +
    "\"]}"
  assert_eq(enc1(req), expected)
}

// ---------- uncle queries ----------

test "eth_get_uncle_by_block_hash_and_index" {
  let hash = h_eth("0x" + String::make(64, 'e'))
  let req = @rpc.eth_get_uncle_by_block_hash_and_index(hash, 0)
  let expected =
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"eth_getUncleByBlockHashAndIndex\",\"params\":[\"0x" +
    String::make(64, 'e') +
    "\",\"0x0\"]}"
  assert_eq(enc1(req), expected)
}

test "eth_get_uncle_by_block_number_and_index" {
  let req = @rpc.eth_get_uncle_by_block_number_and_index("0x10", 1)
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"eth_getUncleByBlockNumberAndIndex","params":["0x10","0x1"]}
  assert_eq(enc1(req), expected)
}

test "eth_get_uncle_count_by_block_hash" {
  let hash = h_eth("0x" + String::make(64, 'f'))
  let req = @rpc.eth_get_uncle_count_by_block_hash(hash)
  let expected =
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"eth_getUncleCountByBlockHash\",\"params\":[\"0x" +
    String::make(64, 'f') +
    "\"]}"
  assert_eq(enc1(req), expected)
}

test "eth_get_uncle_count_by_block_number" {
  let req = @rpc.eth_get_uncle_count_by_block_number("latest")
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"eth_getUncleCountByBlockNumber","params":["latest"]}
  assert_eq(enc1(req), expected)
}

// ---------- call / sim ----------

test "eth_estimate_gas: only to + data set, others omitted" {
  let to = h_eth("0xabababababababababababababababababababab")
  let call : @rpc.TxCall = {
    from: None,
    to: Some(to),
    gas: None,
    gas_price: None,
    max_priority_fee_per_gas: None,
    max_fee_per_gas: None,
    value: None,
    data: Some(b"\xde\xad"),
  }
  let req = @rpc.eth_estimate_gas(call, "latest")
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"eth_estimateGas","params":[{"to":"0xabababababababababababababababababababab","data":"0xdead"},"latest"]}
  assert_eq(enc1(req), expected)
}

test "eth_estimate_gas: all fields set, insertion-ordered keys" {
  let from = h_eth("0x1111111111111111111111111111111111111111")
  let to = h_eth("0x2222222222222222222222222222222222222222")
  let call : @rpc.TxCall = {
    from: Some(from),
    to: Some(to),
    gas: Some(@bigint.BigInt::from_int(21000)),
    gas_price: Some(@bigint.BigInt::from_int(0)),
    max_priority_fee_per_gas: Some(@bigint.BigInt::from_int(1)),
    max_fee_per_gas: Some(@bigint.BigInt::from_int(2)),
    value: Some(@bigint.BigInt::from_int(10)),
    data: Some(b"\xbe\xef"),
  }
  let req = @rpc.eth_estimate_gas(call, "0x10")
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"eth_estimateGas","params":[{"from":"0x1111111111111111111111111111111111111111","to":"0x2222222222222222222222222222222222222222","gas":"0x5208","gasPrice":"0x0","maxPriorityFeePerGas":"0x1","maxFeePerGas":"0x2","value":"0xa","data":"0xbeef"},"0x10"]}
  assert_eq(enc1(req), expected)
}

test "eth_create_access_list: just to set" {
  let to = h_eth("0xabababababababababababababababababababab")
  let call : @rpc.TxCall = {
    from: None,
    to: Some(to),
    gas: None,
    gas_price: None,
    max_priority_fee_per_gas: None,
    max_fee_per_gas: None,
    value: None,
    data: None,
  }
  let req = @rpc.eth_create_access_list(call, "latest")
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"eth_createAccessList","params":[{"to":"0xabababababababababababababababababababab"},"latest"]}
  assert_eq(enc1(req), expected)
}

test "eth_get_proof: address + 2 storage keys + block_tag" {
  let addr = h_eth("0x52908400098527886E0F7030069857D2E4169EE7")
  let k1 = h_eth("0x" + String::make(64, '0'))
  let k2 = h_eth(
    "0x000000000000000000000000000000000000000000000000000000000000000a",
  )
  let req = @rpc.eth_get_proof(addr, [k1, k2], "latest")
  let expected =
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"eth_getProof\",\"params\":[\"0x52908400098527886e0f7030069857d2e4169ee7\",[\"0x" +
    String::make(64, '0') +
    "\",\"0x000000000000000000000000000000000000000000000000000000000000000a\"],\"latest\"]}"
  assert_eq(enc1(req), expected)
}

test "eth_get_proof: empty storage keys array" {
  let addr = h_eth("0x52908400098527886E0F7030069857D2E4169EE7")
  let req = @rpc.eth_get_proof(addr, [], "latest")
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"eth_getProof","params":["0x52908400098527886e0f7030069857d2e4169ee7",[],"latest"]}
  assert_eq(enc1(req), expected)
}

// ---------- tx submission ----------

test "eth_send_transaction: from + to + value" {
  let from = h_eth("0x1111111111111111111111111111111111111111")
  let to = h_eth("0x2222222222222222222222222222222222222222")
  let call : @rpc.TxCall = {
    from: Some(from),
    to: Some(to),
    gas: None,
    gas_price: None,
    max_priority_fee_per_gas: None,
    max_fee_per_gas: None,
    value: Some(@bigint.BigInt::from_int(100)),
    data: None,
  }
  let req = @rpc.eth_send_transaction(call)
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"eth_sendTransaction","params":[{"from":"0x1111111111111111111111111111111111111111","to":"0x2222222222222222222222222222222222222222","value":"0x64"}]}
  assert_eq(enc1(req), expected)
}

test "eth_sign_transaction: from + to" {
  let from = h_eth("0x1111111111111111111111111111111111111111")
  let to = h_eth("0x2222222222222222222222222222222222222222")
  let call : @rpc.TxCall = {
    from: Some(from),
    to: Some(to),
    gas: None,
    gas_price: None,
    max_priority_fee_per_gas: None,
    max_fee_per_gas: None,
    value: None,
    data: None,
  }
  let req = @rpc.eth_sign_transaction(call)
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"eth_signTransaction","params":[{"from":"0x1111111111111111111111111111111111111111","to":"0x2222222222222222222222222222222222222222"}]}
  assert_eq(enc1(req), expected)
}

test "eth_sign: address + data" {
  let addr = h_eth("0x52908400098527886E0F7030069857D2E4169EE7")
  let req = @rpc.eth_sign(addr, b"\xde\xad")
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"eth_sign","params":["0x52908400098527886e0f7030069857d2e4169ee7","0xdead"]}
  assert_eq(enc1(req), expected)
}

// ---------- logs / filters ----------

test "eth_get_logs: from_block + to_block, empty arrays omitted" {
  let filter : @rpc.LogFilter = {
    from_block: Some("0x10"),
    to_block: Some("latest"),
    address: [],
    topics: [],
    block_hash: None,
  }
  let req = @rpc.eth_get_logs(filter)
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"eth_getLogs","params":[{"fromBlock":"0x10","toBlock":"latest"}]}
  assert_eq(enc1(req), expected)
}

test "eth_get_logs: address + topics populated" {
  let addr = h_eth("0xabababababababababababababababababababab")
  let topic = h_eth("0x" + String::make(64, '1'))
  let filter : @rpc.LogFilter = {
    from_block: None,
    to_block: None,
    address: [addr],
    topics: [[topic]],
    block_hash: None,
  }
  let req = @rpc.eth_get_logs(filter)
  let expected =
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"eth_getLogs\",\"params\":[{\"address\":[\"0xabababababababababababababababababababab\"],\"topics\":[[\"0x" +
    String::make(64, '1') +
    "\"]]}]}"
  assert_eq(enc1(req), expected)
}

test "eth_get_logs: block_hash only" {
  let bh = h_eth("0x" + String::make(64, '2'))
  let filter : @rpc.LogFilter = {
    from_block: None,
    to_block: None,
    address: [],
    topics: [],
    block_hash: Some(bh),
  }
  let req = @rpc.eth_get_logs(filter)
  let expected =
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"eth_getLogs\",\"params\":[{\"blockHash\":\"0x" +
    String::make(64, '2') +
    "\"}]}"
  assert_eq(enc1(req), expected)
}

test "eth_new_filter: same shape as eth_getLogs" {
  let filter : @rpc.LogFilter = {
    from_block: Some("earliest"),
    to_block: Some("latest"),
    address: [],
    topics: [],
    block_hash: None,
  }
  let req = @rpc.eth_new_filter(filter)
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"eth_newFilter","params":[{"fromBlock":"earliest","toBlock":"latest"}]}
  assert_eq(enc1(req), expected)
}

test "eth_new_block_filter: no params" {
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"eth_newBlockFilter","params":[]}
  assert_eq(enc1(@rpc.eth_new_block_filter()), expected)
}

test "eth_new_pending_transaction_filter: no params" {
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"eth_newPendingTransactionFilter","params":[]}
  assert_eq(enc1(@rpc.eth_new_pending_transaction_filter()), expected)
}

test "eth_uninstall_filter: bigint id" {
  let req = @rpc.eth_uninstall_filter(@bigint.BigInt::from_int(0x1f))
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"eth_uninstallFilter","params":["0x1f"]}
  assert_eq(enc1(req), expected)
}

test "eth_get_filter_changes: bigint id" {
  let req = @rpc.eth_get_filter_changes(@bigint.BigInt::from_int(0))
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"eth_getFilterChanges","params":["0x0"]}
  assert_eq(enc1(req), expected)
}

test "eth_get_filter_logs: bigint id" {
  let req = @rpc.eth_get_filter_logs(@bigint.BigInt::from_int(255))
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"eth_getFilterLogs","params":["0xff"]}
  assert_eq(enc1(req), expected)
}

// ---------- helpers ----------

test "quantity_from_bigint: zero -> 0x0" {
  assert_eq(@rpc.quantity_from_bigint(@bigint.BigInt::from_int(0)), "0x0")
}

test "quantity_from_bigint: 4096 -> 0x1000" {
  assert_eq(@rpc.quantity_from_bigint(@bigint.BigInt::from_int(4096)), "0x1000")
}

test "quantity_from_int: 4 -> 0x4" {
  assert_eq(@rpc.quantity_from_int(4), "0x4")
}

test "tx_call_to_json: empty -> {}" {
  let call : @rpc.TxCall = {
    from: None,
    to: None,
    gas: None,
    gas_price: None,
    max_priority_fee_per_gas: None,
    max_fee_per_gas: None,
    value: None,
    data: None,
  }
  assert_eq(@rpc.tx_call_to_json(call).stringify(), "{}")
}

test "log_filter_to_json: empty -> {}" {
  let filter : @rpc.LogFilter = {
    from_block: None,
    to_block: None,
    address: [],
    topics: [],
    block_hash: None,
  }
  assert_eq(@rpc.log_filter_to_json(filter).stringify(), "{}")
}
