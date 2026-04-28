// Byte-exact tests for the `trace_*` constructors in `trace_methods.mbt`.
// Each test mutates `id` to 1 (the public default is 0) before encoding and
// asserts the full canonical JSON-RPC body byte-for-byte.

fn h_tr(s : String) -> Bytes {
  match @hex.decode(s) {
    Ok(b) => b
    Err(_) => abort("invalid hex literal in test")
  }
}

///|
/// Build the canonical JSON-RPC body for a request after forcing id=1.
fn enc1_tr(req : @rpc.Request) -> String {
  let req1 : @rpc.Request = { id: 1, method: req.method, params: req.params }
  @rpc.encode_request(req1)
}

// ---------- trace_block ----------

test "trace_block: latest" {
  let req = @rpc.trace_block("latest")
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"trace_block","params":["latest"]}
  assert_eq(enc1_tr(req), expected)
}

// ---------- trace_call ----------

test "trace_call: only to set, single trace type" {
  let to = h_tr("0xabababababababababababababababababababab")
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
  let req = @rpc.trace_call(call, ["trace"], "latest")
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"trace_call","params":[{"to":"0xabababababababababababababababababababab"},["trace"],"latest"]}
  assert_eq(enc1_tr(req), expected)
}

test "trace_call: multiple trace types" {
  let to = h_tr("0xabababababababababababababababababababab")
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
  let req = @rpc.trace_call(call, ["trace", "vmTrace", "stateDiff"], "0x10")
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"trace_call","params":[{"to":"0xabababababababababababababababababababab"},["trace","vmTrace","stateDiff"],"0x10"]}
  assert_eq(enc1_tr(req), expected)
}

// ---------- trace_callMany ----------

test "trace_call_many: two calls, each with own trace types" {
  let to1 = h_tr("0x1111111111111111111111111111111111111111")
  let to2 = h_tr("0x2222222222222222222222222222222222222222")
  let call1 : @rpc.TxCall = {
    from: None,
    to: Some(to1),
    gas: None,
    gas_price: None,
    max_priority_fee_per_gas: None,
    max_fee_per_gas: None,
    value: None,
    data: None,
  }
  let call2 : @rpc.TxCall = {
    from: None,
    to: Some(to2),
    gas: None,
    gas_price: None,
    max_priority_fee_per_gas: None,
    max_fee_per_gas: None,
    value: None,
    data: None,
  }
  let req = @rpc.trace_call_many(
    [(call1, ["trace"]), (call2, ["trace", "stateDiff"])],
    "latest",
  )
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"trace_callMany","params":[[[{"to":"0x1111111111111111111111111111111111111111"},["trace"]],[{"to":"0x2222222222222222222222222222222222222222"},["trace","stateDiff"]]],"latest"]}
  assert_eq(enc1_tr(req), expected)
}

test "trace_call_many: empty calls list" {
  let req = @rpc.trace_call_many([], "latest")
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"trace_callMany","params":[[],"latest"]}
  assert_eq(enc1_tr(req), expected)
}

// ---------- trace_filter ----------

test "trace_filter: empty filter -> {}" {
  let filter : @rpc.TraceFilter = {
    from_block: None,
    to_block: None,
    from_address: [],
    to_address: [],
    after: None,
    count: None,
  }
  let req = @rpc.trace_filter(filter)
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"trace_filter","params":[{}]}
  assert_eq(enc1_tr(req), expected)
}

test "trace_filter: from_block + to_block + count" {
  let filter : @rpc.TraceFilter = {
    from_block: Some("0x10"),
    to_block: Some("latest"),
    from_address: [],
    to_address: [],
    after: None,
    count: Some(100),
  }
  let req = @rpc.trace_filter(filter)
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"trace_filter","params":[{"fromBlock":"0x10","toBlock":"latest","count":100}]}
  assert_eq(enc1_tr(req), expected)
}

test "trace_filter: from_address + to_address + after" {
  let a1 = h_tr("0x1111111111111111111111111111111111111111")
  let a2 = h_tr("0x2222222222222222222222222222222222222222")
  let filter : @rpc.TraceFilter = {
    from_block: None,
    to_block: None,
    from_address: [a1],
    to_address: [a2],
    after: Some(0),
    count: None,
  }
  let req = @rpc.trace_filter(filter)
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"trace_filter","params":[{"fromAddress":["0x1111111111111111111111111111111111111111"],"toAddress":["0x2222222222222222222222222222222222222222"],"after":0}]}
  assert_eq(enc1_tr(req), expected)
}

// ---------- trace_get ----------

test "trace_get: empty indices" {
  let h = h_tr("0x" + String::make(64, 'a'))
  let req = @rpc.trace_get(h, [])
  let expected =
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"trace_get\",\"params\":[\"0x" +
    String::make(64, 'a') +
    "\",[]]}"
  assert_eq(enc1_tr(req), expected)
}

test "trace_get: indices [0,1]" {
  let h = h_tr("0x" + String::make(64, 'b'))
  let req = @rpc.trace_get(h, [0, 1])
  let expected =
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"trace_get\",\"params\":[\"0x" +
    String::make(64, 'b') +
    "\",[0,1]]}"
  assert_eq(enc1_tr(req), expected)
}

// ---------- trace_rawTransaction ----------

test "trace_raw_transaction: raw bytes + trace types" {
  let req = @rpc.trace_raw_transaction(b"\xde\xad", ["trace"])
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"trace_rawTransaction","params":["0xdead",["trace"]]}
  assert_eq(enc1_tr(req), expected)
}

// ---------- trace_replayBlockTransactions ----------

test "trace_replay_block_transactions: tag + types" {
  let req = @rpc.trace_replay_block_transactions("0x10", ["trace", "stateDiff"])
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"trace_replayBlockTransactions","params":["0x10",["trace","stateDiff"]]}
  assert_eq(enc1_tr(req), expected)
}

// ---------- trace_replayTransaction ----------

test "trace_replay_transaction: hash + types" {
  let h = h_tr("0x" + String::make(64, 'c'))
  let req = @rpc.trace_replay_transaction(h, ["trace"])
  let expected =
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"trace_replayTransaction\",\"params\":[\"0x" +
    String::make(64, 'c') +
    "\",[\"trace\"]]}"
  assert_eq(enc1_tr(req), expected)
}

// ---------- trace_transaction ----------

test "trace_transaction: hash" {
  let h = h_tr("0x" + String::make(64, 'd'))
  let req = @rpc.trace_transaction(h)
  let expected =
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"trace_transaction\",\"params\":[\"0x" +
    String::make(64, 'd') +
    "\"]}"
  assert_eq(enc1_tr(req), expected)
}

// ---------- trace_filter_to_json helper ----------

test "trace_filter_to_json: empty -> {}" {
  let filter : @rpc.TraceFilter = {
    from_block: None,
    to_block: None,
    from_address: [],
    to_address: [],
    after: None,
    count: None,
  }
  assert_eq(@rpc.trace_filter_to_json(filter).stringify(), "{}")
}
