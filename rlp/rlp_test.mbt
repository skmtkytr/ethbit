// Test vectors are drawn from ethereum/tests RLPTests/rlptest.json
// (https://github.com/ethereum/tests/blob/develop/RLPTests/rlptest.json)
// and the canonical examples in the Yellow Paper Appendix B / the RLP wiki
// page (https://ethereum.org/en/developers/docs/data-structures-and-encoding/rlp/).

fn s(b : Bytes) -> @rlp.RlpValue {
  @rlp.RlpString(b)
}

fn l(items : Array[@rlp.RlpValue]) -> @rlp.RlpValue {
  @rlp.RlpList(items)
}

// ---------- encode ----------

test "encode: empty string -> 0x80" {
  assert_eq(@rlp.encode(s(b"")), b"\x80")
}

test "encode: empty list -> 0xc0" {
  assert_eq(@rlp.encode(l([])), b"\xc0")
}

test "encode: single byte 0x00 -> 0x00" {
  assert_eq(@rlp.encode(s(b"\x00")), b"\x00")
}

test "encode: single byte 0x01 -> 0x01" {
  assert_eq(@rlp.encode(s(b"\x01")), b"\x01")
}

test "encode: single byte 0x7f -> 0x7f" {
  assert_eq(@rlp.encode(s(b"\x7f")), b"\x7f")
}

test "encode: single byte 0x80 -> 0x81 0x80 (must wrap)" {
  assert_eq(@rlp.encode(s(b"\x80")), b"\x81\x80")
}

test "encode: single byte 0xff -> 0x81 0xff" {
  assert_eq(@rlp.encode(s(b"\xff")), b"\x81\xff")
}

test "encode: \"dog\" -> 0x83 d o g" {
  assert_eq(@rlp.encode(s(b"dog")), b"\x83\x64\x6f\x67")
}

test "encode: 55-byte string (last short-string length)" {
  // "Lorem ipsum dolor sit amet, consectetur adipisicing eli" is 55 chars.
  let payload = b"Lorem ipsum dolor sit amet, consectetur adipisicing eli"
  let encoded = @rlp.encode(s(payload))
  assert_eq(encoded.length(), 56)
  assert_eq(encoded[0], b'\xb7') // 0x80 + 55
  for i = 0; i < 55; i = i + 1 {
    assert_eq(encoded[i + 1], payload[i])
  }
}

test "encode: 56-byte string (first long-string length)" {
  let payload = b"Lorem ipsum dolor sit amet, consectetur adipisicing elit"
  let encoded = @rlp.encode(s(payload))
  // prefix = 0xb7 + 1 = 0xb8, length-byte = 0x38 = 56
  assert_eq(encoded.length(), 58)
  assert_eq(encoded[0], b'\xb8')
  assert_eq(encoded[1], b'\x38')
  for i = 0; i < 56; i = i + 1 {
    assert_eq(encoded[i + 2], payload[i])
  }
}

test "encode: 1024-byte string (multi-byte length)" {
  let payload = Bytes::make(1024, b'\x61')
  let encoded = @rlp.encode(s(payload))
  // prefix = 0xb7 + 2 = 0xb9, length = 0x0400 (big-endian)
  assert_eq(encoded.length(), 1027)
  assert_eq(encoded[0], b'\xb9')
  assert_eq(encoded[1], b'\x04')
  assert_eq(encoded[2], b'\x00')
}

test "encode: [\"cat\", \"dog\"] -> 0xc8 0x83 cat 0x83 dog" {
  let v = l([s(b"cat"), s(b"dog")])
  assert_eq(@rlp.encode(v), b"\xc8\x83\x63\x61\x74\x83\x64\x6f\x67")
}

test "encode: nested set-theory list" {
  // [ [], [[]], [ [], [[]] ] ] -> 0xc7c0c1c0c3c0c1c0
  let v = l([
    l([]),
    l([l([])]),
    l([l([]), l([l([])])]),
  ])
  assert_eq(@rlp.encode(v), b"\xc7\xc0\xc1\xc0\xc3\xc0\xc1\xc0")
}

test "encode: long list (>55 byte payload)" {
  // 12 strings of "asdfasdfasdf" (each encodes to 1 + 12 = 13 bytes = c-prefix + payload)
  // Wait, "asdfasdfasdf" is 12 bytes -> encodes as 0x8c + 12 bytes = 13 bytes per item.
  // Total payload = 12 * 13 = 156 bytes -> long list form.
  let item = s(b"asdfasdfasdf")
  let items : Array[@rlp.RlpValue] = []
  for _ in 0..<12 {
    items.push(item)
  }
  let encoded = @rlp.encode(l(items))
  // payload length = 156 = 0x9c, fits in 1 byte. prefix = 0xf7 + 1 = 0xf8.
  assert_eq(encoded[0], b'\xf8')
  assert_eq(encoded[1], b'\x9c')
  assert_eq(encoded.length(), 2 + 156)
}

// ---------- decode (round-trips and explicit byte tests) ----------

test "decode: 0x80 -> empty string" {
  assert_eq(@rlp.decode(b"\x80"), Ok(s(b"")))
}

test "decode: 0xc0 -> empty list" {
  assert_eq(@rlp.decode(b"\xc0"), Ok(l([])))
}

test "decode: 0x00 -> single byte 0x00" {
  assert_eq(@rlp.decode(b"\x00"), Ok(s(b"\x00")))
}

test "decode: 0x7f -> single byte 0x7f" {
  assert_eq(@rlp.decode(b"\x7f"), Ok(s(b"\x7f")))
}

test "decode: 0x81 0x80 -> single byte 0x80" {
  assert_eq(@rlp.decode(b"\x81\x80"), Ok(s(b"\x80")))
}

test "decode: 0x83 dog -> \"dog\"" {
  assert_eq(@rlp.decode(b"\x83\x64\x6f\x67"), Ok(s(b"dog")))
}

test "decode: nested list 0xc7c0c1c0c3c0c1c0" {
  let want = l([
    l([]),
    l([l([])]),
    l([l([]), l([l([])])]),
  ])
  assert_eq(@rlp.decode(b"\xc7\xc0\xc1\xc0\xc3\xc0\xc1\xc0"), Ok(want))
}

test "decode: cat-dog list" {
  assert_eq(
    @rlp.decode(b"\xc8\x83\x63\x61\x74\x83\x64\x6f\x67"),
    Ok(l([s(b"cat"), s(b"dog")])),
  )
}

// ---------- decode error cases (canonicality + framing) ----------

test "decode: empty input -> EmptyInput" {
  assert_true(@rlp.decode(b"") is Err(EmptyInput))
}

test "decode: trailing bytes after valid encoding" {
  // "0x80 + 0xff" is a valid empty string followed by garbage.
  assert_true(@rlp.decode(b"\x80\xff") is Err(TrailingBytes(_)))
}

test "decode: truncated short string" {
  // 0x83 says \"3 bytes follow\" but only 2 are present.
  assert_true(@rlp.decode(b"\x83\x64\x6f") is Err(TruncatedInput(_, _)))
}

test "decode: truncated long string length" {
  // 0xb9 says \"length is 2 bytes\" but only 1 follows
  assert_true(@rlp.decode(b"\xb9\x04") is Err(TruncatedInput(_, _)))
}

test "decode: non-canonical single byte (0x81 0x42)" {
  // 0x42 < 0x80 must NOT be wrapped with 0x81 — the single-byte encoding is canonical.
  assert_true(@rlp.decode(b"\x81\x42") is Err(NonCanonicalSingleByte))
}

test "decode: leading-zero length byte" {
  // 0xb8 0x00 ... = string with declared length 0; canonical would use 0x80.
  assert_true(@rlp.decode(b"\xb8\x00") is Err(NonCanonicalLengthLeadingZero))
}

test "decode: long-form length when short form would fit" {
  // 0xb8 0x37 + 55 bytes — declared length 55, but should have used 0xb7 prefix.
  let mut buf = b"\xb8\x37"
  for _ in 0..<55 {
    buf = buf + b"\x61"
  }
  assert_true(@rlp.decode(buf) is Err(NonCanonicalLength))
}

// ---------- round-trip ----------

test "round-trip: 0..255 incrementing string" {
  let arr : Array[Byte] = Array::makei(256, fn(i) { i.to_byte() })
  let v = s(Bytes::from_array(arr[:]))
  let encoded = @rlp.encode(v)
  match @rlp.decode(encoded) {
    Ok(decoded) => assert_eq(decoded, v)
    Err(_) => abort("decode failed")
  }
}

test "round-trip: deeply nested list" {
  let v = l([
    l([s(b"hello"), s(b"world")]),
    s(b"\x00\x01\x02\x03"),
    l([l([s(b"a")]), s(b"")]),
  ])
  match @rlp.decode(@rlp.encode(v)) {
    Ok(decoded) => assert_eq(decoded, v)
    Err(_) => abort("decode failed")
  }
}

test "round-trip: long list (200 items)" {
  let items : Array[@rlp.RlpValue] = []
  for i = 0; i < 200; i = i + 1 {
    items.push(s(Bytes::make(i % 5 + 1, (i % 256).to_byte())))
  }
  let v = l(items)
  match @rlp.decode(@rlp.encode(v)) {
    Ok(decoded) => assert_eq(decoded, v)
    Err(_) => abort("decode failed")
  }
}
