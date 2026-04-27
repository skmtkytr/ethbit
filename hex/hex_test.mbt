test "encode: empty bytes -> 0x" {
  assert_eq(@hex.encode(b""), "0x")
}

test "encode: single byte" {
  assert_eq(@hex.encode(b"\x00"), "0x00")
  assert_eq(@hex.encode(b"\xff"), "0xff")
  assert_eq(@hex.encode(b"\x0a"), "0x0a")
}

test "encode: multi-byte" {
  assert_eq(@hex.encode(b"\xde\xad\xbe\xef"), "0xdeadbeef")
}

test "encode: lowercase only" {
  assert_eq(@hex.encode(b"\xab\xcd\xef"), "0xabcdef")
}

test "decode: with 0x prefix" {
  assert_eq(@hex.decode("0xdeadbeef"), Ok(b"\xde\xad\xbe\xef"))
}

test "decode: without prefix" {
  assert_eq(@hex.decode("deadbeef"), Ok(b"\xde\xad\xbe\xef"))
}

test "decode: empty string and 0x" {
  assert_eq(@hex.decode(""), Ok(b""))
  assert_eq(@hex.decode("0x"), Ok(b""))
}

test "decode: uppercase accepted" {
  assert_eq(@hex.decode("0xDEADBEEF"), Ok(b"\xde\xad\xbe\xef"))
  assert_eq(@hex.decode("0xDeAdBeEf"), Ok(b"\xde\xad\xbe\xef"))
}

test "decode: odd length is error" {
  assert_true(@hex.decode("0xabc") is Err(OddLength(_)))
  assert_true(@hex.decode("abc") is Err(OddLength(_)))
}

test "decode: invalid character is error" {
  assert_true(@hex.decode("0xzz") is Err(InvalidChar('z', _)))
  assert_true(@hex.decode("0xgg") is Err(InvalidChar('g', _)))
}

test "round-trip" {
  let original = b"\x01\x23\x45\x67\x89\xab\xcd\xef"
  let encoded = @hex.encode(original)
  assert_eq(encoded, "0x0123456789abcdef")
  assert_eq(@hex.decode(encoded), Ok(original))
}
