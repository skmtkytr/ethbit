// Recursive Length Prefix (RLP) — Ethereum's serialization format.
// Spec: Yellow Paper Appendix B and
// https://ethereum.org/en/developers/docs/data-structures-and-encoding/rlp/
//
// Decoder is strict about canonicality: it rejects encodings that are
// well-formed but not minimal (single byte wrapped with 0x81, leading
// zero in length prefix, long-form length when short form would fit).

///|
pub(all) enum RlpValue {
  RlpString(Bytes)
  RlpList(Array[RlpValue])
} derive(Eq)

///|
pub impl Show for RlpValue with output(self, logger) {
  match self {
    RlpString(b) => {
      logger.write_string("RlpString(0x")
      for byte in b {
        logger.write_string(byte.to_hex())
      }
      logger.write_char(')')
    }
    RlpList(items) => {
      logger.write_string("RlpList[")
      let mut first = true
      for item in items {
        if !first {
          logger.write_string(", ")
        }
        item.output(logger)
        first = false
      }
      logger.write_char(']')
    }
  }
}

///|
pub(all) suberror DecodeError {
  EmptyInput
  TruncatedInput(Int, Int) // expected_end, actual_total
  TrailingBytes(Int) // offset where trailing data begins
  NonCanonicalSingleByte
  NonCanonicalLength
  NonCanonicalLengthLeadingZero
  RecursionTooDeep(Int)
} derive(Eq)

///|
pub impl Show for DecodeError with output(self, logger) {
  match self {
    EmptyInput => logger.write_string("EmptyInput")
    TruncatedInput(want, got) => {
      logger.write_string("TruncatedInput(")
      logger.write_object(want)
      logger.write_string(", ")
      logger.write_object(got)
      logger.write_char(')')
    }
    TrailingBytes(off) => {
      logger.write_string("TrailingBytes(")
      logger.write_object(off)
      logger.write_char(')')
    }
    NonCanonicalSingleByte => logger.write_string("NonCanonicalSingleByte")
    NonCanonicalLength => logger.write_string("NonCanonicalLength")
    NonCanonicalLengthLeadingZero => logger.write_string("NonCanonicalLengthLeadingZero")
    RecursionTooDeep(d) => {
      logger.write_string("RecursionTooDeep(")
      logger.write_object(d)
      logger.write_char(')')
    }
  }
}

const MAX_DEPTH : Int = 256

// ---------- encode ----------

///|
pub fn encode(v : RlpValue) -> Bytes {
  let buf : Array[Byte] = []
  encode_into(v, buf)
  Bytes::from_array(buf[:])
}

///|
fn encode_into(v : RlpValue, buf : Array[Byte]) -> Unit {
  match v {
    RlpString(s) => encode_string(s, buf)
    RlpList(items) => encode_list(items, buf)
  }
}

///|
fn encode_string(s : Bytes, buf : Array[Byte]) -> Unit {
  let len = s.length()
  if len == 1 && s[0].to_int() < 0x80 {
    buf.push(s[0])
  } else if len <= 55 {
    buf.push((0x80 + len).to_byte())
    for i = 0; i < len; i = i + 1 {
      buf.push(s[i])
    }
  } else {
    let len_bytes = encode_length_be(len)
    buf.push((0xb7 + len_bytes.length()).to_byte())
    for b in len_bytes {
      buf.push(b)
    }
    for i = 0; i < len; i = i + 1 {
      buf.push(s[i])
    }
  }
}

///|
fn encode_list(items : Array[RlpValue], buf : Array[Byte]) -> Unit {
  // Encode payload first to learn its length.
  let payload : Array[Byte] = []
  for item in items {
    encode_into(item, payload)
  }
  let len = payload.length()
  if len <= 55 {
    buf.push((0xc0 + len).to_byte())
  } else {
    let len_bytes = encode_length_be(len)
    buf.push((0xf7 + len_bytes.length()).to_byte())
    for b in len_bytes {
      buf.push(b)
    }
  }
  for b in payload {
    buf.push(b)
  }
}

///|
fn encode_length_be(n : Int) -> Array[Byte] {
  // Big-endian encoding of a positive integer with no leading zeros.
  let mut byte_count = 0
  let mut tmp = n
  while tmp > 0 {
    byte_count = byte_count + 1
    tmp = tmp >> 8
  }
  let result : Array[Byte] = Array::make(byte_count, b'\x00')
  for i = 0; i < byte_count; i = i + 1 {
    result[byte_count - 1 - i] = ((n >> (i * 8)) & 0xff).to_byte()
  }
  result
}

// ---------- decode ----------

///|
pub fn decode(bytes : Bytes) -> Result[RlpValue, DecodeError] {
  if bytes.length() == 0 {
    return Err(EmptyInput)
  }
  match decode_at(bytes, 0, 0) {
    Err(e) => Err(e)
    Ok((value, consumed)) =>
      if consumed != bytes.length() {
        Err(TrailingBytes(consumed))
      } else {
        Ok(value)
      }
  }
}

///|
fn decode_at(
  bytes : Bytes,
  offset : Int,
  depth : Int,
) -> Result[(RlpValue, Int), DecodeError] {
  if depth > MAX_DEPTH {
    return Err(RecursionTooDeep(depth))
  }
  if offset >= bytes.length() {
    return Err(TruncatedInput(offset + 1, bytes.length()))
  }
  let prefix = bytes[offset].to_int()
  if prefix < 0x80 {
    // single byte string
    Ok((RlpString(slice(bytes, offset, offset + 1)), offset + 1))
  } else if prefix < 0xb8 {
    // short string, payload length 0..55
    let len = prefix - 0x80
    let start = offset + 1
    let end = start + len
    if end > bytes.length() {
      return Err(TruncatedInput(end, bytes.length()))
    }
    if len == 1 && bytes[start].to_int() < 0x80 {
      return Err(NonCanonicalSingleByte)
    }
    Ok((RlpString(slice(bytes, start, end)), end))
  } else if prefix < 0xc0 {
    // long string, payload length is itself encoded in (prefix - 0xb7) bytes
    let len_of_len = prefix - 0xb7
    let len_start = offset + 1
    let len_end = len_start + len_of_len
    if len_end > bytes.length() {
      return Err(TruncatedInput(len_end, bytes.length()))
    }
    if bytes[len_start].to_int() == 0 {
      return Err(NonCanonicalLengthLeadingZero)
    }
    let payload_len = decode_length_be(bytes, len_start, len_of_len)
    if payload_len <= 55 {
      return Err(NonCanonicalLength)
    }
    let end = len_end + payload_len
    if end > bytes.length() {
      return Err(TruncatedInput(end, bytes.length()))
    }
    Ok((RlpString(slice(bytes, len_end, end)), end))
  } else if prefix < 0xf8 {
    // short list, payload length 0..55
    let payload_len = prefix - 0xc0
    let start = offset + 1
    let end = start + payload_len
    if end > bytes.length() {
      return Err(TruncatedInput(end, bytes.length()))
    }
    match decode_list_items(bytes, start, end, depth + 1) {
      Err(e) => Err(e)
      Ok(items) => Ok((RlpList(items), end))
    }
  } else {
    // long list
    let len_of_len = prefix - 0xf7
    let len_start = offset + 1
    let len_end = len_start + len_of_len
    if len_end > bytes.length() {
      return Err(TruncatedInput(len_end, bytes.length()))
    }
    if bytes[len_start].to_int() == 0 {
      return Err(NonCanonicalLengthLeadingZero)
    }
    let payload_len = decode_length_be(bytes, len_start, len_of_len)
    if payload_len <= 55 {
      return Err(NonCanonicalLength)
    }
    let end = len_end + payload_len
    if end > bytes.length() {
      return Err(TruncatedInput(end, bytes.length()))
    }
    match decode_list_items(bytes, len_end, end, depth + 1) {
      Err(e) => Err(e)
      Ok(items) => Ok((RlpList(items), end))
    }
  }
}

///|
fn decode_list_items(
  bytes : Bytes,
  start : Int,
  end : Int,
  depth : Int,
) -> Result[Array[RlpValue], DecodeError] {
  let items : Array[RlpValue] = []
  let mut offset = start
  while offset < end {
    match decode_at(bytes, offset, depth) {
      Err(e) => return Err(e)
      Ok((item, next)) => {
        items.push(item)
        offset = next
      }
    }
  }
  // offset should equal end exactly; if we overshoot, the inner item
  // exceeded the declared list payload length.
  if offset != end {
    return Err(TruncatedInput(end, offset))
  }
  Ok(items)
}

///|
fn decode_length_be(bytes : Bytes, offset : Int, len : Int) -> Int {
  let mut result = 0
  for i = 0; i < len; i = i + 1 {
    result = (result << 8) | bytes[offset + i].to_int()
  }
  result
}

///|
fn slice(bytes : Bytes, start : Int, end : Int) -> Bytes {
  let n = end - start
  let arr : Array[Byte] = Array::make(n, b'\x00')
  for i = 0; i < n; i = i + 1 {
    arr[i] = bytes[start + i]
  }
  Bytes::from_array(arr[:])
}
