// FIPS 180-4 / NIST CAVS test vectors for SHA-1.
//
// SHA-1 is private to this package; we test it via a small wrapper function
// (also private) declared in this same package's test file. The wrapper just
// re-exports the priv function for the test harness.

fn h_sha1(s : String) -> Bytes {
  match @hex.decode(s) {
    Ok(b) => b
    Err(_) => abort("invalid hex literal")
  }
}

test "sha1 of empty string" {
  let want = h_sha1("0xda39a3ee5e6b4b0d3255bfef95601890afd80709")
  assert_eq(sha1(b""), want)
}

test "sha1 of 'abc'" {
  let want = h_sha1("0xa9993e364706816aba3e25717850c26c9cd0d89d")
  assert_eq(sha1(b"abc"), want)
}

test "sha1 of 448-bit message" {
  let want = h_sha1("0x84983e441c3bd26ebaae4aa1f95129e5e54670f1")
  assert_eq(
    sha1(b"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"),
    want,
  )
}

test "sha1 of single byte 0x00" {
  // FIPS / wikipedia: sha1("\x00") = 5ba93c9db0cff93f52b521d7420e43f6eda2784f
  let want = h_sha1("0x5ba93c9db0cff93f52b521d7420e43f6eda2784f")
  assert_eq(sha1(b"\x00"), want)
}

test "sha1 of 55 bytes produces 20-byte output" {
  let arr : Array[Byte] = Array::make(55, b'\x61')
  let out = sha1(Bytes::from_array(arr[:]))
  assert_eq(out.length(), 20)
}

test "sha1 of 64 bytes produces 20-byte output" {
  let arr : Array[Byte] = Array::make(64, b'\x61')
  let out = sha1(Bytes::from_array(arr[:]))
  assert_eq(out.length(), 20)
}
