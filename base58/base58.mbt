// Base58 and Base58Check encoding (Bitcoin alphabet).
//
// Base58 is positional base-58 with a fixed 58-character alphabet. The leading
// zero bytes of the payload are encoded directly as the digit '1' (one '1' per
// leading 0x00 byte), so decode/encode preserves total byte length on inputs
// that start with zeros.
//
// Base58Check appends a 4-byte checksum (sha256(sha256(payload))[:4]) before
// base58-encoding so that mistyped strings can be rejected on decode.

///|
const ALPHABET : String =
  "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

///|
pub(all) suberror DecodeError {
  // Index in the input string where a non-alphabet character appeared.
  InvalidChar(Int)
  // Base58Check checksum did not match (or input shorter than 4 bytes).
  InvalidChecksum
  // Empty input.
  Empty
} derive(Eq)

///|
pub impl Show for DecodeError with output(self, logger) {
  match self {
    InvalidChar(i) => {
      logger.write_string("InvalidChar(")
      logger.write_object(i)
      logger.write_char(')')
    }
    InvalidChecksum => logger.write_string("InvalidChecksum")
    Empty => logger.write_string("Empty")
  }
}

///|
/// Plain Base58 encode. No checksum is appended — callers who want
/// Base58Check should use `encode_check` instead.
pub fn encode(payload : Bytes) -> String {
  let n = payload.length()
  // Count leading zero bytes; each becomes a '1' in the output.
  let mut zeros = 0
  while zeros < n && payload[zeros] == b'\x00' {
    zeros = zeros + 1
  }
  // All-zero payload (or empty): the result is just `zeros` copies of '1'.
  if zeros == n {
    let buf : Array[Char] = Array::make(zeros, '1')
    return String::from_array(buf[:])
  }
  // Treat the non-zero remainder as a big-endian integer and convert to base 58.
  let nonzero = @bytesx.slice(payload, zeros, n)
  let mut acc = @bigint.BigInt::from_octets(nonzero)
  let fifty_eight = @bigint.BigInt::from_int(58)
  let alphabet_chars = ALPHABET.iter().to_array()
  let digits : Array[Char] = Array::new()
  while !acc.is_zero() {
    let rem = acc % fifty_eight
    acc = acc / fifty_eight
    digits.push(alphabet_chars[rem.to_int()])
  }
  // digits is currently least-significant first; reverse and prefix with the
  // leading '1's.
  let total_len = zeros + digits.length()
  let out : Array[Char] = Array::make(total_len, '1')
  let d_len = digits.length()
  for i = 0; i < d_len; i = i + 1 {
    out[zeros + i] = digits[d_len - 1 - i]
  }
  String::from_array(out[:])
}

///|
/// Plain Base58 decode. Inverse of `encode` — does NOT verify a checksum.
pub fn decode(s : String) -> Result[Bytes, DecodeError] {
  let chars = s.iter().to_array()
  let total = chars.length()
  if total == 0 {
    return Err(Empty)
  }
  // Map each input char to its 0..58 alphabet index, surfacing bad chars.
  let alphabet_chars = ALPHABET.iter().to_array()
  let indices : Array[Int] = Array::make(total, 0)
  for i = 0; i < total; i = i + 1 {
    let c = chars[i]
    let mut idx = -1
    for j = 0; j < 58; j = j + 1 {
      if alphabet_chars[j] == c {
        idx = j
        break
      }
    }
    if idx < 0 {
      return Err(InvalidChar(i))
    }
    indices[i] = idx
  }
  // Leading '1's (= alphabet index 0) become leading 0x00 bytes in output.
  let mut zeros = 0
  while zeros < total && indices[zeros] == 0 {
    zeros = zeros + 1
  }
  if zeros == total {
    // Input is all '1's — output is `zeros` zero bytes.
    let out : Array[Byte] = Array::make(zeros, b'\x00')
    return Ok(Bytes::from_array(out[:]))
  }
  // Accumulate the remaining digits as a big integer.
  let mut acc = @bigint.BigInt::from_int(0)
  let fifty_eight = @bigint.BigInt::from_int(58)
  for i = zeros; i < total; i = i + 1 {
    acc = acc * fifty_eight + @bigint.BigInt::from_int(indices[i])
  }
  // acc cannot be zero here (we exited the all-'1' branch above and there is
  // at least one non-zero digit), so to_octets() returns a tight big-endian
  // representation with no leading zero bytes.
  let body = acc.to_octets()
  if zeros == 0 {
    Ok(body)
  } else {
    let prefix : Array[Byte] = Array::make(zeros, b'\x00')
    Ok(@bytesx.concat([Bytes::from_array(prefix[:]), body]))
  }
}

///|
/// Base58Check encode: appends `sha256(sha256(payload))[:4]` to `payload`,
/// then Base58-encodes the result.
pub fn encode_check(payload : Bytes) -> String {
  let checksum = compute_checksum(payload)
  encode(@bytesx.concat([payload, checksum]))
}

///|
/// Base58Check decode: Base58-decodes `s`, splits off the trailing 4-byte
/// checksum, and verifies it. On success returns the payload (without the
/// checksum bytes).
pub fn decode_check(s : String) -> Result[Bytes, DecodeError] {
  let bytes = match decode(s) {
    Ok(b) => b
    Err(e) => return Err(e)
  }
  let n = bytes.length()
  if n < 4 {
    return Err(InvalidChecksum)
  }
  let payload = @bytesx.slice(bytes, 0, n - 4)
  let given = @bytesx.slice(bytes, n - 4, n)
  let expected = compute_checksum(payload)
  // Compare the two 4-byte checksums.
  for i = 0; i < 4; i = i + 1 {
    if given[i] != expected[i] {
      return Err(InvalidChecksum)
    }
  }
  Ok(payload)
}

///|
/// 4-byte Base58Check checksum: first 4 bytes of sha256(sha256(payload)).
fn compute_checksum(payload : Bytes) -> Bytes {
  let h = @sha256.sha256(@sha256.sha256(payload))
  @bytesx.slice(h, 0, 4)
}
