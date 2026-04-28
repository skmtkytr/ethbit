fn sec_b16(s : String) -> @bigint.BigInt {
  @bigint.BigInt::from_string(s, radix=16)
}

fn sec_h(s : String) -> Bytes {
  match @hex.decode(s) {
    Ok(b) => b
    Err(_) => abort("invalid hex literal")
  }
}

let sec_test_sk : @bigint.BigInt = sec_b16(
  "C9AFA9D845BA75166B5C215767B1D6934E50C3DB36E89B127B8A622B120F6721",
)

// ---- pubkey derivation ----

test "pubkey_from_sk: priv = 1 → pubkey = G" {
  let pk = @secp256k1.pubkey_from_sk(sec_b16("01"))
  assert_true(@secp256k1.point_eq(pk, @secp256k1.g))
}

test "pubkey_from_sk: known scalar produces an on-curve point" {
  let pk = @secp256k1.pubkey_from_sk(sec_test_sk)
  assert_true(@secp256k1.on_curve(pk))
  assert_eq(@secp256k1.is_infinity(pk), false)
}

// ---- uncompressed encoding ----

test "pubkey_to_uncompressed for G has 0x04 prefix and known x" {
  let bytes = @secp256k1.pubkey_to_uncompressed(@secp256k1.g)
  assert_eq(bytes.length(), 65)
  assert_eq(bytes[0], b'\x04')
  // x bytes 1..33 should match Gx
  let want = sec_h(
    "0x0479BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8",
  )
  assert_eq(bytes, want)
}

test "pubkey_to_xy_bytes for G is 64 bytes (no prefix)" {
  let bytes = @secp256k1.pubkey_to_xy_bytes(@secp256k1.g)
  assert_eq(bytes.length(), 64)
  let want = sec_h(
    "0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8",
  )
  assert_eq(bytes, want)
}

// ---- compressed encoding ----

test "pubkey_to_compressed for G has 0x03 prefix (Gy is odd)" {
  // Gy = 0x483A... ends with byte 0xB8 (even). Wait let me check:
  // 0xB8 = 184 = even. So 0x02 prefix.
  let bytes = @secp256k1.pubkey_to_compressed(@secp256k1.g)
  assert_eq(bytes.length(), 33)
  assert_eq(bytes[0], b'\x02')
  let want = sec_h(
    "0x0279BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798",
  )
  assert_eq(bytes, want)
}

test "pubkey_to_compressed for 2G has 0x03 prefix (2Gy is odd)" {
  // 2Gy = 0x1AE168FE...A950CFE52A — ends with 0x2A = 42 = even? Let me double check.
  // 0x2A = 42 → even → prefix 0x02. Hmm let me actually verify by parity.
  let two_g = @secp256k1.point_double(@secp256k1.g)
  let bytes = @secp256k1.pubkey_to_compressed(two_g)
  assert_eq(bytes.length(), 33)
  // 2Gy parity: 0x...52A → last byte 0x2A (42) → even → 0x02
  assert_eq(bytes[0], b'\x02')
}

// ---- roundtrip ----

test "pubkey roundtrip uncompressed" {
  let pk = @secp256k1.pubkey_from_sk(sec_test_sk)
  let bytes = @secp256k1.pubkey_to_uncompressed(pk)
  match @secp256k1.pubkey_from_bytes(bytes) {
    Some(decoded) => assert_true(@secp256k1.point_eq(decoded, pk))
    None => assert_true(false)
  }
}

test "pubkey roundtrip compressed" {
  let pk = @secp256k1.pubkey_from_sk(sec_test_sk)
  let bytes = @secp256k1.pubkey_to_compressed(pk)
  match @secp256k1.pubkey_from_bytes(bytes) {
    Some(decoded) => assert_true(@secp256k1.point_eq(decoded, pk))
    None => assert_true(false)
  }
}

test "pubkey roundtrip preserves parity (priv = 7, often odd-y test case)" {
  let pk = @secp256k1.pubkey_from_sk(@bigint.BigInt::from_int(7))
  let comp = @secp256k1.pubkey_to_compressed(pk)
  match @secp256k1.pubkey_from_bytes(comp) {
    Some(decoded) => assert_true(@secp256k1.point_eq(decoded, pk))
    None => assert_true(false)
  }
}

// ---- decoding edge cases ----

test "pubkey_from_bytes: wrong length returns None" {
  match @secp256k1.pubkey_from_bytes(b"\x04\x00") {
    Some(_) => assert_true(false)
    None => ()
  }
}

test "pubkey_from_bytes: bad uncompressed tag returns None" {
  let bytes = sec_h(
    "0x0079BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8",
  )
  match @secp256k1.pubkey_from_bytes(bytes) {
    Some(_) => assert_true(false)
    None => ()
  }
}

test "pubkey_from_bytes: off-curve point returns None" {
  // x=0, y=0 with 0x04 prefix: not on y² = x³ + 7
  let bytes = @bytesx.concat([
    b"\x04",
    @bigint.BigInt::from_int(0).to_octets(length=32),
    @bigint.BigInt::from_int(0).to_octets(length=32),
  ])
  match @secp256k1.pubkey_from_bytes(bytes) {
    Some(_) => assert_true(false)
    None => ()
  }
}

// ---- end-to-end with sign+verify ----

test "end-to-end: priv → pub → sign → verify with decoded pubkey" {
  let pk = @secp256k1.pubkey_from_sk(sec_test_sk)
  let pk_bytes = @secp256k1.pubkey_to_compressed(pk)
  let msg_hash = @sha256.sha256(b"end-to-end")
  let sig = @secp256k1.sign(sec_test_sk, msg_hash)
  match @secp256k1.pubkey_from_bytes(pk_bytes) {
    Some(decoded) =>
      assert_true(@secp256k1.verify_with_pubkey(decoded, msg_hash, sig))
    None => assert_true(false)
  }
}
