// WebSocket opening-handshake helpers (RFC 6455 §4).
//
// The handshake is an HTTP/1.1 Upgrade exchange: the client sends a request
// with a random `Sec-WebSocket-Key`, and the server replies with status 101
// and `Sec-WebSocket-Accept` = base64(sha1(base64(key) || GUID)) where GUID
// is the fixed magic value defined in RFC 6455 §1.3.
//
// We only build the request bytes and validate the response bytes — the
// caller pumps them through whatever HTTP-on-TCP transport they have.
// The 16-byte client key is the caller's responsibility (must come from a
// CSPRNG; this package never generates randomness).

const WS_GUID : String = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

///|
/// The fields needed to build a WebSocket upgrade request.
///
///   - `host`: value for the `Host:` header (e.g. `"server.example.com"` or
///     `"server.example.com:9001"`). The caller must include the port if it
///     is not the scheme default.
///   - `path`: origin-relative request target (e.g. `"/"`, `"/chat"`).
///   - `origin`: optional `Origin:` header. Browsers always send this; CLI
///     clients usually don't.
///   - `protocols`: subprotocols to advertise (`Sec-WebSocket-Protocol`).
///     Empty array means the header is omitted.
///   - `key`: 16 random bytes the caller picks fresh per handshake. Will
///     be base64-encoded for the `Sec-WebSocket-Key` header. Aborts during
///     `build_handshake_request` if length is not 16.
pub(all) struct HandshakeRequest {
  host : String
  path : String
  origin : String?
  protocols : Array[String]
  key : Bytes
}

///|
/// Build the full HTTP/1.1 Upgrade request as a single ASCII string. The
/// caller writes it (as bytes) to the socket. Lines are CRLF-terminated and
/// the body is empty (handshake has no entity).
pub fn build_handshake_request(req : HandshakeRequest) -> String {
  if req.key.length() != 16 {
    abort("build_handshake_request: key must be exactly 16 bytes")
  }
  let key_b64 = base64_encode(req.key)
  let mut s = "GET " + req.path + " HTTP/1.1\r\n"
  s = s + "Host: " + req.host + "\r\n"
  s = s + "Upgrade: websocket\r\n"
  s = s + "Connection: Upgrade\r\n"
  s = s + "Sec-WebSocket-Key: " + key_b64 + "\r\n"
  s = s + "Sec-WebSocket-Version: 13\r\n"
  match req.origin {
    Some(o) => s = s + "Origin: " + o + "\r\n"
    None => ()
  }
  if req.protocols.length() > 0 {
    let mut protos = ""
    for i = 0; i < req.protocols.length(); i = i + 1 {
      if i > 0 {
        protos = protos + ", "
      }
      protos = protos + req.protocols[i]
    }
    s = s + "Sec-WebSocket-Protocol: " + protos + "\r\n"
  }
  s = s + "\r\n"
  s
}

///|
/// Compute the expected `Sec-WebSocket-Accept` value for a given client key.
/// Per RFC 6455 §4.2.2:
///
///   accept = base64(sha1(base64(key) ++ "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
pub fn expected_accept(key : Bytes) -> String {
  let key_b64 = base64_encode(key)
  let concat = key_b64 + WS_GUID
  let bytes = string_to_ascii_bytes(concat)
  base64_encode(sha1(bytes))
}

fn string_to_ascii_bytes(s : String) -> Bytes {
  let chars = s.iter().to_array()
  let n = chars.length()
  let out : Array[Byte] = Array::make(n, b'\x00')
  for i = 0; i < n; i = i + 1 {
    // The strings we hand to this function (base64 alphabet + the GUID) are
    // pure ASCII, so a direct truncation to byte is correct. We mask just in
    // case to stay defensive.
    out[i] = (chars[i].to_int() & 0xFF).to_byte()
  }
  Bytes::from_array(out[:])
}

///|
/// Reasons a server's handshake response is unacceptable.
pub(all) suberror HandshakeError {
  NotHttp101
  MissingUpgrade
  MissingConnectionUpgrade
  WrongAccept
  Malformed
} derive(Eq)

///|
pub impl Show for HandshakeError with output(self, logger) {
  match self {
    NotHttp101 => logger.write_string("NotHttp101")
    MissingUpgrade => logger.write_string("MissingUpgrade")
    MissingConnectionUpgrade => logger.write_string("MissingConnectionUpgrade")
    WrongAccept => logger.write_string("WrongAccept")
    Malformed => logger.write_string("Malformed")
  }
}

///|
/// Validate the server's handshake response head. `response` is the raw
/// bytes (as a String) up to and including the first `\r\n\r\n` separator
/// — the caller can pass exactly that, or the full response with body
/// appended (we ignore everything after the blank line).
///
/// Checks:
///   - status line starts with `"HTTP/1.1 101 "` (or `"HTTP/1.0 101 "`)
///   - `Upgrade` header value contains `websocket` (case-insensitive)
///   - `Connection` header value contains `upgrade` (case-insensitive)
///   - `Sec-WebSocket-Accept` header equals `expected_accept(client_key)`
pub fn validate_handshake_response(
  response : String,
  client_key : Bytes,
) -> Result[Unit, HandshakeError] {
  let lines = split_response_lines(response)
  if lines.length() == 0 {
    return Err(Malformed)
  }
  // Status line.
  let status = lines[0]
  if !status_is_101(status) {
    if !status_starts_with_http(status) {
      return Err(Malformed)
    }
    return Err(NotHttp101)
  }
  // Header parsing: each line "Name: Value". Be permissive on whitespace.
  let mut got_upgrade = false
  let mut got_connection = false
  let mut accept_value : String? = None
  for i = 1; i < lines.length(); i = i + 1 {
    let line = lines[i]
    if line == "" {
      // Blank line is the header/body separator; stop.
      break
    }
    match split_header(line) {
      Some((name, value)) => {
        let lname = ascii_lower(name)
        if lname == "upgrade" {
          if ascii_lower_contains(value, "websocket") {
            got_upgrade = true
          }
        } else if lname == "connection" {
          if ascii_lower_contains(value, "upgrade") {
            got_connection = true
          }
        } else if lname == "sec-websocket-accept" {
          accept_value = Some(strip_ascii(value))
        }
      }
      None => return Err(Malformed)
    }
  }
  if !got_upgrade {
    return Err(MissingUpgrade)
  }
  if !got_connection {
    return Err(MissingConnectionUpgrade)
  }
  let want = expected_accept(client_key)
  match accept_value {
    Some(v) => if v != want { return Err(WrongAccept) }
    None => return Err(WrongAccept)
  }
  Ok(())
}

fn status_starts_with_http(line : String) -> Bool {
  ascii_lower_starts_with(line, "http/")
}

fn status_is_101(line : String) -> Bool {
  // "HTTP/1.1 101 ..." or "HTTP/1.0 101 ...". Be lenient on the version,
  // strict on the code.
  let chars = line.iter().to_array()
  // Need at least "HTTP/1.x 101".
  if chars.length() < 12 {
    return false
  }
  if !ascii_lower_starts_with(line, "http/") {
    return false
  }
  // Find the first space.
  let mut sp = -1
  for i = 0; i < chars.length(); i = i + 1 {
    if chars[i] == ' ' {
      sp = i
      break
    }
  }
  if sp < 0 || sp + 3 >= chars.length() {
    return false
  }
  chars[sp + 1] == '1' && chars[sp + 2] == '0' && chars[sp + 3] == '1'
}

fn split_response_lines(s : String) -> Array[String] {
  // Split on CRLF. Tolerate a final trailing "\r\n\r\n" (we just stop at the
  // first empty line).
  let chars = s.iter().to_array()
  let n = chars.length()
  let lines : Array[String] = []
  let mut start = 0
  let mut i = 0
  while i < n {
    if i + 1 < n && chars[i] == '\r' && chars[i + 1] == '\n' {
      let line_chars = chars[start:i].to_array()
      lines.push(String::from_array(line_chars))
      i = i + 2
      start = i
    } else {
      i = i + 1
    }
  }
  // If there's a trailing partial line (no CRLF), include it as well — it
  // means the input was not properly terminated, which our header loop
  // tolerates as long as the empty-line separator was already seen.
  if start < n {
    let line_chars = chars[start:n].to_array()
    lines.push(String::from_array(line_chars))
  }
  lines
}

fn split_header(line : String) -> (String, String)? {
  let chars = line.iter().to_array()
  let n = chars.length()
  let mut colon = -1
  for i = 0; i < n; i = i + 1 {
    if chars[i] == ':' {
      colon = i
      break
    }
  }
  if colon < 0 {
    return None
  }
  let name = String::from_array(chars[0:colon].to_array())
  let value = String::from_array(chars[colon + 1:n].to_array())
  Some((strip_ascii(name), strip_ascii(value)))
}

fn strip_ascii(s : String) -> String {
  let chars = s.iter().to_array()
  let n = chars.length()
  let mut a = 0
  while a < n && (chars[a] == ' ' || chars[a] == '\t') {
    a = a + 1
  }
  let mut b = n
  while b > a && (chars[b - 1] == ' ' || chars[b - 1] == '\t') {
    b = b - 1
  }
  String::from_array(chars[a:b].to_array())
}

fn ascii_lower(s : String) -> String {
  let chars = s.iter().to_array()
  let n = chars.length()
  let out : Array[Char] = Array::make(n, ' ')
  for i = 0; i < n; i = i + 1 {
    let code = chars[i].to_int()
    out[i] = if code >= 0x41 && code <= 0x5A {
      Int::unsafe_to_char(code + 0x20)
    } else {
      chars[i]
    }
  }
  String::from_array(out)
}

fn ascii_lower_contains(haystack : String, needle_lower : String) -> Bool {
  // needle_lower must already be lowercase ASCII; haystack is normalized
  // here. This is only used internally with literal "websocket" / "upgrade"
  // needles.
  let h = ascii_lower(haystack)
  let hc = h.iter().to_array()
  let nc = needle_lower.iter().to_array()
  let hn = hc.length()
  let nn = nc.length()
  if nn == 0 {
    return true
  }
  if nn > hn {
    return false
  }
  for i = 0; i <= hn - nn; i = i + 1 {
    let mut ok = true
    for j = 0; j < nn; j = j + 1 {
      if hc[i + j] != nc[j] {
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

fn ascii_lower_starts_with(s : String, prefix_lower : String) -> Bool {
  let lc = ascii_lower(s)
  let sc = lc.iter().to_array()
  let pc = prefix_lower.iter().to_array()
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
