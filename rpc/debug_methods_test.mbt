// Byte-exact tests for the `debug_*` constructors in `debug_methods.mbt`.
// Each test mutates `id` to 1 (the public default is 0) before encoding and
// asserts the full canonical JSON-RPC body byte-for-byte.

fn h_dbg(s : String) -> Bytes {
  match @hex.decode(s) {
    Ok(b) => b
    Err(_) => abort("invalid hex literal in test")
  }
}

///|
/// Build the canonical JSON-RPC body for a request after forcing id=1.
fn enc1_dbg(req : @rpc.Request) -> String {
  let req1 : @rpc.Request = { id: 1, method: req.method, params: req.params }
  @rpc.encode_request(req1)
}

// ---------- debug_traceTransaction ----------

test "debug_trace_transaction: tracer = None -> single-param" {
  let h = h_dbg("0x" + String::make(64, 'a'))
  let req = @rpc.debug_trace_transaction(h, None)
  let expected =
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"debug_traceTransaction\",\"params\":[\"0x" +
    String::make(64, 'a') +
    "\"]}"
  assert_eq(enc1_dbg(req), expected)
}

test "debug_trace_transaction: tracer = Some(callTracer)" {
  let h = h_dbg("0x" + String::make(64, 'b'))
  let req = @rpc.debug_trace_transaction(h, Some("callTracer"))
  let expected =
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"debug_traceTransaction\",\"params\":[\"0x" +
    String::make(64, 'b') +
    "\",{\"tracer\":\"callTracer\"}]}"
  assert_eq(enc1_dbg(req), expected)
}

// ---------- debug_traceCall ----------

test "debug_trace_call: tracer None, only `to` set in call" {
  let to = h_dbg("0xabababababababababababababababababababab")
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
  let req = @rpc.debug_trace_call(call, "latest", None)
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"debug_traceCall","params":[{"to":"0xabababababababababababababababababababab"},"latest"]}
  assert_eq(enc1_dbg(req), expected)
}

test "debug_trace_call: tracer Some(prestateTracer)" {
  let to = h_dbg("0xabababababababababababababababababababab")
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
  let req = @rpc.debug_trace_call(call, "0x10", Some("prestateTracer"))
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"debug_traceCall","params":[{"to":"0xabababababababababababababababababababab","data":"0xdead"},"0x10",{"tracer":"prestateTracer"}]}
  assert_eq(enc1_dbg(req), expected)
}

// ---------- debug_traceBlockByHash ----------

test "debug_trace_block_by_hash: tracer None" {
  let h = h_dbg("0x" + String::make(64, 'c'))
  let req = @rpc.debug_trace_block_by_hash(h, None)
  let expected =
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"debug_traceBlockByHash\",\"params\":[\"0x" +
    String::make(64, 'c') +
    "\"]}"
  assert_eq(enc1_dbg(req), expected)
}

test "debug_trace_block_by_hash: tracer Some" {
  let h = h_dbg("0x" + String::make(64, 'd'))
  let req = @rpc.debug_trace_block_by_hash(h, Some("callTracer"))
  let expected =
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"debug_traceBlockByHash\",\"params\":[\"0x" +
    String::make(64, 'd') +
    "\",{\"tracer\":\"callTracer\"}]}"
  assert_eq(enc1_dbg(req), expected)
}

// ---------- debug_traceBlockByNumber ----------

test "debug_trace_block_by_number: tracer None" {
  let req = @rpc.debug_trace_block_by_number("latest", None)
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"debug_traceBlockByNumber","params":["latest"]}
  assert_eq(enc1_dbg(req), expected)
}

test "debug_trace_block_by_number: tracer Some" {
  let req = @rpc.debug_trace_block_by_number("0x10", Some("callTracer"))
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"debug_traceBlockByNumber","params":["0x10",{"tracer":"callTracer"}]}
  assert_eq(enc1_dbg(req), expected)
}

// ---------- debug_getRaw* ----------

test "debug_get_raw_transaction" {
  let h = h_dbg("0x" + String::make(64, 'e'))
  let req = @rpc.debug_get_raw_transaction(h)
  let expected =
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"debug_getRawTransaction\",\"params\":[\"0x" +
    String::make(64, 'e') +
    "\"]}"
  assert_eq(enc1_dbg(req), expected)
}

test "debug_get_raw_block" {
  let req = @rpc.debug_get_raw_block("latest")
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"debug_getRawBlock","params":["latest"]}
  assert_eq(enc1_dbg(req), expected)
}

test "debug_get_raw_header" {
  let req = @rpc.debug_get_raw_header("0x1")
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"debug_getRawHeader","params":["0x1"]}
  assert_eq(enc1_dbg(req), expected)
}

test "debug_get_raw_receipts" {
  let req = @rpc.debug_get_raw_receipts("pending")
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"debug_getRawReceipts","params":["pending"]}
  assert_eq(enc1_dbg(req), expected)
}
