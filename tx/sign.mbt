// Transaction signing: derive a Signature for a TxLegacy or Tx1559 from a
// private key. Hashes the unsigned encoding with keccak256, then runs ECDSA
// (deterministic per RFC 6979) and packages r/s/v in the form expected by
// the existing encode_signed_* functions.
//
// v derivation:
//   - legacy (EIP-155):  v = chain_id * 2 + 35 + yParity
//   - 1559 / typed:      v = yParity (0 or 1; encoded as RLP integer so 0 = b"")
//
// We emit only the lower bit of recid for v. The recid bit 1 (R.x >= n) case
// has probability ~2^-128 and is effectively unreachable; it is silently
// ignored here. A higher-assurance impl would re-roll the nonce.

///|
fn bigint_to_rlp_bytes(x : @bigint.BigInt) -> Bytes {
  if x.is_zero() {
    b""
  } else {
    x.to_octets()
  }
}

///|
/// Sign a legacy (EIP-155) transaction. Returns the Signature ready to feed
/// into `encode_signed_legacy` / `hash_signed_legacy`.
pub fn sign_legacy(
  txn : TxLegacy,
  chain_id : Bytes,
  sk : @bigint.BigInt,
) -> Signature {
  let h = hash_unsigned_legacy(txn, chain_id)
  let sig = @secp256k1.sign(sk, h)
  let parity = sig.recid & 1
  let chain_id_int = @bigint.BigInt::from_octets(chain_id)
  let v_int = chain_id_int * @bigint.BigInt::from_int(2) +
    @bigint.BigInt::from_int(35 + parity)
  {
    v: bigint_to_rlp_bytes(v_int),
    r: bigint_to_rlp_bytes(sig.r),
    s: bigint_to_rlp_bytes(sig.s),
  }
}

///|
/// Sign an EIP-1559 (type-2) transaction. Returns the Signature ready to feed
/// into `encode_signed_1559` / `hash_signed_1559`.
pub fn sign_1559(txn : Tx1559, sk : @bigint.BigInt) -> Signature {
  let h = hash_unsigned_1559(txn)
  let sig = @secp256k1.sign(sk, h)
  let parity = sig.recid & 1
  let v = if parity == 0 {
    b""
  } else {
    b"\x01"
  }
  {
    v,
    r: bigint_to_rlp_bytes(sig.r),
    s: bigint_to_rlp_bytes(sig.s),
  }
}

///|
/// Sign and encode a legacy transaction in one call.
pub fn sign_and_encode_legacy(
  txn : TxLegacy,
  chain_id : Bytes,
  sk : @bigint.BigInt,
) -> Bytes {
  let sig = sign_legacy(txn, chain_id, sk)
  encode_signed_legacy(txn, sig)
}

///|
/// Sign and encode an EIP-1559 transaction in one call.
pub fn sign_and_encode_1559(txn : Tx1559, sk : @bigint.BigInt) -> Bytes {
  let sig = sign_1559(txn, sk)
  encode_signed_1559(txn, sig)
}

///|
/// Sign an EIP-4844 (type-3, blob) transaction. Returns the Signature ready to
/// feed into `encode_signed_4844` / `hash_signed_4844`.
pub fn sign_4844(txn : Tx4844, sk : @bigint.BigInt) -> Signature {
  let h = hash_unsigned_4844(txn)
  let sig = @secp256k1.sign(sk, h)
  let parity = sig.recid & 1
  let v = if parity == 0 {
    b""
  } else {
    b"\x01"
  }
  {
    v,
    r: bigint_to_rlp_bytes(sig.r),
    s: bigint_to_rlp_bytes(sig.s),
  }
}

///|
/// Sign and encode an EIP-4844 transaction in one call.
pub fn sign_and_encode_4844(txn : Tx4844, sk : @bigint.BigInt) -> Bytes {
  let sig = sign_4844(txn, sk)
  encode_signed_4844(txn, sig)
}
