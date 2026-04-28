// Tests for EIP-191 personal_sign and EIP-712 typed-data signing.
// External anchor: viem-derived expected signer address for sk=1.

fn msg_h(s : String) -> Bytes {
  match @hex.decode(s) {
    Ok(b) => b
    Err(_) => abort("invalid hex literal in test")
  }
}

fn msg_b16(s : String) -> @bigint.BigInt {
  @bigint.BigInt::from_string(s, radix=16)
}

fn msg_unwrap_addr(r : Result[Bytes, @address.AddressError]) -> Bytes {
  match r {
    Ok(a) => a
    Err(_) => abort("expected Ok in test")
  }
}

let msg_test_sk : @bigint.BigInt = msg_b16(
  "0000000000000000000000000000000000000000000000000000000000000001",
)

let msg_test_addr : Bytes = msg_h("0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf")

///|
/// Recover the signer's address from a SignedMessage and a 32-byte digest.
fn recover_address_from_signed(
  digest : Bytes,
  sig : @msg.SignedMessage,
) -> Bytes {
  // v is one byte: 0x1B (parity 0) or 0x1C (parity 1).
  if sig.v.length() != 1 {
    abort("v must be exactly one byte")
  }
  let parity = if sig.v[0] == b'\x1b' {
    0
  } else if sig.v[0] == b'\x1c' {
    1
  } else {
    abort("v must be 0x1B or 0x1C")
  }
  let r_int = @bigint.BigInt::from_octets(sig.r)
  let s_int = @bigint.BigInt::from_octets(sig.s)
  let ecdsa_sig : @secp256k1.EcdsaSig = { r: r_int, s: s_int, recid: parity }
  match @secp256k1.recover(digest, ecdsa_sig) {
    Some(pk) => {
      let xy = @secp256k1.pubkey_to_xy_bytes(pk)
      msg_unwrap_addr(@address.from_pubkey_xy(xy))
    }
    None => abort("recover failed")
  }
}

// ---- int_to_ascii_decimal ----

test "int_to_ascii_decimal: 0 → b\"0\"" {
  assert_eq(@msg.int_to_ascii_decimal(0), b"0")
}

test "int_to_ascii_decimal: 5 → b\"5\"" {
  assert_eq(@msg.int_to_ascii_decimal(5), b"5")
}

test "int_to_ascii_decimal: 13 → b\"13\"" {
  assert_eq(@msg.int_to_ascii_decimal(13), b"13")
}

test "int_to_ascii_decimal: 100 → b\"100\"" {
  assert_eq(@msg.int_to_ascii_decimal(100), b"100")
}

test "int_to_ascii_decimal: 1234567890 → b\"1234567890\"" {
  assert_eq(@msg.int_to_ascii_decimal(1234567890), b"1234567890")
}

// ---- personal_message_hash ----

// Snapshot: keccak256(0x19 || "Ethereum Signed Message:\n5" || "hello").
// Recorded from the current implementation. Cross-check with viem if drift
// is suspected.
test "personal_message_hash: snapshot for b\"hello\"" {
  let h = @msg.personal_message_hash(b"hello")
  let expected = msg_h(
    "0x50b2c43fd39106bafbba0da34fc430e1f91e3c96ea2acee2bc34119f92b37750",
  )
  assert_eq(h, expected)
}

test "personal_message_hash: deterministic for same message" {
  let h1 = @msg.personal_message_hash(b"foo")
  let h2 = @msg.personal_message_hash(b"foo")
  assert_eq(h1, h2)
  assert_eq(h1.length(), 32)
}

test "personal_message_hash: empty message" {
  // prefix = "\x19Ethereum Signed Message:\n0", no message body
  let h = @msg.personal_message_hash(b"")
  assert_eq(h.length(), 32)
}

test "personal_message_hash: different messages → different hashes" {
  let h1 = @msg.personal_message_hash(b"hello")
  let h2 = @msg.personal_message_hash(b"world")
  assert_true(h1 != h2)
}

// ---- personal_sign: round-trip via recover ----

test "personal_sign: recover yields original signer's address" {
  let message = b"hello"
  let sig = @msg.personal_sign(msg_test_sk, message)
  let h = @msg.personal_message_hash(message)
  let addr = recover_address_from_signed(h, sig)
  assert_eq(addr, msg_test_addr)
}

test "personal_sign: r and s are exactly 32 bytes" {
  let sig = @msg.personal_sign(msg_test_sk, b"hello")
  assert_eq(sig.r.length(), 32)
  assert_eq(sig.s.length(), 32)
}

test "personal_sign: v is one byte and is 0x1B or 0x1C" {
  let sig = @msg.personal_sign(msg_test_sk, b"hello")
  assert_eq(sig.v.length(), 1)
  let v = sig.v[0]
  assert_true(v == b'\x1b' || v == b'\x1c')
}

test "personal_sign: deterministic for same (sk, message)" {
  let s1 = @msg.personal_sign(msg_test_sk, b"hello")
  let s2 = @msg.personal_sign(msg_test_sk, b"hello")
  assert_eq(s1.r, s2.r)
  assert_eq(s1.s, s2.s)
  assert_eq(s1.v, s2.v)
}

test "personal_sign: different messages → different signatures" {
  let s1 = @msg.personal_sign(msg_test_sk, b"hello")
  let s2 = @msg.personal_sign(msg_test_sk, b"world")
  // r will differ (depends on hash via RFC6979 nonce).
  assert_true(s1.r != s2.r || s1.s != s2.s)
}

test "personal_sign: empty message round-trips" {
  let sig = @msg.personal_sign(msg_test_sk, b"")
  let h = @msg.personal_message_hash(b"")
  let addr = recover_address_from_signed(h, sig)
  assert_eq(addr, msg_test_addr)
}

test "personal_sign: long message (101 bytes) round-trips" {
  // Forces decimal-length encoding of "101" (3 ASCII digits).
  let arr : Array[Byte] = Array::make(101, b'\x41') // 'A' x 101
  let message = Bytes::from_array(arr[:])
  let sig = @msg.personal_sign(msg_test_sk, message)
  let h = @msg.personal_message_hash(message)
  let addr = recover_address_from_signed(h, sig)
  assert_eq(addr, msg_test_addr)
}

// ---- typed_data_digest ----

test "typed_data_digest: deterministic" {
  let ds = @keccak.keccak256(b"domain")
  let sh = @keccak.keccak256(b"struct")
  let d1 = @msg.typed_data_digest(ds, sh)
  let d2 = @msg.typed_data_digest(ds, sh)
  assert_eq(d1, d2)
  assert_eq(d1.length(), 32)
}

test "typed_data_digest: different inputs → different digests" {
  let ds = @keccak.keccak256(b"domain")
  let sh1 = @keccak.keccak256(b"struct1")
  let sh2 = @keccak.keccak256(b"struct2")
  let d1 = @msg.typed_data_digest(ds, sh1)
  let d2 = @msg.typed_data_digest(ds, sh2)
  assert_true(d1 != d2)
}

// ---- sign_typed_data: round-trip via recover ----

test "sign_typed_data: recover yields original signer's address" {
  let ds = @keccak.keccak256(b"domain")
  let sh = @keccak.keccak256(b"struct")
  let sig = @msg.sign_typed_data(msg_test_sk, ds, sh)
  let digest = @msg.typed_data_digest(ds, sh)
  let addr = recover_address_from_signed(digest, sig)
  assert_eq(addr, msg_test_addr)
}

test "sign_typed_data: r and s are exactly 32 bytes" {
  let ds = @keccak.keccak256(b"domain")
  let sh = @keccak.keccak256(b"struct")
  let sig = @msg.sign_typed_data(msg_test_sk, ds, sh)
  assert_eq(sig.r.length(), 32)
  assert_eq(sig.s.length(), 32)
}

test "sign_typed_data: v is 0x1B or 0x1C" {
  let ds = @keccak.keccak256(b"domain")
  let sh = @keccak.keccak256(b"struct")
  let sig = @msg.sign_typed_data(msg_test_sk, ds, sh)
  assert_eq(sig.v.length(), 1)
  let v = sig.v[0]
  assert_true(v == b'\x1b' || v == b'\x1c')
}

test "sign_typed_data: deterministic" {
  let ds = @keccak.keccak256(b"domain")
  let sh = @keccak.keccak256(b"struct")
  let s1 = @msg.sign_typed_data(msg_test_sk, ds, sh)
  let s2 = @msg.sign_typed_data(msg_test_sk, ds, sh)
  assert_eq(s1.r, s2.r)
  assert_eq(s1.s, s2.s)
  assert_eq(s1.v, s2.v)
}
