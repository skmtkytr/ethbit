///|
pub(all) suberror DecodeError {
  OddLength(Int)
  InvalidChar(Char, Int)
} derive(Eq)

///|
pub impl Show for DecodeError with output(self, logger) {
  match self {
    OddLength(n) => {
      logger.write_string("OddLength(")
      logger.write_object(n)
      logger.write_char(')')
    }
    InvalidChar(c, pos) => {
      logger.write_string("InvalidChar(")
      logger.write_char('\'')
      logger.write_char(c)
      logger.write_string("', ")
      logger.write_object(pos)
      logger.write_char(')')
    }
  }
}

///|
pub fn encode(bytes : Bytes) -> String {
  let mut s = "0x"
  for b in bytes {
    s = s + b.to_hex()
  }
  s
}

///|
pub fn decode(s : String) -> Result[Bytes, DecodeError] {
  let chars = s.iter().to_array()
  let total = chars.length()
  let start = if total >= 2 && chars[0] == '0' && (chars[1] == 'x' || chars[1] == 'X') {
    2
  } else {
    0
  }
  let body_len = total - start
  if body_len % 2 != 0 {
    return Err(OddLength(body_len))
  }
  let out_len = body_len / 2
  let out : Array[Byte] = Array::make(out_len, b'\x00')
  let mut i = 0
  while i < body_len {
    let c_hi = chars[start + i]
    let c_lo = chars[start + i + 1]
    let hi = char_to_nibble(c_hi)
    let lo = char_to_nibble(c_lo)
    match (hi, lo) {
      (Some(h), Some(l)) => out[i / 2] = ((h << 4) | l).to_byte()
      (None, _) => return Err(InvalidChar(c_hi, i))
      (_, None) => return Err(InvalidChar(c_lo, i + 1))
    }
    i = i + 2
  }
  Ok(Bytes::from_array(out[:]))
}

///|
fn char_to_nibble(c : Char) -> Int? {
  let code = c.to_int()
  if code >= 0x30 && code <= 0x39 {
    Some(code - 0x30)
  } else if code >= 0x61 && code <= 0x66 {
    Some(code - 0x61 + 10)
  } else if code >= 0x41 && code <= 0x46 {
    Some(code - 0x41 + 10)
  } else {
    None
  }
}
