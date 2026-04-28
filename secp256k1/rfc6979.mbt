// RFC 6979 deterministic nonce derivation for secp256k1 + SHA-256.
// Removes the need for a CSRNG at signing time and prevents nonce-reuse
// catastrophe when the same message is signed twice.

///|
/// Derive the nonce k from (private key, message hash). Returns k in [1, n-1].
///
/// `priv_octets` is the 32-byte big-endian private key.
/// `msg_hash` is the 32-byte message hash (for Ethereum: keccak256 of the
/// signed payload). RFC 6979 treats this as the raw hash; we reduce it mod n
/// when building the HMAC input as required by `bits2octets`.
pub fn rfc6979_k(priv_octets : Bytes, msg_hash : Bytes) -> @bigint.BigInt {
  let z = reduce_scalar(@bigint.BigInt::from_octets(msg_hash))
  let h1_oct = z.to_octets(length=32)
  // Step b: V = 0x01..01 (32 bytes)
  let v0 = Bytes::make(32, b'\x01')
  // Step c: K = 0x00..00 (32 bytes)
  let k0 = Bytes::make(32, b'\x00')
  // Step d: K = HMAC_K(V || 0x00 || int2octets(x) || bits2octets(h1))
  let k1 = @sha256.hmac(
    k0,
    @bytesx.concat([v0, b"\x00", priv_octets, h1_oct]),
  )
  // Step e: V = HMAC_K(V)
  let v1 = @sha256.hmac(k1, v0)
  // Step f: K = HMAC_K(V || 0x01 || int2octets(x) || bits2octets(h1))
  let k2 = @sha256.hmac(
    k1,
    @bytesx.concat([v1, b"\x01", priv_octets, h1_oct]),
  )
  // Step g: V = HMAC_K(V)
  let v2 = @sha256.hmac(k2, v1)
  // Step h: generate candidates until 1 <= k < n.
  // For secp256k1, rejection probability is ~2^-128, so the first iteration
  // succeeds with overwhelming probability.
  let mut k_state = k2
  let mut v_state = v2
  let mut found = false
  let mut result = zero
  while !found {
    v_state = @sha256.hmac(k_state, v_state)
    let cand = @bigint.BigInt::from_octets(v_state)
    if cand >= one && cand < n {
      result = cand
      found = true
    } else {
      k_state = @sha256.hmac(
        k_state,
        @bytesx.concat([v_state, b"\x00"]),
      )
      v_state = @sha256.hmac(k_state, v_state)
    }
  }
  result
}
