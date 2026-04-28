// Byte-exact tests for the `net_*`, `web3_*`, `txpool_*` constructors in
// `other_methods.mbt`. Each test mutates `id` to 1 (the public default is 0)
// before encoding and asserts the full canonical JSON-RPC body byte-for-byte.

fn h_other(s : String) -> Bytes {
  match @hex.decode(s) {
    Ok(b) => b
    Err(_) => abort("invalid hex literal in test")
  }
}

///|
/// Build the canonical JSON-RPC body for a request after forcing id=1.
fn enc1_other(req : @rpc.Request) -> String {
  let req1 : @rpc.Request = { id: 1, method: req.method, params: req.params }
  @rpc.encode_request(req1)
}

// ---------- net_ ----------

test "net_listening: no params" {
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"net_listening","params":[]}
  assert_eq(enc1_other(@rpc.net_listening()), expected)
}

test "net_peer_count: no params" {
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"net_peerCount","params":[]}
  assert_eq(enc1_other(@rpc.net_peer_count()), expected)
}

test "net_version: no params" {
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"net_version","params":[]}
  assert_eq(enc1_other(@rpc.net_version()), expected)
}

// ---------- web3_ ----------

test "web3_client_version: no params" {
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"web3_clientVersion","params":[]}
  assert_eq(enc1_other(@rpc.web3_client_version()), expected)
}

test "web3_sha3: 0xdead" {
  let req = @rpc.web3_sha3(b"\xde\xad")
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"web3_sha3","params":["0xdead"]}
  assert_eq(enc1_other(req), expected)
}

test "web3_sha3: empty bytes -> 0x" {
  let req = @rpc.web3_sha3(b"")
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"web3_sha3","params":["0x"]}
  assert_eq(enc1_other(req), expected)
}

// ---------- txpool_ ----------

test "txpool_content: no params" {
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"txpool_content","params":[]}
  assert_eq(enc1_other(@rpc.txpool_content()), expected)
}

test "txpool_content_from: address" {
  let addr = h_other("0x52908400098527886E0F7030069857D2E4169EE7")
  let req = @rpc.txpool_content_from(addr)
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"txpool_contentFrom","params":["0x52908400098527886e0f7030069857d2e4169ee7"]}
  assert_eq(enc1_other(req), expected)
}

test "txpool_inspect: no params" {
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"txpool_inspect","params":[]}
  assert_eq(enc1_other(@rpc.txpool_inspect()), expected)
}

test "txpool_status: no params" {
  let expected =
    #|{"jsonrpc":"2.0","id":1,"method":"txpool_status","params":[]}
  assert_eq(enc1_other(@rpc.txpool_status()), expected)
}
