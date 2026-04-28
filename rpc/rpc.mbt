// JSON-RPC 2.0 request/response (de)serialization for Ethereum.
// Spec: https://www.jsonrpc.org/specification
// Ethereum methods: https://ethereum.org/en/developers/docs/apis/json-rpc/
//
// This package only handles the JSON body. Transport (HTTP, IPC, WS) is the
// caller's job — feed `encode_request` output to your client of choice and
// pass the response body to `decode_response`.
//
// JSON serialization uses moonbitlang/core/json:
//   - `@json.parse` (StringView) for decoding
//   - `Json::stringify` for serializing values inside `Array[Json]` params
// Requests are built by direct string concatenation so field order is
// deterministic — strict JSON-RPC 2.0 doesn't require a specific order, but
// byte-exact tests are easier with one. The output is always:
//   {"jsonrpc":"2.0","id":<id>,"method":"<method>","params":[...]}

///|
/// JSON-RPC request. The `method` field uses MoonBit's reserved word
/// (suppressed via `#warnings`) because the JSON-RPC spec requires that
/// exact name.
pub(all) struct Request {
  id : Int
  method : String
  params : Array[Json]
}

///|
pub(all) struct ErrorObject {
  code : Int
  message : String
} derive(Eq)

///|
pub impl Show for ErrorObject with output(self, logger) {
  logger.write_string("ErrorObject{ code: ")
  logger.write_object(self.code)
  logger.write_string(", message: ")
  logger.write_object(self.message)
  logger.write_string(" }")
}

///|
pub(all) enum Response {
  Ok(Int, Json)
  Err(Int?, ErrorObject)
}

///|
pub impl Eq for Response with equal(a, b) {
  match (a, b) {
    (Ok(ia, ja), Ok(ib, jb)) => ia == ib && ja == jb
    (Err(ia, ea), Err(ib, eb)) => ia == ib && ea == eb
    _ => false
  }
}

///|
pub impl Show for Response with output(self, logger) {
  match self {
    Ok(id, j) => {
      logger.write_string("Ok(")
      logger.write_object(id)
      logger.write_string(", ")
      logger.write_object(j)
      logger.write_char(')')
    }
    Err(id, e) => {
      logger.write_string("Err(")
      logger.write_object(id)
      logger.write_string(", ")
      logger.write_object(e)
      logger.write_char(')')
    }
  }
}

// ---------- encode ----------

///|
/// Returns the canonical JSON-RPC 2.0 body for the given request.
/// Format (deterministic):
/// `{"jsonrpc":"2.0","id":<id>,"method":"<method>","params":[...]}`
pub fn encode_request(req : Request) -> String {
  let mut s = "{\"jsonrpc\":\"2.0\",\"id\":"
  s = s + req.id.to_string()
  s = s + ",\"method\":"
  s = s + json_encode_string(req.method)
  s = s + ",\"params\":["
  let n = req.params.length()
  for i = 0; i < n; i = i + 1 {
    if i > 0 {
      s = s + ","
    }
    s = s + req.params[i].stringify()
  }
  s = s + "]}"
  s
}

///|
/// JSON-encode a MoonBit string: wraps in double quotes and escapes per RFC 8259.
fn json_encode_string(s : String) -> String {
  // Use the Json::stringify of String(s) for full RFC 8259 escaping (handles
  // control chars, quote, backslash, surrogates, etc.). This avoids
  // re-implementing the lexer.
  Json::stringify(Json::string(s))
}

// ---------- decode ----------

///|
/// Parse a JSON-RPC 2.0 response body. Returns `None` on:
///   - malformed JSON
///   - missing or non-object root
///   - missing `jsonrpc` field
///   - missing both `result` and `error` fields
///   - missing `id` field (must be present, even if null)
pub fn decode_response(body : String) -> Response? {
  let parsed = try? @json.parse(body)
  let root = match parsed {
    Ok(j) => j
    Err(_) => return None
  }
  let obj = match root {
    Object(m) => m
    _ => return None
  }
  // jsonrpc field must be present (per spec). Don't enforce its value strictly
  // — most servers send "2.0" but a few legacy endpoints omit the version
  // string. Presence-only check matches viem/ethers-style permissiveness.
  if obj.get("jsonrpc") is None {
    return None
  }
  let id = match obj.get("id") {
    Some(Number(n, ..)) => Some(n.to_int())
    Some(Null) => None
    Some(_) => return None // wrong type
    None => return None // missing
  }
  match obj.get("error") {
    Some(err_json) => {
      let err = match decode_error_object(err_json) {
        Some(e) => e
        None => return None
      }
      Some(Err(id, err))
    }
    None =>
      match obj.get("result") {
        Some(result) =>
          match id {
            Some(i) => Some(Ok(i, result))
            None => None // success response with null id is invalid
          }
        None => None // neither result nor error
      }
  }
}

///|
fn decode_error_object(j : Json) -> ErrorObject? {
  let m = match j {
    Object(m) => m
    _ => return None
  }
  let code = match m.get("code") {
    Some(Number(n, ..)) => n.to_int()
    _ => return None
  }
  let message = match m.get("message") {
    Some(String(s)) => s
    _ => return None
  }
  Some({ code, message })
}

// ---------- hex helpers for Ethereum results ----------

///|
/// Read a JSON-RPC "Quantity" hex string (e.g. "0x1a2b") into a BigInt.
/// Returns `None` on:
///   - non-string Json
///   - missing "0x"/"0X" prefix
///   - empty hex body ("0x" with no digits)
///   - any non-hex character in the body
pub fn parse_hex_quantity(json : Json) -> @bigint.BigInt? {
  let s = match json {
    String(s) => s
    _ => return None
  }
  let chars = s.iter().to_array()
  let n = chars.length()
  if n < 3 || chars[0] != '0' || (chars[1] != 'x' && chars[1] != 'X') {
    return None
  }
  // Validate every body char is a hex digit. BigInt::from_string aborts on
  // bad input, so we cannot defer this check.
  for i = 2; i < n; i = i + 1 {
    let c = chars[i]
    if !is_hex_char(c) {
      return None
    }
  }
  let body = String::from_array(chars[2:n].to_array())
  Some(@bigint.BigInt::from_string(body, radix=16))
}

///|
/// Read a JSON-RPC "Data" hex string (e.g. "0xdeadbeef") into Bytes.
/// Even-digit body required; "0x" returns empty bytes.
/// Returns `None` on type/format error.
pub fn parse_hex_bytes(json : Json) -> Bytes? {
  let s = match json {
    String(s) => s
    _ => return None
  }
  match @hex.decode(s) {
    Ok(b) => Some(b)
    Err(_) => None
  }
}

///|
fn is_hex_char(c : Char) -> Bool {
  let code = c.to_int()
  (code >= 0x30 && code <= 0x39) || // 0-9
  (code >= 0x61 && code <= 0x66) || // a-f
  (code >= 0x41 && code <= 0x46) // A-F
}

// ---------- Ethereum hex encoding ----------

///|
/// Encode bytes as JSON-RPC "Data": `"0x"` + lowercase hex, leading zeros
/// preserved. Empty bytes => `"0x"`.
fn encode_data(b : Bytes) -> String {
  @hex.encode(b)
}

///|
/// Encode bytes as a JSON-RPC "Quantity" string: `"0x"` + lowercase hex
/// with no leading zeros, except `"0x0"` for zero.
/// Caller passes the big-endian byte representation; this just strips
/// leading zero nibbles.
fn encode_quantity_from_bytes(b : Bytes) -> String {
  // Convert via BigInt to drop leading-zero nibbles (a stripped byte may
  // still have a leading zero nibble, e.g. 0x0a).
  if b.length() == 0 {
    return "0x0"
  }
  let n = @bigint.BigInt::from_octets(b)
  if n.is_zero() {
    "0x0"
  } else {
    "0x" + n.to_string(radix=16)
  }
}

// ---------- request convenience constructors ----------
//
// All convenience constructors return a Request with id=0 as a placeholder.
// Callers should override `id` (e.g. via a counter) before sending.

///|
/// `eth_getBalance(address, block_tag)`.
/// `address` must be 20 bytes (not validated here).
pub fn eth_get_balance(address : Bytes, block_tag : String) -> Request {
  {
    id: 0,
    method: "eth_getBalance",
    params: [Json::string(encode_data(address)), Json::string(block_tag)],
  }
}

///|
/// `eth_blockNumber()` — current block height.
pub fn eth_block_number() -> Request {
  { id: 0, method: "eth_blockNumber", params: [] }
}

///|
/// `eth_chainId()`.
pub fn eth_chain_id() -> Request {
  { id: 0, method: "eth_chainId", params: [] }
}

///|
/// `eth_getTransactionCount(address, block_tag)` — used as nonce source.
pub fn eth_get_transaction_count(
  address : Bytes,
  block_tag : String,
) -> Request {
  {
    id: 0,
    method: "eth_getTransactionCount",
    params: [Json::string(encode_data(address)), Json::string(block_tag)],
  }
}

///|
/// `eth_sendRawTransaction(raw)` — broadcast an RLP-encoded signed tx.
pub fn eth_send_raw_transaction(raw : Bytes) -> Request {
  {
    id: 0,
    method: "eth_sendRawTransaction",
    params: [Json::string(encode_data(raw))],
  }
}

///|
/// `eth_call({to, data}, block_tag)` — read-only contract call.
pub fn eth_call(to : Bytes, data : Bytes, block_tag : String) -> Request {
  let call_obj : Map[String, Json] = {
    "to": Json::string(encode_data(to)),
    "data": Json::string(encode_data(data)),
  }
  {
    id: 0,
    method: "eth_call",
    params: [Json::object(call_obj), Json::string(block_tag)],
  }
}

///|
/// `eth_getTransactionByHash(hash)`.
pub fn eth_get_transaction_by_hash(hash : Bytes) -> Request {
  {
    id: 0,
    method: "eth_getTransactionByHash",
    params: [Json::string(encode_data(hash))],
  }
}

// ---------- internal helpers exposed for symmetry ----------

///|
/// Encode bytes as a Quantity hex string. Public helper for callers that
/// need to build their own RPC params (e.g. for methods not in the
/// convenience list).
pub fn quantity_from_bytes(b : Bytes) -> String {
  encode_quantity_from_bytes(b)
}

///|
/// Encode bytes as a Data hex string. Wrapper around `@hex.encode` for
/// API symmetry with `quantity_from_bytes`.
pub fn data_from_bytes(b : Bytes) -> String {
  encode_data(b)
}
