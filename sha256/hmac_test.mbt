// RFC 4231 HMAC-SHA-256 test vectors.

fn ch(s : String) -> Bytes {
  match @hex.decode(s) {
    Ok(b) => b
    Err(_) => abort("invalid hex literal")
  }
}

test "RFC 4231 test 1" {
  let key = ch("0x0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b")
  let data = b"Hi There"
  let want = ch("0xb0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7")
  assert_eq(@sha256.hmac(key, data), want)
}

test "RFC 4231 test 2" {
  let key = b"Jefe"
  let data = b"what do ya want for nothing?"
  let want = ch("0x5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843")
  assert_eq(@sha256.hmac(key, data), want)
}

test "RFC 4231 test 3 (key=0xaa*20, data=0xdd*50)" {
  let key = ch("0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
  let arr : Array[Byte] = Array::make(50, b'\xdd')
  let data = Bytes::from_array(arr[:])
  let want = ch("0x773ea91e36800e46854db8ebd09181a72959098b3ef8c122d9635514ced565fe")
  assert_eq(@sha256.hmac(key, data), want)
}

test "RFC 4231 test 4 (key=0x0102..0x19, data=0xcd*50)" {
  let key = ch(
    "0x0102030405060708090a0b0c0d0e0f10111213141516171819",
  )
  let arr : Array[Byte] = Array::make(50, b'\xcd')
  let data = Bytes::from_array(arr[:])
  let want = ch("0x82558a389a443c0ea4cc819899f2083a85f0faa3e578f8077a2e3ff46729665b")
  assert_eq(@sha256.hmac(key, data), want)
}

test "RFC 4231 test 6 (key longer than block)" {
  let arr : Array[Byte] = Array::make(131, b'\xaa')
  let key = Bytes::from_array(arr[:])
  let data = b"Test Using Larger Than Block-Size Key - Hash Key First"
  let want = ch("0x60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54")
  assert_eq(@sha256.hmac(key, data), want)
}
