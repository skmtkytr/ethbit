// High-level secp256k1 facade: private-key → public-key, public-key encoding
// in SEC1 forms (uncompressed 65B / compressed 33B), and decoding.

///|
/// Derive the public-key point from a private key (1 <= sk < n).
pub fn pubkey_from_sk(sk : @bigint.BigInt) -> Point {
  mul_g(sk)
}

///|
/// SEC1 uncompressed encoding: 0x04 || x (32B) || y (32B).
pub fn pubkey_to_uncompressed(pk : Point) -> Bytes {
  if is_infinity(pk) {
    abort("pubkey_to_uncompressed: point at infinity has no encoding")
  }
  let (x, y) = to_affine(pk)
  @bytesx.concat([b"\x04", x.to_octets(length=32), y.to_octets(length=32)])
}

///|
/// SEC1 uncompressed body without the leading 0x04 tag: x (32B) || y (32B),
/// total 64 bytes. This is the form Ethereum hashes with keccak256 to derive
/// an address.
pub fn pubkey_to_xy_bytes(pk : Point) -> Bytes {
  if is_infinity(pk) {
    abort("pubkey_to_xy_bytes: point at infinity has no encoding")
  }
  let (x, y) = to_affine(pk)
  @bytesx.concat([x.to_octets(length=32), y.to_octets(length=32)])
}

///|
/// SEC1 compressed encoding: 0x02 || x  (when y is even)
///                          or 0x03 || x  (when y is odd).
pub fn pubkey_to_compressed(pk : Point) -> Bytes {
  if is_infinity(pk) {
    abort("pubkey_to_compressed: point at infinity has no encoding")
  }
  let (x, y) = to_affine(pk)
  let prefix = if (y & one) == one {
    b"\x03"
  } else {
    b"\x02"
  }
  @bytesx.concat([prefix, x.to_octets(length=32)])
}

///|
/// Decode a SEC1 public-key encoding (33B compressed or 65B uncompressed).
/// Returns None on length mismatch, bad tag, off-curve point, or no real y.
pub fn pubkey_from_bytes(bytes : Bytes) -> Point? {
  let len = bytes.length()
  if len == 65 && bytes[0] == b'\x04' {
    let x = @bigint.BigInt::from_octets(@bytesx.slice(bytes, 1, 33))
    let y = @bigint.BigInt::from_octets(@bytesx.slice(bytes, 33, 65))
    let pk : Point = { x, y, z: one }
    if on_curve(pk) {
      Some(pk)
    } else {
      None
    }
  } else if len == 33 && (bytes[0] == b'\x02' || bytes[0] == b'\x03') {
    let x = @bigint.BigInt::from_octets(@bytesx.slice(bytes, 1, 33))
    let want_parity = if bytes[0] == b'\x03' {
      1
    } else {
      0
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
    let y = if beta_parity == want_parity {
      beta
    } else {
      fsub(p, beta)
    }
    let pk : Point = { x, y, z: one }
    if on_curve(pk) {
      Some(pk)
    } else {
      None
    }
  } else {
    None
  }
}
