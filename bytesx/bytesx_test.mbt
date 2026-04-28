// concat -----------------------------------------------------------

test "concat: empty array" {
  assert_eq(@bytesx.concat([]), b"")
}

test "concat: single element" {
  assert_eq(@bytesx.concat([b"hello"]), b"hello")
}

test "concat: multiple elements" {
  assert_eq(
    @bytesx.concat([b"\xde\xad", b"\xbe\xef", b"\x01"]),
    b"\xde\xad\xbe\xef\x01",
  )
}

test "concat: includes empty parts" {
  assert_eq(@bytesx.concat([b"", b"abc", b"", b"def", b""]), b"abcdef")
}

// slice ------------------------------------------------------------

test "slice: full range" {
  assert_eq(@bytesx.slice(b"\x01\x02\x03", 0, 3), b"\x01\x02\x03")
}

test "slice: middle" {
  assert_eq(@bytesx.slice(b"\x01\x02\x03\x04\x05", 1, 4), b"\x02\x03\x04")
}

test "slice: empty" {
  assert_eq(@bytesx.slice(b"\x01\x02", 1, 1), b"")
}

// pad_left ---------------------------------------------------------

test "pad_left: shorter input gets padded" {
  assert_eq(@bytesx.pad_left(b"\xab", 4, b'\x00'), b"\x00\x00\x00\xab")
}

test "pad_left: equal length is unchanged" {
  assert_eq(@bytesx.pad_left(b"\xab\xcd", 2, b'\x00'), b"\xab\xcd")
}

test "pad_left: longer input is unchanged (no truncation)" {
  assert_eq(@bytesx.pad_left(b"\xab\xcd\xef", 2, b'\x00'), b"\xab\xcd\xef")
}

test "pad_left: empty input padded fully" {
  assert_eq(@bytesx.pad_left(b"", 4, b'\xff'), b"\xff\xff\xff\xff")
}

// pad_right --------------------------------------------------------

test "pad_right: shorter input gets padded" {
  assert_eq(@bytesx.pad_right(b"\xab", 4, b'\x00'), b"\xab\x00\x00\x00")
}

test "pad_right: equal length is unchanged" {
  assert_eq(@bytesx.pad_right(b"\xab\xcd", 2, b'\x00'), b"\xab\xcd")
}

test "pad_right: longer input is unchanged" {
  assert_eq(@bytesx.pad_right(b"\xab\xcd\xef", 2, b'\x00'), b"\xab\xcd\xef")
}

// from_uint64_be ---------------------------------------------------

test "from_uint64_be: zero -> empty" {
  assert_eq(@bytesx.from_uint64_be(0UL), b"")
}

test "from_uint64_be: 1 -> 0x01" {
  assert_eq(@bytesx.from_uint64_be(1UL), b"\x01")
}

test "from_uint64_be: 0xff -> 0xff" {
  assert_eq(@bytesx.from_uint64_be(0xffUL), b"\xff")
}

test "from_uint64_be: 0x0100 -> 0x01 0x00 (no leading zero)" {
  assert_eq(@bytesx.from_uint64_be(0x0100UL), b"\x01\x00")
}

test "from_uint64_be: 1024 -> 0x04 0x00" {
  assert_eq(@bytesx.from_uint64_be(1024UL), b"\x04\x00")
}

test "from_uint64_be: 0xdeadbeef -> 4 bytes" {
  assert_eq(@bytesx.from_uint64_be(0xdeadbeefUL), b"\xde\xad\xbe\xef")
}

test "from_uint64_be: max -> 8 bytes 0xff" {
  assert_eq(
    @bytesx.from_uint64_be(0xffffffffffffffffUL),
    b"\xff\xff\xff\xff\xff\xff\xff\xff",
  )
}
