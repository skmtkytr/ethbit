// Base64 encode/decode (RFC 4648 §4) — standard alphabet with `=` padding.
// Private to this package: only used for the WebSocket handshake's
// Sec-WebSocket-Key and Sec-WebSocket-Accept. The project's general-purpose
// binary→text encoding is hex; we deliberately don't expose base64 outside
// this package.

let base64_alphabet : String =
  #|ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/

///|
/// Encode `b` as base64 with standard alphabet and `=` padding.
fn base64_encode(b : Bytes) -> String {
  let alphabet = base64_alphabet.iter().to_array()
  let n = b.length()
  if n == 0 {
    return ""
  }
  // Output length: ceil(n / 3) * 4.
  let groups = (n + 2) / 3
  let out_len = groups * 4
  let out : Array[Char] = Array::make(out_len, '=')
  let mut i = 0
  let mut o = 0
  while i + 3 <= n {
    let b0 = b[i].to_int()
    let b1 = b[i + 1].to_int()
    let b2 = b[i + 2].to_int()
    out[o] = alphabet[(b0 >> 2) & 0x3F]
    out[o + 1] = alphabet[((b0 << 4) | (b1 >> 4)) & 0x3F]
    out[o + 2] = alphabet[((b1 << 2) | (b2 >> 6)) & 0x3F]
    out[o + 3] = alphabet[b2 & 0x3F]
    i = i + 3
    o = o + 4
  }
  let rem = n - i
  if rem == 1 {
    let b0 = b[i].to_int()
    out[o] = alphabet[(b0 >> 2) & 0x3F]
    out[o + 1] = alphabet[(b0 << 4) & 0x3F]
    // out[o+2] and out[o+3] stay '='
  } else if rem == 2 {
    let b0 = b[i].to_int()
    let b1 = b[i + 1].to_int()
    out[o] = alphabet[(b0 >> 2) & 0x3F]
    out[o + 1] = alphabet[((b0 << 4) | (b1 >> 4)) & 0x3F]
    out[o + 2] = alphabet[(b1 << 2) & 0x3F]
    // out[o+3] stays '='
  }
  String::from_array(out)
}

fn base64_char_to_value(c : Char) -> Int? {
  let code = c.to_int()
  if code >= 0x41 && code <= 0x5A {
    Some(code - 0x41) // A-Z -> 0..25
  } else if code >= 0x61 && code <= 0x7A {
    Some(code - 0x61 + 26) // a-z -> 26..51
  } else if code >= 0x30 && code <= 0x39 {
    Some(code - 0x30 + 52) // 0-9 -> 52..61
  } else if code == 0x2B {
    Some(62) // +
  } else if code == 0x2F {
    Some(63) // /
  } else {
    None
  }
}

///|
/// Decode a base64 string with standard alphabet and `=` padding.
/// Returns `None` if:
///   - length is not a multiple of 4
///   - any non-alphabet, non-`=` character appears
///   - `=` appears at a position other than the last 1 or 2 chars
///
/// Currently used only by the test suite (handshake validation only needs
/// `base64_encode`); kept here for round-trip testing and future use.
#warnings("-unused_value")
fn base64_decode(s : String) -> Bytes? {
  let chars = s.iter().to_array()
  let n = chars.length()
  if n == 0 {
    return Some(b"")
  }
  if n % 4 != 0 {
    return None
  }
  // Count trailing '=' (0, 1, or 2).
  let mut pad = 0
  if chars[n - 1] == '=' {
    pad = 1
    if chars[n - 2] == '=' {
      pad = 2
    }
  }
  // No '=' allowed before that.
  for i = 0; i < n - pad; i = i + 1 {
    if chars[i] == '=' {
      return None
    }
  }
  // Output length: 3 bytes per 4-char group, minus padding.
  let groups = n / 4
  let out_len = groups * 3 - pad
  let out : Array[Byte] = Array::make(out_len, b'\x00')
  let mut i = 0
  let mut o = 0
  while i + 4 <= n {
    let last_group = i + 4 == n
    let v0 = match base64_char_to_value(chars[i]) {
      Some(v) => v
      None => return None
    }
    let v1 = match base64_char_to_value(chars[i + 1]) {
      Some(v) => v
      None => return None
    }
    if last_group && pad == 2 {
      // chars[i+2] and chars[i+3] are '='. Output 1 byte.
      out[o] = ((v0 << 2) | (v1 >> 4)).to_byte()
      o = o + 1
    } else {
      let v2 = match base64_char_to_value(chars[i + 2]) {
        Some(v) => v
        None => return None
      }
      if last_group && pad == 1 {
        out[o] = ((v0 << 2) | (v1 >> 4)).to_byte()
        out[o + 1] = (((v1 << 4) | (v2 >> 2)) & 0xFF).to_byte()
        o = o + 2
      } else {
        let v3 = match base64_char_to_value(chars[i + 3]) {
          Some(v) => v
          None => return None
        }
        out[o] = ((v0 << 2) | (v1 >> 4)).to_byte()
        out[o + 1] = (((v1 << 4) | (v2 >> 2)) & 0xFF).to_byte()
        out[o + 2] = (((v2 << 6) | v3) & 0xFF).to_byte()
        o = o + 3
      }
    }
    i = i + 4
  }
  Some(Bytes::from_array(out[:]))
}
