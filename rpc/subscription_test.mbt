// Byte-exact tests for `eth_subscribe` / `eth_unsubscribe` and
// `parse_notification`. All request tests force `id = 1` before encoding so
// the canonical body is byte-comparable with a string literal.

fn h_sub(s : String) -> Bytes {
  match @hex.decode(s) {
    Ok(b) => b
    Err(_) => abort("invalid hex literal in test")
  }
}

///|
/// Build the canonical JSON-RPC body for a request after forcing id=1.
fn enc1_sub(req : @rpc.Request) -> String {
  let req1 : @rpc.Request = { id: 1, method: req.method, params: req.params }
  @rpc.encode_request(req1)
}

// ---------- eth_subscribe: NewHeads ----------

test "eth_subscribe: NewHeads -> [\"newHeads\"]" {
  let req = @rpc.eth_subscribe(NewHeads)
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"eth_subscribe","params":["newHeads"]}
  assert_eq(enc1_sub(req), expected)
}

test "eth_subscribe: NewHeads sets method field" {
  let req = @rpc.eth_subscribe(NewHeads)
  assert_eq(req.method, "eth_subscribe")
}

test "eth_subscribe: default id is 0" {
  let req = @rpc.eth_subscribe(NewHeads)
  assert_eq(req.id, 0)
}

// ---------- eth_subscribe: Logs ----------

test "eth_subscribe: Logs(filter with from/to blocks)" {
  let filter : @rpc.LogFilter = {
    from_block: Some("0x10"),
    to_block: Some("latest"),
    address: [],
    topics: [],
    block_hash: None,
  }
  let req = @rpc.eth_subscribe(Logs(filter))
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"eth_subscribe","params":["logs",{"fromBlock":"0x10","toBlock":"latest"}]}
  assert_eq(enc1_sub(req), expected)
}

test "eth_subscribe: Logs(empty filter) -> empty object" {
  let filter : @rpc.LogFilter = {
    from_block: None,
    to_block: None,
    address: [],
    topics: [],
    block_hash: None,
  }
  let req = @rpc.eth_subscribe(Logs(filter))
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"eth_subscribe","params":["logs",{}]}
  assert_eq(enc1_sub(req), expected)
}

test "eth_subscribe: Logs(filter with address + topics)" {
  let addr = h_sub("0xabababababababababababababababababababab")
  let topic = h_sub("0x" + String::make(64, '1'))
  let filter : @rpc.LogFilter = {
    from_block: None,
    to_block: None,
    address: [addr],
    topics: [[topic]],
    block_hash: None,
  }
  let req = @rpc.eth_subscribe(Logs(filter))
  let expected =
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"eth_subscribe\",\"params\":[\"logs\",{\"address\":[\"0xabababababababababababababababababababab\"],\"topics\":[[\"0x" +
    String::make(64, '1') +
    "\"]]}]}"
  assert_eq(enc1_sub(req), expected)
}

// ---------- eth_subscribe: NewPendingTransactions ----------

test "eth_subscribe: NewPendingTransactions -> [\"newPendingTransactions\"]" {
  let req = @rpc.eth_subscribe(NewPendingTransactions)
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"eth_subscribe","params":["newPendingTransactions"]}
  assert_eq(enc1_sub(req), expected)
}

// ---------- eth_subscribe: Syncing ----------

test "eth_subscribe: Syncing -> [\"syncing\"]" {
  let req = @rpc.eth_subscribe(Syncing)
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"eth_subscribe","params":["syncing"]}
  assert_eq(enc1_sub(req), expected)
}

// ---------- eth_unsubscribe ----------

test "eth_unsubscribe: 16-byte handle -> hex" {
  let id = h_sub("0xabcdef1234567890abcdef1234567890")
  let req = @rpc.eth_unsubscribe(id)
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"eth_unsubscribe","params":["0xabcdef1234567890abcdef1234567890"]}
  assert_eq(enc1_sub(req), expected)
}

test "eth_unsubscribe: short handle still encoded verbatim" {
  let req = @rpc.eth_unsubscribe(b"\xab\xcd")
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"eth_unsubscribe","params":["0xabcd"]}
  assert_eq(enc1_sub(req), expected)
}

test "eth_unsubscribe: empty bytes -> 0x" {
  let req = @rpc.eth_unsubscribe(b"")
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"eth_unsubscribe","params":["0x"]}
  assert_eq(enc1_sub(req), expected)
}

test "eth_unsubscribe: method field" {
  let req = @rpc.eth_unsubscribe(b"\x01")
  assert_eq(req.method, "eth_unsubscribe")
}

// ---------- parse_notification: happy path (NewHeads-shape payload) ----------

test "parse_notification: NewHeads-shape result is JsonObject" {
  let body =
    #|{"jsonrpc":"2.0","method":"eth_subscription","params":{"subscription":"0xcafebabe","result":{"number":"0x10","hash":"0xabc"}}}
  let n = match @rpc.parse_notification(body) {
    Some(n) => n
    None => abort("expected Some")
  }
  assert_eq(n.subscription, h_sub("0xcafebabe"))
  // Result is the inner block-header object: re-stringify and compare.
  assert_eq(n.result.stringify(), "{\"number\":\"0x10\",\"hash\":\"0xabc\"}")
}

// ---------- parse_notification: NewPendingTransactions (string payload) ----------

test "parse_notification: NewPendingTransactions-shape result is JsonString" {
  let body =
    #|{"jsonrpc":"2.0","method":"eth_subscription","params":{"subscription":"0xdeadbeef","result":"0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"}}
  let n = match @rpc.parse_notification(body) {
    Some(n) => n
    None => abort("expected Some")
  }
  assert_eq(n.subscription, h_sub("0xdeadbeef"))
  match n.result {
    String(s) =>
      assert_eq(
        s,
        "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
      )
    _ => abort("expected JsonString")
  }
}

// ---------- parse_notification: Logs payload ----------

test "parse_notification: Logs-shape result is JsonObject" {
  let body =
    #|{"jsonrpc":"2.0","method":"eth_subscription","params":{"subscription":"0x01","result":{"address":"0xababab","data":"0x00","topics":["0xff"]}}}
  let n = match @rpc.parse_notification(body) {
    Some(n) => n
    None => abort("expected Some")
  }
  assert_eq(n.subscription, b"\x01")
  match n.result {
    Object(_) => ()
    _ => abort("expected JsonObject")
  }
}

// ---------- parse_notification: Syncing-shape (boolean false) ----------

test "parse_notification: Syncing-shape result is JsonBoolean(false)" {
  let body =
    #|{"jsonrpc":"2.0","method":"eth_subscription","params":{"subscription":"0xaa","result":false}}
  let n = match @rpc.parse_notification(body) {
    Some(n) => n
    None => abort("expected Some")
  }
  assert_eq(n.subscription, b"\xaa")
  match n.result {
    False => ()
    _ => abort("expected JsonBoolean(false)")
  }
}

// ---------- parse_notification: subscription with even-length zero body ----------

test "parse_notification: subscription = \"0x\" -> empty bytes" {
  let body =
    #|{"jsonrpc":"2.0","method":"eth_subscription","params":{"subscription":"0x","result":null}}
  let n = match @rpc.parse_notification(body) {
    Some(n) => n
    None => abort("expected Some")
  }
  assert_eq(n.subscription, b"")
  match n.result {
    Null => ()
    _ => abort("expected JsonNull")
  }
}

// ---------- parse_notification: rejection cases ----------

test "parse_notification: regular response (id + result) -> None" {
  let body =
    #|{"jsonrpc":"2.0","id":1,"result":"0x10"}
  match @rpc.parse_notification(body) {
    None => ()
    Some(_) => abort("expected None")
  }
}

test "parse_notification: regular error response -> None" {
  let body =
    #|{"jsonrpc":"2.0","id":1,"error":{"code":-32000,"message":"oops"}}
  match @rpc.parse_notification(body) {
    None => ()
    Some(_) => abort("expected None")
  }
}

test "parse_notification: malformed JSON -> None" {
  let body = "{not json"
  match @rpc.parse_notification(body) {
    None => ()
    Some(_) => abort("expected None")
  }
}

test "parse_notification: empty string -> None" {
  match @rpc.parse_notification("") {
    None => ()
    Some(_) => abort("expected None")
  }
}

test "parse_notification: non-object root (array) -> None" {
  let body = "[1,2,3]"
  match @rpc.parse_notification(body) {
    None => ()
    Some(_) => abort("expected None")
  }
}

test "parse_notification: non-object root (string) -> None" {
  let body =
    #|"hello"
  match @rpc.parse_notification(body) {
    None => ()
    Some(_) => abort("expected None")
  }
}

test "parse_notification: missing jsonrpc -> None" {
  let body =
    #|{"method":"eth_subscription","params":{"subscription":"0x01","result":null}}
  match @rpc.parse_notification(body) {
    None => ()
    Some(_) => abort("expected None")
  }
}

test "parse_notification: jsonrpc != \"2.0\" -> None" {
  let body =
    #|{"jsonrpc":"1.0","method":"eth_subscription","params":{"subscription":"0x01","result":null}}
  match @rpc.parse_notification(body) {
    None => ()
    Some(_) => abort("expected None")
  }
}

test "parse_notification: missing method -> None" {
  let body =
    #|{"jsonrpc":"2.0","params":{"subscription":"0x01","result":null}}
  match @rpc.parse_notification(body) {
    None => ()
    Some(_) => abort("expected None")
  }
}

test "parse_notification: method != eth_subscription -> None" {
  let body =
    #|{"jsonrpc":"2.0","method":"eth_unrelated","params":{"subscription":"0x01","result":null}}
  match @rpc.parse_notification(body) {
    None => ()
    Some(_) => abort("expected None")
  }
}

test "parse_notification: missing params -> None" {
  let body =
    #|{"jsonrpc":"2.0","method":"eth_subscription"}
  match @rpc.parse_notification(body) {
    None => ()
    Some(_) => abort("expected None")
  }
}

test "parse_notification: params not an object -> None" {
  let body =
    #|{"jsonrpc":"2.0","method":"eth_subscription","params":["0x01","payload"]}
  match @rpc.parse_notification(body) {
    None => ()
    Some(_) => abort("expected None")
  }
}

test "parse_notification: params.subscription missing -> None" {
  let body =
    #|{"jsonrpc":"2.0","method":"eth_subscription","params":{"result":null}}
  match @rpc.parse_notification(body) {
    None => ()
    Some(_) => abort("expected None")
  }
}

test "parse_notification: params.subscription not a string -> None" {
  let body =
    #|{"jsonrpc":"2.0","method":"eth_subscription","params":{"subscription":42,"result":null}}
  match @rpc.parse_notification(body) {
    None => ()
    Some(_) => abort("expected None")
  }
}

test "parse_notification: subscription with odd-length hex body -> None" {
  let body =
    #|{"jsonrpc":"2.0","method":"eth_subscription","params":{"subscription":"0xabc","result":null}}
  match @rpc.parse_notification(body) {
    None => ()
    Some(_) => abort("expected None")
  }
}

test "parse_notification: subscription with non-hex char -> None" {
  let body =
    #|{"jsonrpc":"2.0","method":"eth_subscription","params":{"subscription":"0xzz","result":null}}
  match @rpc.parse_notification(body) {
    None => ()
    Some(_) => abort("expected None")
  }
}

test "parse_notification: params.result missing -> None" {
  let body =
    #|{"jsonrpc":"2.0","method":"eth_subscription","params":{"subscription":"0x01"}}
  match @rpc.parse_notification(body) {
    None => ()
    Some(_) => abort("expected None")
  }
}
