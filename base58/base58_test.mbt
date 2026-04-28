// ----- Plain Base58 -----

test "encode: empty bytes" {
  assert_eq(@base58.encode(b""), "")
}

test "encode: single zero byte -> '1'" {
  assert_eq(@base58.encode(b"\x00"), "1")
}

test "encode: two zero bytes -> '11'" {
  assert_eq(@base58.encode(b"\x00\x00"), "11")
}

test "encode: leading zero plus 0x61 -> '12g'" {
  // 0x61 (= 97) encodes to "2g" (1*58 + 39); the leading 0x00 prepends a '1'.
  assert_eq(@base58.encode(b"\x00\x61"), "12g")
}

test "encode: 0x61 alone -> '2g'" {
  // 0x61 = 97 = 1*58 + 39 → digits are [1, 39] = ['2', 'g'].
  assert_eq(@base58.encode(b"\x61"), "2g")
}

test "decode: empty input is Err(Empty)" {
  assert_true(@base58.decode("") is Err(Empty))
}

test "decode: canonical 'hello world' base58 string" {
  // Plain Base58 of the ASCII string "hello world".
  let expected = b"\x68\x65\x6c\x6c\x6f\x20\x77\x6f\x72\x6c\x64"
  assert_eq(@base58.decode("StV1DL6CwTryKyV"), Ok(expected))
}

test "encode: 'hello world!' -> canonical base58" {
  let payload = b"\x68\x65\x6c\x6c\x6f\x20\x77\x6f\x72\x6c\x64\x21"
  assert_eq(@base58.encode(payload), "2yGEbwRFyhPZZckKA")
}

test "decode: '1' -> single zero byte" {
  assert_eq(@base58.decode("1"), Ok(b"\x00"))
}

test "decode: '11' -> two zero bytes" {
  assert_eq(@base58.decode("11"), Ok(b"\x00\x00"))
}

test "decode: '2g' -> 0x61" {
  assert_eq(@base58.decode("2g"), Ok(b"\x61"))
}

test "decode: invalid char surfaces position" {
  // '0' (zero) is not in the alphabet. Position 0.
  assert_true(@base58.decode("0") is Err(InvalidChar(0)))
  // 'O' (uppercase O) excluded; here at position 2.
  assert_true(@base58.decode("AbOcd") is Err(InvalidChar(2)))
  // 'l' (lowercase L) excluded; first occurrence at position 2 in "Hellol".
  assert_true(@base58.decode("Hellol") is Err(InvalidChar(2)))
}

test "round-trip: random byte sequences" {
  let cases : Array[Bytes] = [
    b"\x00",
    b"\x00\x00\x00\xff",
    b"\xde\xad\xbe\xef",
    b"\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a",
    b"\x00\x00\x12\x34\x56\x78\x9a\xbc\xde\xf0",
    b"\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff",
  ]
  for c in cases {
    let encoded = @base58.encode(c)
    match @base58.decode(encoded) {
      Ok(d) => assert_eq(d, c)
      Err(e) => fail("decode failed: \{e}")
    }
  }
}

// ----- Base58Check -----

test "decode_check: bitcoin genesis P2PKH address" {
  // The canonical base58check decode of the genesis block coinbase address.
  // First byte is the version (0x00 = mainnet P2PKH); remaining 20 bytes are
  // the hash160 of Satoshi's genesis pubkey.
  let expected = match
    @hex.decode("0x0062e907b15cbf27d5425399ebf6f0fb50ebb88f18") {
    Ok(b) => b
    Err(e) => {
      fail("hex decode of expected payload failed: \{e}")
      b""
    }
  }
  match @base58.decode_check("1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa") {
    Ok(payload) => assert_eq(payload, expected)
    Err(e) => fail("decode_check failed: \{e}")
  }
}

test "decode_check: tampered string -> InvalidChecksum" {
  // Flip the last character of the genesis address (a -> b).
  assert_true(
    @base58.decode_check("1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNb") is
      Err(InvalidChecksum),
  )
}

test "decode_check: empty input -> Empty" {
  assert_true(@base58.decode_check("") is Err(Empty))
}

test "decode_check: non-alphabet char surfaces position" {
  // 'l' (lowercase L) is not in the alphabet. Index 1 here.
  assert_true(@base58.decode_check("Al23") is Err(InvalidChar(1)))
}

test "decode_check: input shorter than 4 bytes -> InvalidChecksum" {
  // "11" decodes to b"\x00\x00" which has length 2 (< 4). Treat as bad checksum.
  assert_true(@base58.decode_check("11") is Err(InvalidChecksum))
}

test "encode_check / decode_check round-trip" {
  let cases : Array[Bytes] = [
    b"\x00",
    b"\x00\x01\x02\x03",
    b"\xde\xad\xbe\xef",
    b"\x00\x62\xe9\x07\xb1\x5c\xbf\x27\xd5\x42\x53\x99\xeb\xf6\xf0\xfb\x50\xeb\xb8\x8f\x18",
  ]
  for c in cases {
    let s = @base58.encode_check(c)
    match @base58.decode_check(s) {
      Ok(d) => assert_eq(d, c)
      Err(e) => fail("decode_check failed for round-trip: \{e}")
    }
  }
}

test "encode_check: matches canonical genesis address" {
  // Round-trips against the known string for the genesis P2PKH payload.
  let payload = match
    @hex.decode("0x0062e907b15cbf27d5425399ebf6f0fb50ebb88f18") {
    Ok(b) => b
    Err(e) => {
      fail("hex decode failed: \{e}")
      b""
    }
  }
  assert_eq(
    @base58.encode_check(payload),
    "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa",
  )
}

test "decode_check: BIP-32 test vector 1 master xprv produces 78-byte payload" {
  let xprv =
    "xprv9s21ZrQH143K3QTDL4LXw2F7HEK3wJUD2nW2nRk4stbPy6cq3jPPqjiChkVvvNKmPGJxWUtg6LnF5kejMRNNU3TGtRBeJgk33yuGBxrMPHi"
  match @base58.decode_check(xprv) {
    Ok(payload) => assert_eq(payload.length(), 78)
    Err(e) => fail("decode_check failed: \{e}")
  }
}

// ----- DecodeError Show -----

test "Show DecodeError" {
  inspect(@base58.InvalidChar(7), content="InvalidChar(7)")
  inspect(@base58.InvalidChecksum, content="InvalidChecksum")
  inspect(@base58.Empty, content="Empty")
}
