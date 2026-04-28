// Test vectors for RFC 6979 + secp256k1 + SHA-256.
// Sources: widely-cited community vectors used by python-ecdsa, noble-secp256k1.
// We cross-check the SHA-256 of the message string by computing it in-test.

fn r_b16(s : String) -> @bigint.BigInt {
  @bigint.BigInt::from_string(s, radix=16)
}

fn r_h(s : String) -> Bytes {
  match @hex.decode(s) {
    Ok(b) => b
    Err(_) => abort("invalid hex literal")
  }
}

// Test vectors from python-ecdsa / community:
// priv = 0xC9AFA9D845BA75166B5C215767B1D6934E50C3DB36E89B127B8A622B120F6721
// msg = "sample" → expected_k = 0xA6E3C57DD01ABE90086538398355DD4C3B17AA873382B0F24D6129493D8AAD60
// msg = "test"   → expected_k = 0xD30017BBBB9E1142EFEEEEED5302C2C61F47CDDA9B7BE7E03DEFB1B40FBA1864

test "RFC 6979: standard secp256k1+SHA256 vector, msg='sample'" {
  let sk = r_b16(
    "C9AFA9D845BA75166B5C215767B1D6934E50C3DB36E89B127B8A622B120F6721",
  )
  let priv_oct = sk.to_octets(length=32)
  let msg_hash = @sha256.sha256(b"sample")
  // Sanity: known SHA-256 of "sample"
  assert_eq(
    msg_hash,
    r_h("0xaf2bdbe1aa9b6ec1e2ade1d694f41fc71a831d0268e9891562113d8a62add1bf"),
  )
  let k = @secp256k1.rfc6979_k(priv_oct, msg_hash)
  assert_eq(
    k,
    r_b16("A6E3C57DD01ABE90086538398355DD4C3B17AA873382B0F24D6129493D8AAD60"),
  )
}

// "test" produces a different k than "sample" (collision-free property);
// we exercise full ECDSA against viem-derived signatures in ecdsa_test.mbt
// for cross-library coverage.

test "RFC 6979: deterministic — same input produces same k" {
  let sk = r_b16(
    "C9AFA9D845BA75166B5C215767B1D6934E50C3DB36E89B127B8A622B120F6721",
  )
  let priv_oct = sk.to_octets(length=32)
  let hash = r_h("0x4b688df40bcedbe641ddb16ff0a1842d9c67ea1c3bf63f3e0471baa664531d1a")
  let k1 = @secp256k1.rfc6979_k(priv_oct, hash)
  let k2 = @secp256k1.rfc6979_k(priv_oct, hash)
  assert_eq(k1, k2)
}

test "RFC 6979: different messages produce different k" {
  let sk = r_b16(
    "0000000000000000000000000000000000000000000000000000000000000001",
  )
  let priv_oct = sk.to_octets(length=32)
  let h1 = @sha256.sha256(b"sample")
  let h2 = @sha256.sha256(b"test")
  let k1 = @secp256k1.rfc6979_k(priv_oct, h1)
  let k2 = @secp256k1.rfc6979_k(priv_oct, h2)
  assert_true(k1 != k2)
}

test "RFC 6979: k is in valid range [1, n-1]" {
  let sk = r_b16(
    "DC87789B9CFE1FAD3D8B5B49EE9F0CFA02F50B47C46D547EBE0AB7E1AC75B86C",
  )
  let priv_oct = sk.to_octets(length=32)
  let hash = @sha256.sha256(b"abc")
  let k = @secp256k1.rfc6979_k(priv_oct, hash)
  assert_true(@secp256k1.is_valid_scalar(k))
}
