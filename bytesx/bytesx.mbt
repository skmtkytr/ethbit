// Small Bytes helpers used by RLP, ABI, and tx packages.
// Kept minimal — only operations that are exercised in multiple packages.

///|
pub fn concat(parts : Array[Bytes]) -> Bytes {
  let mut total = 0
  for p in parts {
    total = total + p.length()
  }
  let out : Array[Byte] = Array::make(total, b'\x00')
  let mut pos = 0
  for p in parts {
    let n = p.length()
    for i = 0; i < n; i = i + 1 {
      out[pos + i] = p[i]
    }
    pos = pos + n
  }
  Bytes::from_array(out[:])
}

///|
pub fn slice(b : Bytes, start : Int, end : Int) -> Bytes {
  let n = end - start
  let out : Array[Byte] = Array::make(n, b'\x00')
  for i = 0; i < n; i = i + 1 {
    out[i] = b[start + i]
  }
  Bytes::from_array(out[:])
}

///|
/// Left-pad `b` with `fill` until it reaches `target_len`. If `b` is already
/// at least that long, returns `b` as-is (no truncation).
pub fn pad_left(b : Bytes, target_len : Int, fill : Byte) -> Bytes {
  let n = b.length()
  if n >= target_len {
    return b
  }
  let out : Array[Byte] = Array::make(target_len, fill)
  let pad = target_len - n
  for i = 0; i < n; i = i + 1 {
    out[pad + i] = b[i]
  }
  Bytes::from_array(out[:])
}

///|
pub fn pad_right(b : Bytes, target_len : Int, fill : Byte) -> Bytes {
  let n = b.length()
  if n >= target_len {
    return b
  }
  let out : Array[Byte] = Array::make(target_len, fill)
  for i = 0; i < n; i = i + 1 {
    out[i] = b[i]
  }
  Bytes::from_array(out[:])
}

///|
/// Big-endian byte representation of a UInt64 with no leading zeros.
/// 0 maps to the empty Bytes (matches RLP integer convention).
pub fn from_uint64_be(n : UInt64) -> Bytes {
  if n == 0UL {
    return b""
  }
  let mut byte_count = 0
  let mut tmp = n
  while tmp > 0UL {
    byte_count = byte_count + 1
    tmp = tmp >> 8
  }
  let out : Array[Byte] = Array::make(byte_count, b'\x00')
  for i = 0; i < byte_count; i = i + 1 {
    out[byte_count - 1 - i] = (n >> (i * 8)).to_byte()
  }
  Bytes::from_array(out[:])
}
