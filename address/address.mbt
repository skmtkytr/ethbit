// EIP-55 mixed-case checksum address encoding.
// Spec: https://eips.ethereum.org/EIPS/eip-55
//
// Algorithm: hash the lowercase ASCII hex representation of the 20-byte
// address with keccak256; for each hex digit position i, uppercase the
// character if it is in [a-f] AND the i-th nibble of the hash is >= 8.

///|
pub(all) suberror AddressError {
  InvalidLength(Int)
} derive(Eq)

///|
pub impl Show for AddressError with output(self, logger) {
  match self {
    InvalidLength(n) => {
      logger.write_string("InvalidLength(")
      logger.write_object(n)
      logger.write_char(')')
    }
  }
}

///|
pub fn to_checksum(addr : Bytes) -> Result[String, AddressError] {
  if addr.length() != 20 {
    return Err(InvalidLength(addr.length()))
  }
  // Lowercase ASCII hex (40 chars) of the 20 input bytes.
  // This is both the input to keccak256 (per EIP-55) and the case-template
  // for the output.
  let hex_bytes : Array[Byte] = Array::make(40, b'0')
  for i = 0; i < 20; i = i + 1 {
    let v = addr[i].to_int()
    hex_bytes[i * 2] = nibble_to_lower_hex_byte((v >> 4) & 0xf)
    hex_bytes[i * 2 + 1] = nibble_to_lower_hex_byte(v & 0xf)
  }
  let hash = @keccak.keccak256(Bytes::from_array(hex_bytes[:]))
  let chars : Array[Char] = Array::make(42, '0')
  chars[0] = '0'
  chars[1] = 'x'
  for i = 0; i < 40; i = i + 1 {
    let c = hex_bytes[i]
    let hash_byte = hash[i / 2].to_int()
    let nibble = if i % 2 == 0 {
      (hash_byte >> 4) & 0xf
    } else {
      hash_byte & 0xf
    }
    let final_byte = if c >= b'a' && c <= b'f' && nibble >= 8 {
      (c.to_int() - 0x20).to_byte() // ASCII uppercase
    } else {
      c
    }
    chars[i + 2] = final_byte.to_char()
  }
  Ok(String::from_array(chars[:]))
}

///|
/// Returns true iff the input is exactly a 0x-prefixed 40-hex-char address
/// AND the case of the hex digits matches the EIP-55 checksum.
///
/// All-lowercase and all-uppercase hex are NOT considered valid checksums
/// (they are valid Ethereum addresses but skip the EIP-55 typo guard).
pub fn is_valid_checksum(addr : String) -> Bool {
  let chars = addr.iter().to_array()
  if chars.length() != 42 {
    return false
  }
  if chars[0] != '0' || chars[1] != 'x' {
    return false
  }
  let bytes = match @hex.decode(addr) {
    Ok(b) => b
    Err(_) => return false
  }
  if bytes.length() != 20 {
    return false
  }
  match to_checksum(bytes) {
    Ok(expected) => expected == addr
    Err(_) => false
  }
}

///|
fn nibble_to_lower_hex_byte(n : Int) -> Byte {
  if n < 10 {
    (n + 0x30).to_byte() // '0'..'9'
  } else {
    (n + 0x57).to_byte() // 'a'..'f'
  }
}
