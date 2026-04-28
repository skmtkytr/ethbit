// Official RIPEMD-160 test vectors (Dobbertin/Bosselaers/Preneel, 1996).
// https://homes.esat.kuleuven.be/~bosselae/ripemd160.html

fn h(s : String) -> Bytes {
  match @hex.decode(s) {
    Ok(b) => b
    Err(_) => abort("invalid hex literal")
  }
}

test "ripemd160 of empty string" {
  let want = h("0x9c1185a5c5e9fc54612808977ee8f548b2258d31")
  assert_eq(@ripemd160.ripemd160(b""), want)
}

test "ripemd160 of 'a'" {
  let want = h("0x0bdc9d2d256b3ee9daae347be6f4dc835a467ffe")
  assert_eq(@ripemd160.ripemd160(b"a"), want)
}

test "ripemd160 of 'abc'" {
  let want = h("0x8eb208f7e05d987a9b044a8e98c6b087f15a0bfc")
  assert_eq(@ripemd160.ripemd160(b"abc"), want)
}

test "ripemd160 of 'message digest'" {
  let want = h("0x5d0689ef49d2fae572b881b123a85ffa21595f36")
  assert_eq(@ripemd160.ripemd160(b"message digest"), want)
}

test "ripemd160 of 'a'..'z'" {
  let want = h("0xf71c27109c692c1b56bbdceb5b9d2865b3708dbc")
  assert_eq(@ripemd160.ripemd160(b"abcdefghijklmnopqrstuvwxyz"), want)
}

test "ripemd160 of alphanumeric mix" {
  let want = h("0xb0e20b6e3116640286ed3a87a5713079b21f5189")
  assert_eq(
    @ripemd160.ripemd160(
      b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789",
    ),
    want,
  )
}

test "ripemd160 of 'a'*1000000" {
  let arr : Array[Byte] = Array::make(1000000, b'\x61')
  let input = Bytes::from_array(arr[:])
  let want = h("0x52783243c1697bdbe16d37f97f68f08325dc1528")
  assert_eq(@ripemd160.ripemd160(input), want)
}

// Padding boundary checks: input length 55 vs 56 bytes (the boundary where
// the 1-bit + length field crosses into a second block).

test "ripemd160 of 55 bytes produces 20-byte output" {
  let arr : Array[Byte] = Array::make(55, b'\x61')
  let out = @ripemd160.ripemd160(Bytes::from_array(arr[:]))
  assert_eq(out.length(), 20)
}

test "ripemd160 of 56 bytes produces 20-byte output" {
  let arr : Array[Byte] = Array::make(56, b'\x61')
  let out = @ripemd160.ripemd160(Bytes::from_array(arr[:]))
  assert_eq(out.length(), 20)
}

test "ripemd160 of 64 bytes produces 20-byte output" {
  let arr : Array[Byte] = Array::make(64, b'\x61')
  let out = @ripemd160.ripemd160(Bytes::from_array(arr[:]))
  assert_eq(out.length(), 20)
}
