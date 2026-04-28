// secp256k1 scalar field F_n where n is the group order.
//
// n = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
//
// Used for: private keys, ECDSA signature components (r, s), RFC 6979 nonce.
// Operations are NOT constant-time. See SECURITY.md.
//
// Convention: all arguments and return values are reduced into [0, n).

///|
/// The secp256k1 group order.
pub let n : @bigint.BigInt = @bigint.BigInt::from_string(
  "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141",
  radix=16,
)

///|
fn reduce_n(x : @bigint.BigInt) -> @bigint.BigInt {
  let r = x % n
  if r < zero {
    r + n
  } else {
    r
  }
}

///|
pub fn nadd(a : @bigint.BigInt, b : @bigint.BigInt) -> @bigint.BigInt {
  reduce_n(a + b)
}

///|
pub fn nsub(a : @bigint.BigInt, b : @bigint.BigInt) -> @bigint.BigInt {
  reduce_n(a - b)
}

///|
pub fn nneg(a : @bigint.BigInt) -> @bigint.BigInt {
  reduce_n(-a)
}

///|
pub fn nmul(a : @bigint.BigInt, b : @bigint.BigInt) -> @bigint.BigInt {
  reduce_n(a * b)
}

///|
/// Modular inverse mod n via Fermat: a^(n-2) mod n. Defined for a != 0.
pub fn ninv(a : @bigint.BigInt) -> @bigint.BigInt {
  if a == zero {
    zero
  } else {
    a.pow(n - two, modulus=n)
  }
}

///|
/// Reduce an arbitrary BigInt into the scalar field [0, n).
pub fn reduce_scalar(x : @bigint.BigInt) -> @bigint.BigInt {
  reduce_n(x)
}

///|
/// True iff `a` is in [1, n-1]. Required for ECDSA signature components and
/// private keys.
pub fn is_valid_scalar(a : @bigint.BigInt) -> Bool {
  a > zero && a < n
}
