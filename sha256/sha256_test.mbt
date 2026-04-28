// FIPS 180-4 / NIST CAVS test vectors.

fn h(s : String) -> Bytes {
  match @hex.decode(s) {
    Ok(b) => b
    Err(_) => abort("invalid hex literal")
  }
}

test "sha256 of empty string" {
  let want = h("0xe3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
  assert_eq(@sha256.sha256(b""), want)
}

test "sha256 of 'abc'" {
  let want = h("0xba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
  assert_eq(@sha256.sha256(b"abc"), want)
}

test "sha256 of 448-bit message" {
  let want = h("0x248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1")
  assert_eq(
    @sha256.sha256(b"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"),
    want,
  )
}

test "sha256 of 'a'*1000000" {
  let arr : Array[Byte] = Array::make(1000000, b'\x61')
  let input = Bytes::from_array(arr[:])
  let want = h("0xcdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0")
  assert_eq(@sha256.sha256(input), want)
}

test "sha256 of single byte 0x00" {
  let want = h("0x6e340b9cffb37a989ca544e6bb780a2c78901d3fb33738768511a30617afa01d")
  assert_eq(@sha256.sha256(b"\x00"), want)
}

// Padding boundary check: input length 55 vs 56 bytes (the boundary where
// the 1-bit + length field crosses into a second block). The 56-byte case
// is the standard NIST vector above. We additionally test that 55 and 64
// bytes both produce some 32-byte output without crashing — full vector
// validation is provided by the NIST cases.

test "sha256 of 55 bytes produces 32-byte output" {
  let arr : Array[Byte] = Array::make(55, b'\x61')
  let out = @sha256.sha256(Bytes::from_array(arr[:]))
  assert_eq(out.length(), 32)
}

test "sha256 of 64 bytes produces 32-byte output" {
  let arr : Array[Byte] = Array::make(64, b'\x61')
  let out = @sha256.sha256(Bytes::from_array(arr[:]))
  assert_eq(out.length(), 32)
}
