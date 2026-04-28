// Tests for skmtkytr/ethbit/rpc.
// Covers encode_request (deterministic byte-exact form), decode_response on
// both success and error envelopes, hex parse helpers, and the Ethereum
// convenience constructors.

fn h(s : String) -> Bytes {
  match @hex.decode(s) {
    Ok(b) => b
    Err(_) => abort("invalid hex literal in test")
  }
}

// ---------- encode_request ----------

test "encode_request: empty params, eth_blockNumber" {
  let req : @rpc.Request = {
    id: 1,
    method: "eth_blockNumber",
    params: [],
  }
  assert_eq(
    @rpc.encode_request(req),
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"eth_blockNumber\",\"params\":[]}",
  )
}

test "encode_request: id can be 0" {
  let req : @rpc.Request = { id: 0, method: "eth_chainId", params: [] }
  assert_eq(
    @rpc.encode_request(req),
    "{\"jsonrpc\":\"2.0\",\"id\":0,\"method\":\"eth_chainId\",\"params\":[]}",
  )
}

test "encode_request: id can be larger int" {
  let req : @rpc.Request = { id: 12345, method: "eth_chainId", params: [] }
  assert_eq(
    @rpc.encode_request(req),
    "{\"jsonrpc\":\"2.0\",\"id\":12345,\"method\":\"eth_chainId\",\"params\":[]}",
  )
}

test "encode_request: single string param" {
  let req : @rpc.Request = {
    id: 7,
    method: "eth_sendRawTransaction",
    params: [Json::string("0xdead")],
  }
  assert_eq(
    @rpc.encode_request(req),
    "{\"jsonrpc\":\"2.0\",\"id\":7,\"method\":\"eth_sendRawTransaction\",\"params\":[\"0xdead\"]}",
  )
}

test "encode_request: two string params" {
  let req : @rpc.Request = {
    id: 1,
    method: "eth_getBalance",
    params: [Json::string("0xabcd"), Json::string("latest")],
  }
  assert_eq(
    @rpc.encode_request(req),
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"eth_getBalance\",\"params\":[\"0xabcd\",\"latest\"]}",
  )
}

test "encode_request: method string with embedded quote is escaped" {
  // No real method has a quote, but the encoder must still produce valid JSON.
  let req : @rpc.Request = { id: 1, method: "a\"b", params: [] }
  assert_eq(
    @rpc.encode_request(req),
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"a\\\"b\",\"params\":[]}",
  )
}

// ---------- decode_response: success ----------

test "decode_response: success with hex result" {
  let body = "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":\"0x10\"}"
  match @rpc.decode_response(body) {
    Some(Ok(id, j)) => {
      assert_eq(id, 1)
      assert_eq(j, Json::string("0x10"))
    }
    other => {
      let _ = other
      fail("expected Ok variant")
    }
  }
}

test "decode_response: success with object result" {
  let body =
    #|{"jsonrpc":"2.0","id":42,"result":{"hash":"0xabc","blockNumber":"0x10"}}
  match @rpc.decode_response(body) {
    Some(Ok(id, _)) => assert_eq(id, 42)
    _ => fail("expected Ok variant")
  }
}

test "decode_response: success with null result" {
  // eth_getTransactionByHash returns null for an unknown hash.
  let body = "{\"jsonrpc\":\"2.0\",\"id\":3,\"result\":null}"
  match @rpc.decode_response(body) {
    Some(Ok(id, j)) => {
      assert_eq(id, 3)
      assert_eq(j, Json::null())
    }
    _ => fail("expected Ok variant")
  }
}

// ---------- decode_response: error ----------

test "decode_response: error envelope with int id" {
  let body =
    #|{"jsonrpc":"2.0","id":1,"error":{"code":-32601,"message":"Method not found"}}
  let expected_err : @rpc.ErrorObject = {
    code: -32601,
    message: "Method not found",
  }
  match @rpc.decode_response(body) {
    Some(Err(Some(id), e)) => {
      assert_eq(id, 1)
      assert_eq(e, expected_err)
    }
    _ => fail("expected Err(Some, _)")
  }
}

test "decode_response: error envelope with null id (parse error case)" {
  let body =
    #|{"jsonrpc":"2.0","id":null,"error":{"code":-32700,"message":"Parse error"}}
  match @rpc.decode_response(body) {
    Some(Err(None, e)) => assert_eq(e.code, -32700)
    _ => fail("expected Err(None, _)")
  }
}

// ---------- decode_response: malformed / invalid ----------

test "decode_response: malformed JSON returns None" {
  match @rpc.decode_response("{not json") {
    None => ()
    _ => fail("expected None")
  }
}

test "decode_response: non-object root returns None" {
  match @rpc.decode_response("[1,2,3]") {
    None => ()
    _ => fail("expected None")
  }
}

test "decode_response: missing id returns None" {
  match @rpc.decode_response("{\"jsonrpc\":\"2.0\",\"result\":\"0x1\"}") {
    None => ()
    _ => fail("expected None")
  }
}

test "decode_response: missing jsonrpc returns None" {
  match @rpc.decode_response("{\"id\":1,\"result\":\"0x1\"}") {
    None => ()
    _ => fail("expected None")
  }
}

test "decode_response: neither result nor error returns None" {
  match @rpc.decode_response("{\"jsonrpc\":\"2.0\",\"id\":1}") {
    None => ()
    _ => fail("expected None")
  }
}

// ---------- parse_hex_quantity ----------

test "parse_hex_quantity: 0x10 == 16" {
  match @rpc.parse_hex_quantity(Json::string("0x10")) {
    Some(n) => assert_eq(n, @bigint.BigInt::from_int(16))
    None => fail("expected Some")
  }
}

test "parse_hex_quantity: 0x0 == 0" {
  match @rpc.parse_hex_quantity(Json::string("0x0")) {
    Some(n) => assert_eq(n, @bigint.BigInt::from_int(0))
    None => fail("expected Some")
  }
}

test "parse_hex_quantity: large value" {
  // 2^64 = 18446744073709551616 = 0x10000000000000000
  match @rpc.parse_hex_quantity(Json::string("0x10000000000000000")) {
    Some(n) => {
      let two64 = @bigint.BigInt::from_int(1) << 64
      assert_eq(n, two64)
    }
    None => fail("expected Some")
  }
}

test "parse_hex_quantity: 0x without digits returns None" {
  match @rpc.parse_hex_quantity(Json::string("0x")) {
    None => ()
    _ => fail("expected None")
  }
}

test "parse_hex_quantity: missing 0x prefix returns None" {
  match @rpc.parse_hex_quantity(Json::string("10")) {
    None => ()
    _ => fail("expected None")
  }
}

test "parse_hex_quantity: invalid char returns None" {
  match @rpc.parse_hex_quantity(Json::string("0x1g")) {
    None => ()
    _ => fail("expected None")
  }
}

test "parse_hex_quantity: non-string Json returns None" {
  match @rpc.parse_hex_quantity(Json::number(16.0)) {
    None => ()
    _ => fail("expected None")
  }
}

// ---------- parse_hex_bytes ----------

test "parse_hex_bytes: 0xdeadbeef" {
  match @rpc.parse_hex_bytes(Json::string("0xdeadbeef")) {
    Some(b) => assert_eq(b, b"\xde\xad\xbe\xef")
    None => fail("expected Some")
  }
}

test "parse_hex_bytes: empty 0x" {
  match @rpc.parse_hex_bytes(Json::string("0x")) {
    Some(b) => assert_eq(b, b"")
    None => fail("expected Some")
  }
}

test "parse_hex_bytes: odd length returns None" {
  match @rpc.parse_hex_bytes(Json::string("0xa")) {
    None => ()
    _ => fail("expected None")
  }
}

test "parse_hex_bytes: non-string Json returns None" {
  match @rpc.parse_hex_bytes(Json::null()) {
    None => ()
    _ => fail("expected None")
  }
}

// ---------- convenience constructors ----------

test "eth_get_balance: well-formed params" {
  let addr = h("0x52908400098527886E0F7030069857D2E4169EE7")
  let req = @rpc.eth_get_balance(addr, "latest")
  assert_eq(req.method, "eth_getBalance")
  assert_eq(req.params.length(), 2)
  assert_eq(req.params[0], Json::string("0x52908400098527886e0f7030069857d2e4169ee7"))
  assert_eq(req.params[1], Json::string("latest"))
}

test "eth_block_number: no params" {
  let req = @rpc.eth_block_number()
  assert_eq(req.method, "eth_blockNumber")
  assert_eq(req.params.length(), 0)
}

test "eth_chain_id: no params" {
  let req = @rpc.eth_chain_id()
  assert_eq(req.method, "eth_chainId")
  assert_eq(req.params.length(), 0)
}

test "eth_get_transaction_count: well-formed params" {
  let addr = h("0x52908400098527886E0F7030069857D2E4169EE7")
  let req = @rpc.eth_get_transaction_count(addr, "pending")
  assert_eq(req.method, "eth_getTransactionCount")
  assert_eq(req.params.length(), 2)
  assert_eq(req.params[1], Json::string("pending"))
}

test "eth_send_raw_transaction: lowercase hex with 0x prefix" {
  let req = @rpc.eth_send_raw_transaction(b"\xde\xad")
  assert_eq(req.method, "eth_sendRawTransaction")
  assert_eq(req.params.length(), 1)
  assert_eq(req.params[0], Json::string("0xdead"))
}

test "eth_call: object call_data + block_tag" {
  let to = h("0x52908400098527886E0F7030069857D2E4169EE7")
  let data = b"\xab\xcd"
  let req = @rpc.eth_call(to, data, "latest")
  assert_eq(req.method, "eth_call")
  assert_eq(req.params.length(), 2)
  // Inspect the object structure of params[0]
  match req.params[0] {
    Object(m) => {
      assert_eq(
        m.get("to"),
        Some(Json::string("0x52908400098527886e0f7030069857d2e4169ee7")),
      )
      assert_eq(m.get("data"), Some(Json::string("0xabcd")))
    }
    _ => fail("expected params[0] to be an Object")
  }
  assert_eq(req.params[1], Json::string("latest"))
}

test "eth_get_transaction_by_hash: 32-byte hash hex" {
  let hash = h("0x" + String::make(64, 'a'))
  let req = @rpc.eth_get_transaction_by_hash(hash)
  assert_eq(req.method, "eth_getTransactionByHash")
  assert_eq(req.params.length(), 1)
  assert_eq(req.params[0], Json::string("0x" + String::make(64, 'a')))
}

// ---------- quantity / data helpers ----------

test "quantity_from_bytes: empty -> 0x0" {
  assert_eq(@rpc.quantity_from_bytes(b""), "0x0")
}

test "quantity_from_bytes: zero bytes -> 0x0" {
  assert_eq(@rpc.quantity_from_bytes(b"\x00\x00"), "0x0")
}

test "quantity_from_bytes: 21000 -> 0x5208" {
  assert_eq(@rpc.quantity_from_bytes(b"\x52\x08"), "0x5208")
}

test "quantity_from_bytes: 0x000a -> 0xa (no leading zeros)" {
  assert_eq(@rpc.quantity_from_bytes(b"\x00\x0a"), "0xa")
}

test "data_from_bytes: preserves leading zeros" {
  assert_eq(@rpc.data_from_bytes(b"\x00\x0a"), "0x000a")
}

test "data_from_bytes: empty -> 0x" {
  assert_eq(@rpc.data_from_bytes(b""), "0x")
}

// ---------- round-trip ----------

test "encode_request -> decode_response (hand-built reply)" {
  let req : @rpc.Request = {
    id: 99,
    method: "eth_blockNumber",
    params: [],
  }
  let body = @rpc.encode_request(req)
  // Body is the request, not a response. Build a matching response by hand:
  let reply = "{\"jsonrpc\":\"2.0\",\"id\":99,\"result\":\"0x4b7\"}"
  // Sanity: req encoded correctly
  assert_eq(
    body,
    "{\"jsonrpc\":\"2.0\",\"id\":99,\"method\":\"eth_blockNumber\",\"params\":[]}",
  )
  match @rpc.decode_response(reply) {
    Some(Ok(id, j)) => {
      assert_eq(id, 99)
      match @rpc.parse_hex_quantity(j) {
        Some(n) => assert_eq(n, @bigint.BigInt::from_int(0x4b7))
        None => fail("expected hex quantity to parse")
      }
    }
    _ => fail("expected Ok")
  }
}
