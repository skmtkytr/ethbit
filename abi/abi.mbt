// Solidity ABI encoding / decoding.
// Spec: https://docs.soliditylang.org/en/latest/abi-spec.html
//
// Supported types: uint{8..256}, address, bool, bytes{1..32}, bytes (dynamic),
// string, T[] (dynamic array), and tuple. (int, fixed-size arrays not in v0.)

///|
pub(all) enum AbiType {
  TUint(Int) // bits in 8..256, multiples of 8
  TAddress
  TBool
  TFixedBytes(Int) // 1..32
  TBytes
  TString
  TArray(AbiType) // T[] dynamic
  TTuple(Array[AbiType])
} derive(Eq)

///|
pub(all) enum AbiValue {
  VUint(Int, Bytes) // (bits, big-endian payload, length <= bits/8)
  VAddress(Bytes) // exactly 20 bytes
  VBool(Bool)
  VFixedBytes(Int, Bytes) // (n in 1..32, payload exactly n bytes)
  VBytes(Bytes)
  VString(String)
  VArray(AbiType, Array[AbiValue]) // element type kept for empty arrays
  VTuple(Array[AbiValue])
} derive(Eq)

///|
pub(all) suberror DecodeError {
  Truncated(Int) // offset where read failed
  InvalidBool(Byte)
  NonZeroAddressPad
  InvalidUtf8
  ArrayLengthTooLarge(Int)
} derive(Eq)

///|
pub impl Show for DecodeError with output(self, logger) {
  match self {
    Truncated(o) => {
      logger.write_string("Truncated(")
      logger.write_object(o)
      logger.write_char(')')
    }
    InvalidBool(b) => {
      logger.write_string("InvalidBool(")
      logger.write_object(b)
      logger.write_char(')')
    }
    NonZeroAddressPad => logger.write_string("NonZeroAddressPad")
    InvalidUtf8 => logger.write_string("InvalidUtf8")
    ArrayLengthTooLarge(n) => {
      logger.write_string("ArrayLengthTooLarge(")
      logger.write_object(n)
      logger.write_char(')')
    }
  }
}

///|
pub impl Show for AbiValue with output(self, logger) {
  match self {
    VUint(b, payload) => {
      logger.write_string("VUint(")
      logger.write_object(b)
      logger.write_string(", 0x")
      for byte in payload {
        logger.write_string(byte.to_hex())
      }
      logger.write_char(')')
    }
    VAddress(b) => {
      logger.write_string("VAddress(0x")
      for byte in b {
        logger.write_string(byte.to_hex())
      }
      logger.write_char(')')
    }
    VBool(b) =>
      if b {
        logger.write_string("VBool(true)")
      } else {
        logger.write_string("VBool(false)")
      }
    VFixedBytes(n, b) => {
      logger.write_string("VFixedBytes(")
      logger.write_object(n)
      logger.write_string(", 0x")
      for byte in b {
        logger.write_string(byte.to_hex())
      }
      logger.write_char(')')
    }
    VBytes(b) => {
      logger.write_string("VBytes(0x")
      for byte in b {
        logger.write_string(byte.to_hex())
      }
      logger.write_char(')')
    }
    VString(s) => {
      logger.write_string("VString(\"")
      logger.write_string(s)
      logger.write_string("\")")
    }
    VArray(_, items) => {
      logger.write_string("VArray[")
      let mut first = true
      for it in items {
        if !first {
          logger.write_string(", ")
        }
        it.output(logger)
        first = false
      }
      logger.write_char(']')
    }
    VTuple(items) => {
      logger.write_string("VTuple(")
      let mut first = true
      for it in items {
        if !first {
          logger.write_string(", ")
        }
        it.output(logger)
        first = false
      }
      logger.write_char(')')
    }
  }
}

// ---------- helpers / constructors ----------

///|
/// Convenience constructor: a uint256 from a UInt64.
pub fn uint256_from_u64(n : UInt64) -> AbiValue {
  VUint(256, @bytesx.from_uint64_be(n))
}

///|
/// Convenience constructor: address from 20 bytes (must be exactly 20 bytes;
/// not validated here — caller's responsibility).
pub fn address(b : Bytes) -> AbiValue {
  VAddress(b)
}

// ---------- predicates ----------

///|
fn is_dynamic(v : AbiValue) -> Bool {
  match v {
    VBytes(_) | VString(_) | VArray(_) => true
    VTuple(items) => {
      for it in items {
        if is_dynamic(it) {
          return true
        }
      }
      false
    }
    _ => false
  }
}

///|
fn is_dynamic_type(t : AbiType) -> Bool {
  match t {
    TBytes | TString | TArray(_) => true
    TTuple(types) => {
      for ty in types {
        if is_dynamic_type(ty) {
          return true
        }
      }
      false
    }
    _ => false
  }
}

///|
fn static_head_size(v : AbiValue) -> Int {
  match v {
    VTuple(items) => {
      let mut n = 0
      for it in items {
        n = n + static_head_size(it)
      }
      n
    }
    _ => 32
  }
}

///|
fn static_head_size_type(t : AbiType) -> Int {
  match t {
    TTuple(types) => {
      let mut n = 0
      for ty in types {
        n = n + static_head_size_type(ty)
      }
      n
    }
    _ => 32
  }
}

// ---------- encode ----------

///|
/// Encode a tuple of values (top-level ABI encoding).
pub fn encode(values : Array[AbiValue]) -> Bytes {
  encode_tuple(values)
}

///|
fn encode_tuple(values : Array[AbiValue]) -> Bytes {
  let n = values.length()
  let tails : Array[Bytes] = Array::make(n, b"")
  let mut total_head = 0
  for i = 0; i < n; i = i + 1 {
    let v = values[i]
    if is_dynamic(v) {
      tails[i] = encode_dynamic_tail(v)
      total_head = total_head + 32
    } else {
      total_head = total_head + static_head_size(v)
    }
  }
  let head_parts : Array[Bytes] = Array::make(n, b"")
  let mut tail_off = total_head
  for i = 0; i < n; i = i + 1 {
    let v = values[i]
    if is_dynamic(v) {
      head_parts[i] = uint256_be_of_int(tail_off)
      tail_off = tail_off + tails[i].length()
    } else {
      head_parts[i] = encode_static(v)
    }
  }
  @bytesx.concat([@bytesx.concat(head_parts), @bytesx.concat(tails)])
}

///|
/// Encode a static value as its inline bytes (32 bytes per primitive).
fn encode_static(v : AbiValue) -> Bytes {
  match v {
    VUint(_, payload) => @bytesx.pad_left(payload, 32, b'\x00')
    VAddress(b) => @bytesx.pad_left(b, 32, b'\x00')
    VBool(true) => @bytesx.pad_left(b"\x01", 32, b'\x00')
    VBool(false) => Bytes::make(32, b'\x00')
    VFixedBytes(_, b) => @bytesx.pad_right(b, 32, b'\x00')
    VTuple(items) => {
      let parts : Array[Bytes] = Array::make(items.length(), b"")
      for i = 0; i < items.length(); i = i + 1 {
        parts[i] = encode_static(items[i])
      }
      @bytesx.concat(parts)
    }
    _ => abort("encode_static called on dynamic value")
  }
}

///|
/// Encode the tail payload of a dynamic value.
fn encode_dynamic_tail(v : AbiValue) -> Bytes {
  match v {
    VBytes(b) => encode_bytes_payload(b)
    VString(s) => encode_bytes_payload(@utf8.encode(s.view()))
    VArray(_, items) => {
      let len_word = uint256_be_of_int(items.length())
      @bytesx.concat([len_word, encode_tuple(items)])
    }
    VTuple(_) => encode_tuple(match v {
      VTuple(xs) => xs
      _ => abort("unreachable")
    })
    _ => abort("encode_dynamic_tail called on static value")
  }
}

///|
fn encode_bytes_payload(b : Bytes) -> Bytes {
  let len = b.length()
  let len_word = uint256_be_of_int(len)
  // pad data right to next 32-byte boundary
  let padded = if len % 32 == 0 {
    b
  } else {
    @bytesx.pad_right(b, ((len / 32) + 1) * 32, b'\x00')
  }
  @bytesx.concat([len_word, padded])
}

///|
fn uint256_be_of_int(n : Int) -> Bytes {
  @bytesx.pad_left(@bytesx.from_uint64_be(n.to_uint64()), 32, b'\x00')
}

// ---------- selector / function call ----------

///|
/// 4-byte function selector = first 4 bytes of keccak256(signature).
/// The signature is the canonical Solidity form, e.g. "transfer(address,uint256)".
pub fn selector(signature : String) -> Bytes {
  let hash = @keccak.keccak256(@utf8.encode(signature.view()))
  @bytesx.slice(hash, 0, 4)
}

///|
/// Encode a function call: 4-byte selector followed by ABI-encoded arguments.
pub fn encode_function_call(
  signature : String,
  args : Array[AbiValue],
) -> Bytes {
  @bytesx.concat([selector(signature), encode(args)])
}

// ---------- decode ----------

///|
/// Decode bytes into a list of values, given the expected types.
pub fn decode(types : Array[AbiType], data : Bytes) -> Result[Array[AbiValue], DecodeError] {
  decode_tuple(types, data, 0)
}

///|
fn decode_tuple(
  types : Array[AbiType],
  data : Bytes,
  base_offset : Int,
) -> Result[Array[AbiValue], DecodeError] {
  let n = types.length()
  let values : Array[AbiValue] = Array::make(n, VBool(false))
  let mut head_pos = base_offset
  for i = 0; i < n; i = i + 1 {
    let t = types[i]
    if is_dynamic_type(t) {
      // Read 32-byte offset (relative to base_offset)
      if head_pos + 32 > data.length() {
        return Err(Truncated(head_pos))
      }
      let off = read_uint256_as_int(data, head_pos)
      let abs_off = base_offset + off
      match decode_value(t, data, abs_off) {
        Err(e) => return Err(e)
        Ok(v) => values[i] = v
      }
      head_pos = head_pos + 32
    } else {
      let size = static_head_size_type(t)
      if head_pos + size > data.length() {
        return Err(Truncated(head_pos))
      }
      match decode_static(t, data, head_pos) {
        Err(e) => return Err(e)
        Ok(v) => values[i] = v
      }
      head_pos = head_pos + size
    }
  }
  Ok(values)
}

///|
fn decode_static(
  t : AbiType,
  data : Bytes,
  offset : Int,
) -> Result[AbiValue, DecodeError] {
  match t {
    TUint(bits) => {
      // Strip leading zeros. Take last bits/8 bytes.
      let byte_count = bits / 8
      let payload = @bytesx.slice(data, offset + 32 - byte_count, offset + 32)
      Ok(VUint(bits, strip_leading_zeros(payload)))
    }
    TAddress => {
      // First 12 bytes of the word should be zero
      for i = 0; i < 12; i = i + 1 {
        if data[offset + i] != b'\x00' {
          return Err(NonZeroAddressPad)
        }
      }
      Ok(VAddress(@bytesx.slice(data, offset + 12, offset + 32)))
    }
    TBool => {
      // Last byte is 0 or 1; preceding 31 bytes should be zero (lenient: just look at last)
      let v = data[offset + 31]
      if v == b'\x00' {
        Ok(VBool(false))
      } else if v == b'\x01' {
        Ok(VBool(true))
      } else {
        Err(InvalidBool(v))
      }
    }
    TFixedBytes(n) => Ok(VFixedBytes(n, @bytesx.slice(data, offset, offset + n)))
    TTuple(types) =>
      match decode_tuple(types, data, offset) {
        Err(e) => Err(e)
        Ok(vs) => Ok(VTuple(vs))
      }
    _ => abort("decode_static called on dynamic type")
  }
}

///|
fn decode_value(
  t : AbiType,
  data : Bytes,
  offset : Int,
) -> Result[AbiValue, DecodeError] {
  match t {
    TBytes => {
      if offset + 32 > data.length() {
        return Err(Truncated(offset))
      }
      let len = read_uint256_as_int(data, offset)
      if offset + 32 + len > data.length() {
        return Err(ArrayLengthTooLarge(len))
      }
      Ok(VBytes(@bytesx.slice(data, offset + 32, offset + 32 + len)))
    }
    TString => {
      if offset + 32 > data.length() {
        return Err(Truncated(offset))
      }
      let len = read_uint256_as_int(data, offset)
      if offset + 32 + len > data.length() {
        return Err(ArrayLengthTooLarge(len))
      }
      let payload = @bytesx.slice(data, offset + 32, offset + 32 + len)
      let s = try @utf8.decode(payload.view()) catch {
        _ => return Err(InvalidUtf8)
      }
      Ok(VString(s))
    }
    TArray(elem) => {
      if offset + 32 > data.length() {
        return Err(Truncated(offset))
      }
      let len = read_uint256_as_int(data, offset)
      let types : Array[AbiType] = Array::make(len, elem)
      match decode_tuple(types, data, offset + 32) {
        Err(e) => Err(e)
        Ok(items) => Ok(VArray(elem, items))
      }
    }
    TTuple(types) =>
      match decode_tuple(types, data, offset) {
        Err(e) => Err(e)
        Ok(items) => Ok(VTuple(items))
      }
    _ =>
      // shouldn't be called on static types
      decode_static(t, data, offset)
  }
}

///|
fn read_uint256_as_int(data : Bytes, offset : Int) -> Int {
  let mut r = 0
  // Only take low 8 bytes — sufficient for any sane offset/length.
  for i = 0; i < 8; i = i + 1 {
    r = (r << 8) | data[offset + 24 + i].to_int()
  }
  r
}

///|
fn strip_leading_zeros(b : Bytes) -> Bytes {
  let n = b.length()
  let mut start = 0
  while start < n && b[start] == b'\x00' {
    start = start + 1
  }
  if start == n {
    b""
  } else {
    @bytesx.slice(b, start, n)
  }
}
