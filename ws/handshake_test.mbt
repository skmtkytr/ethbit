// RFC 6455 §1.3 / §4.2 handshake test vectors.

// "the sample nonce" (16 bytes) is the canonical RFC 6455 example client
// key. base64("the sample nonce") == "dGhlIHNhbXBsZSBub25jZQ==".
let rfc_sample_key : Bytes = b"the sample nonce"

test "expected_accept matches RFC 6455 canonical example" {
  // The expected accept value comes directly from RFC 6455 §1.3 / §4.2.2.
  assert_eq(expected_accept(rfc_sample_key), "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=")
}

test "expected_accept differs for different keys" {
  let other : Bytes = b"another sample!!"
  assert_eq(other.length(), 16)
  let a = expected_accept(rfc_sample_key)
  let b = expected_accept(other)
  // Just confirm SHA-1 propagates the key change.
  if a == b {
    abort("expected different accept for different keys")
  }
}

test "build_handshake_request RFC 6455 example" {
  let req : @ws.HandshakeRequest = {
    host: "server.example.com",
    path: "/chat",
    origin: Some("http://example.com"),
    protocols: ["chat", "superchat"],
    key: rfc_sample_key,
  }
  let s = @ws.build_handshake_request(req)
  // Starts with the request-line.
  if !starts_with(s, "GET /chat HTTP/1.1\r\n") {
    abort("missing request line")
  }
  // Contains the right Host.
  if !contains(s, "Host: server.example.com\r\n") {
    abort("missing Host header")
  }
  // Sec-WebSocket-Key header has base64 of the key.
  if !contains(s, "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n") {
    abort("missing or wrong Sec-WebSocket-Key")
  }
  if !contains(s, "Upgrade: websocket\r\n") {
    abort("missing Upgrade")
  }
  if !contains(s, "Connection: Upgrade\r\n") {
    abort("missing Connection")
  }
  if !contains(s, "Sec-WebSocket-Version: 13\r\n") {
    abort("missing Sec-WebSocket-Version")
  }
  if !contains(s, "Origin: http://example.com\r\n") {
    abort("missing Origin")
  }
  if !contains(s, "Sec-WebSocket-Protocol: chat, superchat\r\n") {
    abort("missing Sec-WebSocket-Protocol")
  }
  // Ends with the blank-line separator.
  if !ends_with(s, "\r\n\r\n") {
    abort("missing terminator")
  }
}

test "build_handshake_request omits optional headers when not provided" {
  let req : @ws.HandshakeRequest = {
    host: "h.example",
    path: "/",
    origin: None,
    protocols: [],
    key: rfc_sample_key,
  }
  let s = @ws.build_handshake_request(req)
  if contains(s, "Origin:") {
    abort("Origin should be absent")
  }
  if contains(s, "Sec-WebSocket-Protocol:") {
    abort("Sec-WebSocket-Protocol should be absent")
  }
}

test "validate_handshake_response: well-formed -> Ok" {
  let response =
    "HTTP/1.1 101 Switching Protocols\r\n" +
    "Upgrade: websocket\r\n" +
    "Connection: Upgrade\r\n" +
    "Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\n" +
    "\r\n"
  match @ws.validate_handshake_response(response, rfc_sample_key) {
    Ok(_) => ()
    Err(e) => {
      let _ = e
      abort("expected Ok")
    }
  }
}

test "validate_handshake_response: status 200 -> NotHttp101" {
  let response =
    "HTTP/1.1 200 OK\r\n" +
    "Upgrade: websocket\r\n" +
    "Connection: Upgrade\r\n" +
    "Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\n" +
    "\r\n"
  match @ws.validate_handshake_response(response, rfc_sample_key) {
    Err(NotHttp101) => ()
    Err(e) => {
      let _ = e
      abort("expected NotHttp101")
    }
    Ok(_) => abort("expected error")
  }
}

test "validate_handshake_response: missing Upgrade -> MissingUpgrade" {
  let response =
    "HTTP/1.1 101 Switching Protocols\r\n" +
    "Connection: Upgrade\r\n" +
    "Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\n" +
    "\r\n"
  match @ws.validate_handshake_response(response, rfc_sample_key) {
    Err(MissingUpgrade) => ()
    Err(e) => {
      let _ = e
      abort("expected MissingUpgrade")
    }
    Ok(_) => abort("expected error")
  }
}

test "validate_handshake_response: missing Connection -> MissingConnectionUpgrade" {
  let response =
    "HTTP/1.1 101 Switching Protocols\r\n" +
    "Upgrade: websocket\r\n" +
    "Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\n" +
    "\r\n"
  match @ws.validate_handshake_response(response, rfc_sample_key) {
    Err(MissingConnectionUpgrade) => ()
    Err(e) => {
      let _ = e
      abort("expected MissingConnectionUpgrade")
    }
    Ok(_) => abort("expected error")
  }
}

test "validate_handshake_response: wrong Accept -> WrongAccept" {
  let response =
    "HTTP/1.1 101 Switching Protocols\r\n" +
    "Upgrade: websocket\r\n" +
    "Connection: Upgrade\r\n" +
    "Sec-WebSocket-Accept: AAAAAAAAAAAAAAAAAAAAAAAAAAA=\r\n" +
    "\r\n"
  match @ws.validate_handshake_response(response, rfc_sample_key) {
    Err(WrongAccept) => ()
    Err(e) => {
      let _ = e
      abort("expected WrongAccept")
    }
    Ok(_) => abort("expected error")
  }
}

test "validate_handshake_response: missing Accept -> WrongAccept" {
  let response =
    "HTTP/1.1 101 Switching Protocols\r\n" +
    "Upgrade: websocket\r\n" +
    "Connection: Upgrade\r\n" +
    "\r\n"
  match @ws.validate_handshake_response(response, rfc_sample_key) {
    Err(WrongAccept) => ()
    Err(e) => {
      let _ = e
      abort("expected WrongAccept")
    }
    Ok(_) => abort("expected error")
  }
}

test "validate_handshake_response: case-insensitive header match" {
  // Real servers may send "upgrade" / "connection" with arbitrary casing,
  // and "Connection: keep-alive, Upgrade" is legal. Verify our matcher is
  // case-insensitive and substring-friendly.
  let response =
    "HTTP/1.1 101 Switching Protocols\r\n" +
    "upgrade: WebSocket\r\n" +
    "Connection: keep-alive, Upgrade\r\n" +
    "Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\n" +
    "\r\n"
  match @ws.validate_handshake_response(response, rfc_sample_key) {
    Ok(_) => ()
    Err(e) => {
      let _ = e
      abort("expected Ok")
    }
  }
}

test "validate_handshake_response: garbage -> Malformed" {
  let response = "not an http response at all\r\n\r\n"
  match @ws.validate_handshake_response(response, rfc_sample_key) {
    Err(Malformed) => ()
    Err(e) => {
      let _ = e
      abort("expected Malformed")
    }
    Ok(_) => abort("expected error")
  }
}

// ---------- helpers ----------

fn starts_with(s : String, prefix : String) -> Bool {
  let sc = s.iter().to_array()
  let pc = prefix.iter().to_array()
  if pc.length() > sc.length() {
    return false
  }
  for i = 0; i < pc.length(); i = i + 1 {
    if sc[i] != pc[i] {
      return false
    }
  }
  true
}

fn ends_with(s : String, suffix : String) -> Bool {
  let sc = s.iter().to_array()
  let xc = suffix.iter().to_array()
  if xc.length() > sc.length() {
    return false
  }
  let off = sc.length() - xc.length()
  for i = 0; i < xc.length(); i = i + 1 {
    if sc[off + i] != xc[i] {
      return false
    }
  }
  true
}

fn contains(haystack : String, needle : String) -> Bool {
  let h = haystack.iter().to_array()
  let n = needle.iter().to_array()
  if n.length() == 0 {
    return true
  }
  if n.length() > h.length() {
    return false
  }
  for i = 0; i <= h.length() - n.length(); i = i + 1 {
    let mut ok = true
    for j = 0; j < n.length(); j = j + 1 {
      if h[i + j] != n[j] {
        ok = false
        break
      }
    }
    if ok {
      return true
    }
  }
  false
}
