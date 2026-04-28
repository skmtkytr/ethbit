// FIPS 180-4 / NIST CAVS test vectors.

fn h(s : String) -> Bytes {
  match @hex.decode(s) {
    Ok(b) => b
    Err(_) => abort("invalid hex literal")
  }
}

test "sha512 of empty string" {
  let want = h(
    "0xcf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e",
  )
  assert_eq(@sha512.sha512(b""), want)
}

test "sha512 of 'abc'" {
  let want = h(
    "0xddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f",
  )
  assert_eq(@sha512.sha512(b"abc"), want)
}

test "sha512 of 896-bit message" {
  let want = h(
    "0x8e959b75dae313da8cf4f72814fc143f8f7779c6eb9f7fa17299aeadb6889018501d289e4900f7e4331b99dec4b5433ac7d329eeb6dd26545e96e55b874be909",
  )
  assert_eq(
    @sha512.sha512(
      b"abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu",
    ),
    want,
  )
}

test "sha512 of 'a'*1000000" {
  let arr : Array[Byte] = Array::make(1000000, b'\x61')
  let input = Bytes::from_array(arr[:])
  let want = h(
    "0xe718483d0ce769644e2e42c7bc15b4638e1f98b13b2044285632a803afa973ebde0ff244877ea60a4cb0432ce577c31beb009c5c2c49aa2e4eadb217ad8cc09b",
  )
  assert_eq(@sha512.sha512(input), want)
}

test "sha512 of single byte produces 64-byte output" {
  let out = @sha512.sha512(b"\x00")
  assert_eq(out.length(), 64)
}

// Padding boundary check: input length 111 vs 112 bytes (the boundary where
// the 1-bit + 16-byte length field crosses into a second block). The 112-byte
// case is the standard NIST vector above. We additionally test that 111 and
// 128 bytes both produce some 64-byte output without crashing — full vector
// validation is provided by the NIST cases.

test "sha512 of 111 bytes produces 64-byte output" {
  let arr : Array[Byte] = Array::make(111, b'\x61')
  let out = @sha512.sha512(Bytes::from_array(arr[:]))
  assert_eq(out.length(), 64)
}

test "sha512 of 128 bytes produces 64-byte output" {
  let arr : Array[Byte] = Array::make(128, b'\x61')
  let out = @sha512.sha512(Bytes::from_array(arr[:]))
  assert_eq(out.length(), 64)
}
