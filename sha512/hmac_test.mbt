// RFC 4231 HMAC-SHA-512 test vectors.

fn ch(s : String) -> Bytes {
  match @hex.decode(s) {
    Ok(b) => b
    Err(_) => abort("invalid hex literal")
  }
}

test "RFC 4231 test 1" {
  let key = ch("0x0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b")
  let data = b"Hi There"
  let want = ch(
    "0x87aa7cdea5ef619d4ff0b4241a1d6cb02379f4e2ce4ec2787ad0b30545e17cdedaa833b7d6b8a702038b274eaea3f4e4be9d914eeb61f1702e696c203a126854",
  )
  assert_eq(@sha512.hmac(key, data), want)
}

test "RFC 4231 test 2" {
  let key = b"Jefe"
  let data = b"what do ya want for nothing?"
  let want = ch(
    "0x164b7a7bfcf819e2e395fbe73b56e0a387bd64222e831fd610270cd7ea2505549758bf75c05a994a6d034f65f8f0e6fdcaeab1a34d4a6b4b636e070a38bce737",
  )
  assert_eq(@sha512.hmac(key, data), want)
}

test "RFC 4231 test 4 (key=0x0102..0x19, data=0xcd*50)" {
  let key = ch("0x0102030405060708090a0b0c0d0e0f10111213141516171819")
  let arr : Array[Byte] = Array::make(50, b'\xcd')
  let data = Bytes::from_array(arr[:])
  let want = ch(
    "0xb0ba465637458c6990e5a8c5f61d4af7e576d97ff94b872de76f8050361ee3dba91ca5c11aa25eb4d679275cc5788063a5f19741120c4f2de2adebeb10a298dd",
  )
  assert_eq(@sha512.hmac(key, data), want)
}
