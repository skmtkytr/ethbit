// secp256k1 prime field F_p arithmetic.
//
// p = 2^256 - 2^32 - 977
//   = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F
//
// Implementation uses @bigint. Operations are NOT constant-time.
// See SECURITY.md for the threat model.
//
// Convention: all arguments and return values are reduced into [0, p).

///|
/// The secp256k1 field prime.
pub let p : @bigint.BigInt = @bigint.BigInt::from_string(
  "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F",
  radix=16,
)

///|
let zero : @bigint.BigInt = @bigint.BigInt::from_int(0)

///|
let one : @bigint.BigInt = @bigint.BigInt::from_int(1)

///|
let two : @bigint.BigInt = @bigint.BigInt::from_int(2)

///|
let four : @bigint.BigInt = @bigint.BigInt::from_int(4)

///|
/// Curve constant b in y^2 = x^3 + b. For secp256k1, b = 7.
pub let b : @bigint.BigInt = @bigint.BigInt::from_int(7)

///|
/// Reduce x to canonical [0, p).
fn reduce(x : @bigint.BigInt) -> @bigint.BigInt {
  let r = x % p
  if r < zero {
    r + p
  } else {
    r
  }
}

///|
pub fn fadd(a : @bigint.BigInt, b : @bigint.BigInt) -> @bigint.BigInt {
  reduce(a + b)
}

///|
pub fn fsub(a : @bigint.BigInt, b : @bigint.BigInt) -> @bigint.BigInt {
  reduce(a - b)
}

///|
pub fn fneg(a : @bigint.BigInt) -> @bigint.BigInt {
  reduce(-a)
}

///|
pub fn fmul(a : @bigint.BigInt, b : @bigint.BigInt) -> @bigint.BigInt {
  reduce(a * b)
}

///|
pub fn fsquare(a : @bigint.BigInt) -> @bigint.BigInt {
  reduce(a * a)
}

///|
/// Modular inverse via Fermat's little theorem: a^(p-2) mod p.
/// Defined for a != 0; calling with a = 0 yields 0.
pub fn finv(a : @bigint.BigInt) -> @bigint.BigInt {
  if a == zero {
    zero
  } else {
    a.pow(p - two, modulus=p)
  }
}

///|
/// Square root mod p. secp256k1 has p ≡ 3 (mod 4) so sqrt(a) = a^((p+1)/4).
/// Returns a value `r`; `r * r mod p == a` only when a is a quadratic residue.
/// Caller must verify by squaring.
pub fn fsqrt(a : @bigint.BigInt) -> @bigint.BigInt {
  let exp = (p + one) / four
  a.pow(exp, modulus=p)
}

///|
/// Decode a 32-byte big-endian payload as a field element. Does NOT reject
/// values >= p (the caller should validate if strictness is required).
pub fn from_bytes_be(b : Bytes) -> @bigint.BigInt {
  @bigint.BigInt::from_octets(b)
}

///|
/// Encode a field element as a 32-byte big-endian payload.
pub fn to_bytes_be(a : @bigint.BigInt) -> Bytes {
  a.to_octets(length=32)
}
