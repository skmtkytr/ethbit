fn s_b16(s : String) -> @bigint.BigInt {
  @bigint.BigInt::from_string(s, radix=16)
}

fn s_bi(n : Int) -> @bigint.BigInt {
  @bigint.BigInt::from_int(n)
}

let nm1 : @bigint.BigInt = s_b16(
  "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364140",
)

// ---- n value ----

test "n value: 256-bit and matches known constant" {
  assert_eq(@secp256k1.n.bit_length(), 256)
  // High 128 bits are 0xFF...FE, low 128 bits are 0xBAAEDCE6...41
  let high = @secp256k1.n / s_bi(2).pow(s_bi(128))
  let expected_high = s_b16("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE")
  assert_eq(high, expected_high)
}

test "n is less than p (n is a divisor of curve points + identity)" {
  assert_true(@secp256k1.n < @secp256k1.p)
}

// ---- nadd ----

test "nadd: 0 + 0 = 0" {
  assert_eq(@secp256k1.nadd(s_bi(0), s_bi(0)), s_bi(0))
}

test "nadd: (n-1) + 1 = 0" {
  assert_eq(@secp256k1.nadd(nm1, s_bi(1)), s_bi(0))
}

// ---- nsub ----

test "nsub: 0 - 1 = n-1" {
  assert_eq(@secp256k1.nsub(s_bi(0), s_bi(1)), nm1)
}

test "nsub: a - a = 0" {
  let a = s_b16("0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF")
  assert_eq(@secp256k1.nsub(a, a), s_bi(0))
}

// ---- nneg ----

test "nneg: -1 = n-1" {
  assert_eq(@secp256k1.nneg(s_bi(1)), nm1)
}

test "nneg: a + (-a) = 0" {
  let a = s_b16("BEEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890AB")
  assert_eq(@secp256k1.nadd(a, @secp256k1.nneg(a)), s_bi(0))
}

// ---- nmul ----

test "nmul: 1 * a = a (when a < n)" {
  let a = s_b16("00000000000000000000000000000000BEEF1234567890ABCDEF1234567890AB")
  assert_eq(@secp256k1.nmul(s_bi(1), a), a)
}

test "nmul: (n-1) * (n-1) = 1" {
  assert_eq(@secp256k1.nmul(nm1, nm1), s_bi(1))
}

// ---- ninv ----

test "ninv: 1 * inv(1) = 1" {
  assert_eq(@secp256k1.nmul(s_bi(1), @secp256k1.ninv(s_bi(1))), s_bi(1))
}

test "ninv: 2 * inv(2) = 1" {
  assert_eq(@secp256k1.nmul(s_bi(2), @secp256k1.ninv(s_bi(2))), s_bi(1))
}

test "ninv: a * inv(a) = 1 for arbitrary a < n" {
  let a = s_b16("00000000000000000000000000000000BEEF1234567890ABCDEF1234567890AB")
  assert_eq(@secp256k1.nmul(a, @secp256k1.ninv(a)), s_bi(1))
}

test "ninv: inv(0) returns 0 (defined behavior)" {
  assert_eq(@secp256k1.ninv(s_bi(0)), s_bi(0))
}

test "ninv: inv(n-1) = n-1 since (n-1)^2 = 1 mod n" {
  assert_eq(@secp256k1.ninv(nm1), nm1)
}

// ---- reduce_scalar ----

test "reduce_scalar: identity for x in [0, n)" {
  let a = s_b16("00000000000000000000000000000000BEEF1234567890ABCDEF1234567890AB")
  assert_eq(@secp256k1.reduce_scalar(a), a)
}

test "reduce_scalar: n maps to 0" {
  assert_eq(@secp256k1.reduce_scalar(@secp256k1.n), s_bi(0))
}

test "reduce_scalar: 2n maps to 0" {
  let two_n = @secp256k1.n + @secp256k1.n
  assert_eq(@secp256k1.reduce_scalar(two_n), s_bi(0))
}

test "reduce_scalar: -1 maps to n-1" {
  assert_eq(@secp256k1.reduce_scalar(s_bi(-1)), nm1)
}

// ---- is_valid_scalar ----

test "is_valid_scalar: 0 is invalid" {
  assert_eq(@secp256k1.is_valid_scalar(s_bi(0)), false)
}

test "is_valid_scalar: 1 is valid" {
  assert_eq(@secp256k1.is_valid_scalar(s_bi(1)), true)
}

test "is_valid_scalar: n-1 is valid" {
  assert_eq(@secp256k1.is_valid_scalar(nm1), true)
}

test "is_valid_scalar: n is invalid" {
  assert_eq(@secp256k1.is_valid_scalar(@secp256k1.n), false)
}

test "is_valid_scalar: 2n is invalid" {
  let two_n = @secp256k1.n + @secp256k1.n
  assert_eq(@secp256k1.is_valid_scalar(two_n), false)
}
