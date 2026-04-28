// Tests for EIP-4844 (blob, type 3) transaction encoding and signing.
// We do not have stable cross-impl reference vectors here; tests verify
// structural invariants and end-to-end correctness via signature recovery.

fn b4844_h(s : String) -> Bytes {
  match @hex.decode(s) {
    Ok(b) => b
    Err(_) => abort("invalid hex literal in test")
  }
}

fn b4844_b16(s : String) -> @bigint.BigInt {
  @bigint.BigInt::from_string(s, radix=16)
}

let b4844_test_sk : @bigint.BigInt = b4844_b16(
  "0000000000000000000000000000000000000000000000000000000000000001",
)

let b4844_test_addr : Bytes = b4844_h("0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf")

// A versioned hash: 0x01 (KZG version) followed by 31 zero bytes.
fn b4844_sample_versioned_hash() -> Bytes {
  b4844_h("0x0100000000000000000000000000000000000000000000000000000000000000")
}

fn b4844_make() -> @tx.Tx4844 {
  {
    chain_id: b4844_h("0x01"),
    nonce: b"",
    max_priority_fee_per_gas: b4844_h("0x59682f00"),
    max_fee_per_gas: b4844_h("0x06fc23ac00"),
    gas_limit: b4844_h("0x5208"),
    to: b4844_h("0x52908400098527886E0F7030069857D2E4169EE7"),
    value: b4844_h("0x0de0b6b3a7640000"),
    data: b"",
    access_list: [],
    max_fee_per_blob_gas: b4844_h("0x3b9aca00"),
    blob_versioned_hashes: [b4844_sample_versioned_hash()],
  }
}

fn b4844_unwrap_addr(r : Result[Bytes, @address.AddressError]) -> Bytes {
  match r {
    Ok(a) => a
    Err(_) => abort("expected Ok in test")
  }
}

test "encode_unsigned_4844: starts with 0x03 and has plausible length" {
  let tx = b4844_make()
  let bytes = @tx.encode_unsigned_4844(tx)
  assert_true(bytes.length() > 0)
  // Type byte prefix
  assert_eq(bytes[0].to_int(), 0x03)
  // Sanity: should be longer than just the type byte + an empty list.
  assert_true(bytes.length() > 32)
}

test "hash_unsigned_4844: returns 32 bytes" {
  let tx = b4844_make()
  let h = @tx.hash_unsigned_4844(tx)
  assert_eq(h.length(), 32)
}

test "sign_4844: recover yields original signer's address" {
  let tx = b4844_make()
  let sig = @tx.sign_4844(tx, b4844_test_sk)
  let h = @tx.hash_unsigned_4844(tx)
  // For 4844: v is yParity directly (0 -> b"", 1 -> b"\x01").
  let parity = if sig.v.length() == 0 {
    0
  } else {
    sig.v[0].to_int()
  }
  let r_int = @bigint.BigInt::from_octets(sig.r)
  let s_int = @bigint.BigInt::from_octets(sig.s)
  let ecdsa_sig : @secp256k1.EcdsaSig = { r: r_int, s: s_int, recid: parity }
  match @secp256k1.recover(h, ecdsa_sig) {
    Some(pk) => {
      let xy = @secp256k1.pubkey_to_xy_bytes(pk)
      let addr = b4844_unwrap_addr(@address.from_pubkey_xy(xy))
      assert_eq(addr, b4844_test_addr)
    }
    None => assert_true(false)
  }
}

test "sign_4844 is deterministic" {
  let tx = b4844_make()
  let s1 = @tx.sign_4844(tx, b4844_test_sk)
  let s2 = @tx.sign_4844(tx, b4844_test_sk)
  assert_eq(s1.v, s2.v)
  assert_eq(s1.r, s2.r)
  assert_eq(s1.s, s2.s)
}

test "sign_and_encode_4844: equals encode_signed_4844(sign_4844(...))" {
  let tx = b4844_make()
  let bytes = @tx.sign_and_encode_4844(tx, b4844_test_sk)
  let sig = @tx.sign_4844(tx, b4844_test_sk)
  assert_eq(bytes, @tx.encode_signed_4844(tx, sig))
}

test "sign_4844: v is yParity (b\"\" or b\"\\x01\")" {
  let tx = b4844_make()
  let sig = @tx.sign_4844(tx, b4844_test_sk)
  let ok = sig.v == b"" || sig.v == b"\x01"
  assert_true(ok)
}

test "encode_unsigned_4844: works structurally with multiple blob hashes" {
  let mut tx = b4844_make()
  tx = {
    ..tx,
    blob_versioned_hashes: [
      b4844_sample_versioned_hash(),
      b4844_h("0x010102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"),
    ],
  }
  let bytes = @tx.encode_unsigned_4844(tx)
  // Type byte still 0x03
  assert_eq(bytes[0].to_int(), 0x03)
  // Single-hash encoding length should be strictly less than two-hash.
  let single = @tx.encode_unsigned_4844(b4844_make())
  assert_true(bytes.length() > single.length())
  // Hash still 32 bytes regardless of how many blob hashes are present.
  assert_eq(@tx.hash_unsigned_4844(tx).length(), 32)
  // Sign + recover continues to work end-to-end with multiple hashes.
  let sig = @tx.sign_4844(tx, b4844_test_sk)
  let h = @tx.hash_unsigned_4844(tx)
  let parity = if sig.v.length() == 0 {
    0
  } else {
    sig.v[0].to_int()
  }
  let r_int = @bigint.BigInt::from_octets(sig.r)
  let s_int = @bigint.BigInt::from_octets(sig.s)
  let ecdsa_sig : @secp256k1.EcdsaSig = { r: r_int, s: s_int, recid: parity }
  match @secp256k1.recover(h, ecdsa_sig) {
    Some(pk) => {
      let xy = @secp256k1.pubkey_to_xy_bytes(pk)
      let addr = b4844_unwrap_addr(@address.from_pubkey_xy(xy))
      assert_eq(addr, b4844_test_addr)
    }
    None => assert_true(false)
  }
}
