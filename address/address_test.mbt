// EIP-55 test vectors come directly from the spec:
// https://eips.ethereum.org/EIPS/eip-55#test-cases

fn b(s : String) -> Bytes {
  match @hex.decode(s) {
    Ok(b) => b
    Err(_) => abort("invalid hex literal in test")
  }
}

fn unwrap(r : Result[String, @address.AddressError]) -> String {
  match r {
    Ok(s) => s
    Err(_) => abort("expected Ok in test")
  }
}

// ---- to_checksum: EIP-55 spec examples ----

test "to_checksum: all-uppercase pattern (52908400...)" {
  let addr = b("0x52908400098527886E0F7030069857D2E4169EE7")
  assert_eq(
    unwrap(@address.to_checksum(addr)),
    "0x52908400098527886E0F7030069857D2E4169EE7",
  )
}

test "to_checksum: all-uppercase pattern (8617E340...)" {
  let addr = b("0x8617E340B3D01FA5F11F306F4090FD50E238070D")
  assert_eq(
    unwrap(@address.to_checksum(addr)),
    "0x8617E340B3D01FA5F11F306F4090FD50E238070D",
  )
}

test "to_checksum: all-lowercase pattern (de709f21...)" {
  let addr = b("0xde709f2102306220921060314715629080e2fb77")
  assert_eq(
    unwrap(@address.to_checksum(addr)),
    "0xde709f2102306220921060314715629080e2fb77",
  )
}

test "to_checksum: all-lowercase pattern (27b1fdb0...)" {
  let addr = b("0x27b1fdb04752bbc536007a920d24acb045561c26")
  assert_eq(
    unwrap(@address.to_checksum(addr)),
    "0x27b1fdb04752bbc536007a920d24acb045561c26",
  )
}

test "to_checksum: mixed case (5aAeb605...)" {
  let addr = b("0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed")
  assert_eq(
    unwrap(@address.to_checksum(addr)),
    "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed",
  )
}

test "to_checksum: mixed case (fB691609...)" {
  let addr = b("0xfb6916095ca1df60bb79ce92ce3ea74c37c5d359")
  assert_eq(
    unwrap(@address.to_checksum(addr)),
    "0xfB6916095ca1df60bB79Ce92cE3Ea74c37c5d359",
  )
}

test "to_checksum: mixed case (dbF03B40...)" {
  let addr = b("0xdbf03b407c01e7cd3cbea99509d93f8dddc8c6fb")
  assert_eq(
    unwrap(@address.to_checksum(addr)),
    "0xdbF03B407c01E7cD3CBea99509d93f8DDDC8C6FB",
  )
}

test "to_checksum: mixed case (D1220A0c...)" {
  let addr = b("0xd1220a0cf47c7b9be7a2e6ba89f429762e7b9adb")
  assert_eq(
    unwrap(@address.to_checksum(addr)),
    "0xD1220A0cf47c7B9Be7A2E6BA89F429762e7b9aDb",
  )
}

// ---- to_checksum: input is order-independent of source case ----

test "to_checksum: uppercase hex input produces same result" {
  let from_lower = unwrap(
    @address.to_checksum(b("0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed")),
  )
  let from_upper = unwrap(
    @address.to_checksum(b("0x5AAEB6053F3E94C9B9A09F33669435E7EF1BEAED")),
  )
  assert_eq(from_lower, from_upper)
}

// ---- to_checksum: length errors ----

test "to_checksum: 19-byte input is error" {
  assert_true(
    @address.to_checksum(Bytes::make(19, b'\x00'))
    is Err(InvalidLength(19)),
  )
}

test "to_checksum: 21-byte input is error" {
  assert_true(
    @address.to_checksum(Bytes::make(21, b'\x00'))
    is Err(InvalidLength(21)),
  )
}

test "to_checksum: empty input is error" {
  assert_true(@address.to_checksum(b"") is Err(InvalidLength(0)))
}

// ---- is_valid_checksum ----

test "is_valid_checksum: properly checksummed addresses return true" {
  assert_true(@address.is_valid_checksum("0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed"))
  assert_true(@address.is_valid_checksum("0xfB6916095ca1df60bB79Ce92cE3Ea74c37c5d359"))
  assert_true(@address.is_valid_checksum("0x52908400098527886E0F7030069857D2E4169EE7"))
  assert_true(@address.is_valid_checksum("0xde709f2102306220921060314715629080e2fb77"))
}

test "is_valid_checksum: all-lowercase mixed-case address is NOT valid checksum" {
  // The lowercase form is a valid Ethereum address but NOT a valid checksum
  // for an address that has mixed-case bits set.
  assert_false(@address.is_valid_checksum("0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed"))
}

test "is_valid_checksum: all-uppercase mixed-case address is NOT valid checksum" {
  assert_false(@address.is_valid_checksum("0x5AAEB6053F3E94C9B9A09F33669435E7EF1BEAED"))
}

test "is_valid_checksum: single wrong-case character invalidates" {
  // Flip the leading '5' nothing, but flip the 'A' in position 4 to 'a'.
  assert_false(@address.is_valid_checksum("0x5aaeb6053F3E94C9b9A09f33669435E7Ef1BeAed"))
}

test "is_valid_checksum: missing 0x prefix returns false" {
  assert_false(@address.is_valid_checksum("5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed"))
}

test "is_valid_checksum: wrong length returns false" {
  assert_false(@address.is_valid_checksum("0x5aAeb6053F3E94C9b9A09f33669435E7Ef1Bea")) // 39 chars
  assert_false(@address.is_valid_checksum("0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed00")) // 42 chars
  assert_false(@address.is_valid_checksum(""))
  assert_false(@address.is_valid_checksum("0x"))
}

test "is_valid_checksum: non-hex character returns false" {
  assert_false(@address.is_valid_checksum("0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAeZ"))
}

test "is_valid_checksum: uppercase 0X prefix is not accepted (strict)" {
  assert_false(@address.is_valid_checksum("0X5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed"))
}

// ---- Round-trip ----

test "round-trip: checksum of decoded checksum equals original" {
  let original = "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed"
  let bytes = b(original)
  assert_eq(unwrap(@address.to_checksum(bytes)), original)
}

// ---- from_pubkey_xy ----

fn unwrap_addr(r : Result[Bytes, @address.AddressError]) -> Bytes {
  match r {
    Ok(a) => a
    Err(_) => abort("expected Ok in test")
  }
}

test "from_pubkey_xy: priv=1 (pub=G) → 0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf" {
  // SEC1 uncompressed body of G (no 0x04 prefix): Gx || Gy
  let g_xy = b(
    "0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8",
  )
  let addr = unwrap_addr(@address.from_pubkey_xy(g_xy))
  let want = b("0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf")
  assert_eq(addr, want)
}

test "from_pubkey_xy: rejects wrong-length input" {
  match @address.from_pubkey_xy(b"\x00\x01") {
    Ok(_) => assert_true(false)
    Err(_) => ()
  }
}
