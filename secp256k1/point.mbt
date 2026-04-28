// secp256k1 elliptic-curve point arithmetic.
//
// Internal representation: Jacobian coordinates (X, Y, Z) representing the
// affine point (X / Z^2, Y / Z^3) when Z != 0; the point at infinity when Z == 0.
//
// Curve: y^2 = x^3 + 7 over F_p. a = 0.
//
// Scalar multiplication uses the Montgomery ladder, which performs the same
// add+double sequence regardless of bit value (algorithmic constant time at
// the structural level). The underlying field ops are NOT constant-time; see
// SECURITY.md.

///|
pub(all) struct Point {
  x : @bigint.BigInt
  y : @bigint.BigInt
  z : @bigint.BigInt // Z = 0 marks point at infinity
}

///|
/// Generator point G of secp256k1, in Jacobian (Z = 1).
pub let g : Point = {
  x: @bigint.BigInt::from_string(
    "79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798",
    radix=16,
  ),
  y: @bigint.BigInt::from_string(
    "483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8",
    radix=16,
  ),
  z: one,
}

///|
/// Point at infinity (additive identity).
pub let infinity : Point = { x: one, y: one, z: zero }

///|
pub fn is_infinity(p : Point) -> Bool {
  p.z == zero
}

///|
/// Convert Jacobian Point to affine (x, y). Returns (0, 0) for infinity;
/// caller must guard with `is_infinity`.
pub fn to_affine(p : Point) -> (@bigint.BigInt, @bigint.BigInt) {
  if is_infinity(p) {
    return (zero, zero)
  }
  let zi = finv(p.z)
  let zi2 = fsquare(zi)
  let zi3 = fmul(zi2, zi)
  (fmul(p.x, zi2), fmul(p.y, zi3))
}

///|
/// True if p satisfies the curve equation (handles Jacobian: y^2 = x^3 + b*z^6).
/// Returns true for the point at infinity.
pub fn on_curve(p : Point) -> Bool {
  if is_infinity(p) {
    return true
  }
  let y2 = fsquare(p.y)
  let x3 = fmul(fsquare(p.x), p.x)
  let z2 = fsquare(p.z)
  let z6 = fmul(fsquare(z2), z2)
  let rhs = fadd(x3, fmul(b, z6))
  y2 == rhs
}

///|
/// Equality of two Jacobian points (compares the affine projections).
pub fn point_eq(a : Point, q : Point) -> Bool {
  let ai = is_infinity(a)
  let bi = is_infinity(q)
  if ai && bi {
    return true
  }
  if ai || bi {
    return false
  }
  let z2a = fsquare(a.z)
  let z2b = fsquare(q.z)
  let z3a = fmul(z2a, a.z)
  let z3b = fmul(z2b, q.z)
  fmul(a.x, z2b) == fmul(q.x, z2a) && fmul(a.y, z3b) == fmul(q.y, z3a)
}

///|
pub fn point_neg(p : Point) -> Point {
  if is_infinity(p) {
    return p
  }
  { x: p.x, y: fneg(p.y), z: p.z }
}

///|
/// Doubling for y^2 = x^3 + b (a = 0). Standard Jacobian formula.
pub fn point_double(p : Point) -> Point {
  if is_infinity(p) {
    return infinity
  }
  if p.y == zero {
    return infinity
  }
  let three = @bigint.BigInt::from_int(3)
  let eight = @bigint.BigInt::from_int(8)
  let a = fsquare(p.x)
  let bb = fsquare(p.y)
  let c = fsquare(bb)
  let xpb = fadd(p.x, bb)
  let d = fmul(two, fsub(fsub(fsquare(xpb), a), c))
  let e = fmul(three, a)
  let f = fsquare(e)
  let x3 = fsub(f, fmul(two, d))
  let y3 = fsub(fmul(e, fsub(d, x3)), fmul(eight, c))
  let z3 = fmul(fmul(two, p.y), p.z)
  { x: x3, y: y3, z: z3 }
}

///|
/// Addition of two Jacobian points. Handles all cases including identity,
/// equal points (delegates to double), and inverse points (returns infinity).
pub fn point_add(p : Point, q : Point) -> Point {
  if is_infinity(p) {
    return q
  }
  if is_infinity(q) {
    return p
  }
  let z1z1 = fsquare(p.z)
  let z2z2 = fsquare(q.z)
  let u1 = fmul(p.x, z2z2)
  let u2 = fmul(q.x, z1z1)
  let s1 = fmul(fmul(p.y, q.z), z2z2)
  let s2 = fmul(fmul(q.y, p.z), z1z1)
  if u1 == u2 {
    if s1 != s2 {
      return infinity
    }
    return point_double(p)
  }
  let h = fsub(u2, u1)
  let i = fsquare(fmul(two, h))
  let j = fmul(h, i)
  let r = fmul(two, fsub(s2, s1))
  let v = fmul(u1, i)
  let x3 = fsub(fsub(fsquare(r), j), fmul(two, v))
  let y3 = fsub(fmul(r, fsub(v, x3)), fmul(two, fmul(s1, j)))
  let zsum_sq = fsquare(fadd(p.z, q.z))
  let z3 = fmul(fsub(fsub(zsum_sq, z1z1), z2z2), h)
  { x: x3, y: y3, z: z3 }
}

///|
/// k * p via Montgomery ladder. Iterates a fixed 256 bits regardless of k's
/// magnitude (so the loop count does not leak the bit length of k).
///
/// Caller must ensure 0 <= k < 2^256. For curve-meaningful results pass
/// k in [0, n).
pub fn point_mul(k : @bigint.BigInt, p : Point) -> Point {
  let kb = k.to_octets(length=32)
  let mut r0 = infinity
  let mut r1 = p
  for i = 255; i >= 0; i = i - 1 {
    let byte_idx = 31 - i / 8
    let bit_idx = i % 8
    let bit = (kb[byte_idx].to_int() >> bit_idx) & 1
    if bit == 0 {
      r1 = point_add(r0, r1)
      r0 = point_double(r0)
    } else {
      r0 = point_add(r0, r1)
      r1 = point_double(r1)
    }
  }
  r0
}

///|
/// Convenience: k * G.
pub fn mul_g(k : @bigint.BigInt) -> Point {
  point_mul(k, g)
}
