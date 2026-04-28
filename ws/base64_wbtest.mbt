// RFC 4648 §10 test vectors for base64.

test "base64 encode empty" {
  assert_eq(base64_encode(b""), "")
}

test "base64 encode 'f'" {
  assert_eq(base64_encode(b"f"), "Zg==")
}

test "base64 encode 'fo'" {
  assert_eq(base64_encode(b"fo"), "Zm8=")
}

test "base64 encode 'foo'" {
  assert_eq(base64_encode(b"foo"), "Zm9v")
}

test "base64 encode 'foob'" {
  assert_eq(base64_encode(b"foob"), "Zm9vYg==")
}

test "base64 encode 'fooba'" {
  assert_eq(base64_encode(b"fooba"), "Zm9vYmE=")
}

test "base64 encode 'foobar'" {
  assert_eq(base64_encode(b"foobar"), "Zm9vYmFy")
}

test "base64 decode empty" {
  match base64_decode("") {
    Some(b) => assert_eq(b, b"")
    None => abort("expected Some")
  }
}

test "base64 decode 'Zg=='" {
  match base64_decode("Zg==") {
    Some(b) => assert_eq(b, b"f")
    None => abort("expected Some")
  }
}

test "base64 decode 'Zm8='" {
  match base64_decode("Zm8=") {
    Some(b) => assert_eq(b, b"fo")
    None => abort("expected Some")
  }
}

test "base64 decode 'Zm9v'" {
  match base64_decode("Zm9v") {
    Some(b) => assert_eq(b, b"foo")
    None => abort("expected Some")
  }
}

test "base64 decode 'Zm9vYmFy'" {
  match base64_decode("Zm9vYmFy") {
    Some(b) => assert_eq(b, b"foobar")
    None => abort("expected Some")
  }
}

test "base64 round-trip 16 random bytes" {
  let data = b"\x01\x23\x45\x67\x89\xab\xcd\xef\x10\x32\x54\x76\x98\xba\xdc\xfe"
  let encoded = base64_encode(data)
  match base64_decode(encoded) {
    Some(b) => assert_eq(b, data)
    None => abort("expected Some")
  }
}

test "base64 decode rejects bad length" {
  // Length must be multiple of 4.
  assert_eq(base64_decode("Zg="), None)
  assert_eq(base64_decode("Zg"), None)
  assert_eq(base64_decode("Z"), None)
}

test "base64 decode rejects invalid character" {
  assert_eq(base64_decode("Zg=!"), None) // '!' is not in alphabet
  assert_eq(base64_decode("Z!=="), None)
}

test "base64 decode rejects misplaced padding" {
  assert_eq(base64_decode("Z=g="), None) // '=' before last
}

test "base64 RFC 6455 sample nonce" {
  // The canonical RFC 6455 example: client key "the sample nonce".
  match base64_decode("dGhlIHNhbXBsZSBub25jZQ==") {
    Some(b) => assert_eq(b, b"the sample nonce")
    None => abort("expected Some")
  }
  assert_eq(base64_encode(b"the sample nonce"), "dGhlIHNhbXBsZSBub25jZQ==")
}
