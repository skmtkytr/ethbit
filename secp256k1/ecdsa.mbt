// ECDSA over secp256k1 with deterministic nonces (RFC 6979) and low-s
// normalization (BIP 62 / EIP-2). Recovery id is the Ethereum convention:
//   bit 0 = yParity  (parity of R.y)
//   bit 1 = x_overflow  (1 iff R.x >= n; vanishingly rare)
//
// Inputs and outputs are BigInts in [1, n-1] for r and s. The private key is
// also a BigInt in [1, n-1]. Caller is responsible for hashing the payload
// (Ethereum convention: keccak256).

///|
pub(all) struct EcdsaSig {
  r : @bigint.BigInt
  s : @bigint.BigInt
  recid : Int
}

///|
/// Deterministic ECDSA signing.
///
/// `sk` must satisfy 1 <= sk < n; otherwise the result is unspecified.
/// `msg_hash` must be exactly 32 bytes.
pub fn sign(sk : @bigint.BigInt, msg_hash : Bytes) -> EcdsaSig {
  let sk_oct = sk.to_octets(length=32)
  let z = reduce_scalar(@bigint.BigInt::from_octets(msg_hash))
  let k = rfc6979_k(sk_oct, msg_hash)
  let r_pt = mul_g(k)
  let (rx, ry) = to_affine(r_pt)
  let r = reduce_scalar(rx)
  if r == zero {
    abort("ECDSA sign: r = 0 (probability ~2^-128, should be unreachable)")
  }
  let k_inv = ninv(k)
  let s_raw = nmul(k_inv, nadd(z, nmul(r, sk)))
  if s_raw == zero {
    abort("ECDSA sign: s = 0 (probability ~2^-256, should be unreachable)")
  }
  let half_n = n / two
  let mut s = s_raw
  let mut yflip = false
  if s_raw > half_n {
    s = nsub(n, s_raw)
    yflip = true
  }
  let parity_raw = if (ry & one) == one {
    1
  } else {
    0
  }
  let parity = if yflip {
    parity_raw ^ 1
  } else {
    parity_raw
  }
  let x_overflow = if rx >= n {
    1
  } else {
    0
  }
  let recid = (x_overflow << 1) | parity
  { r, s, recid }
}

///|
/// Verify a signature against the given public-key point.
pub fn verify_with_pubkey(
  pk : Point,
  msg_hash : Bytes,
  sig : EcdsaSig,
) -> Bool {
  if !is_valid_scalar(sig.r) || !is_valid_scalar(sig.s) {
    return false
  }
  let z = reduce_scalar(@bigint.BigInt::from_octets(msg_hash))
  let s_inv = ninv(sig.s)
  let u1 = nmul(z, s_inv)
  let u2 = nmul(sig.r, s_inv)
  let r_calc = point_add(point_mul(u1, g), point_mul(u2, pk))
  if is_infinity(r_calc) {
    return false
  }
  let (rx, _) = to_affine(r_calc)
  reduce_scalar(rx) == sig.r
}

///|
/// Recover the public-key point from a signature and message hash. Returns
/// None if the signature is malformed (r or s out of range, no y on curve,
/// recid implies x >= p).
pub fn recover(msg_hash : Bytes, sig : EcdsaSig) -> Point? {
  if !is_valid_scalar(sig.r) || !is_valid_scalar(sig.s) {
    return None
  }
  let yparity = sig.recid & 1
  let x_overflow = (sig.recid >> 1) & 1
  let x = if x_overflow == 1 {
    sig.r + n
  } else {
    sig.r
  }
  if x >= p {
    return None
  }
  let alpha = fadd(fmul(fsquare(x), x), b)
  let beta = fsqrt(alpha)
  if fsquare(beta) != alpha {
    return None
  }
  let beta_parity = if (beta & one) == one {
    1
  } else {
    0
  }
  let y = if beta_parity == yparity {
    beta
  } else {
    fsub(p, beta)
  }
  let r_pt : Point = { x, y, z: one }
  let z = reduce_scalar(@bigint.BigInt::from_octets(msg_hash))
  let r_inv = ninv(sig.r)
  let s_r = point_mul(sig.s, r_pt)
  let neg_zg = point_neg(mul_g(z))
  let diff = point_add(s_r, neg_zg)
  Some(point_mul(r_inv, diff))
}
