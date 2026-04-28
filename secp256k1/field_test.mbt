fn b16(s : String) -> @bigint.BigInt {
  @bigint.BigInt::from_string(s, radix=16)
}

fn bi(n : Int) -> @bigint.BigInt {
  @bigint.BigInt::from_int(n)
}

let pm1 : @bigint.BigInt = b16(
  "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2E",
)

// ---- p value ----

test "p value: matches 2^256 - 2^32 - 977" {
  let two256 = bi(2).pow(bi(256))
  let two32 = bi(2).pow(bi(32))
  let p_calc = two256 - two32 - bi(977)
  assert_eq(@secp256k1.p, p_calc)
}

// ---- addition ----

test "fadd: 0 + 0 = 0" {
  assert_eq(@secp256k1.fadd(bi(0), bi(0)), bi(0))
}

test "fadd: (p-1) + 1 = 0" {
  assert_eq(@secp256k1.fadd(pm1, bi(1)), bi(0))
}

test "fadd: (p-1) + (p-1) = p-2" {
  let pm2 = b16(
    "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2D",
  )
  assert_eq(@secp256k1.fadd(pm1, pm1), pm2)
}

// ---- subtraction ----

test "fsub: 0 - 1 = p-1" {
  assert_eq(@secp256k1.fsub(bi(0), bi(1)), pm1)
}

test "fsub: a - a = 0" {
  let a = b16("0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF")
  assert_eq(@secp256k1.fsub(a, a), bi(0))
}

// ---- negation ----

test "fneg: -0 = 0" {
  assert_eq(@secp256k1.fneg(bi(0)), bi(0))
}

test "fneg: -1 = p-1" {
  assert_eq(@secp256k1.fneg(bi(1)), pm1)
}

test "fneg: a + (-a) = 0" {
  let a = b16("BEEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890AB")
  assert_eq(@secp256k1.fadd(a, @secp256k1.fneg(a)), bi(0))
}

// ---- multiplication ----

test "fmul: 0 * x = 0" {
  let x = b16("DEADBEEF00000000DEADBEEF00000000DEADBEEF00000000DEADBEEF00000000")
  assert_eq(@secp256k1.fmul(bi(0), x), bi(0))
}

test "fmul: 1 * x = x" {
  let x = b16("DEADBEEF00000000DEADBEEF00000000DEADBEEF00000000DEADBEEF00000000")
  assert_eq(@secp256k1.fmul(bi(1), x), x)
}

test "fmul: (p-1) * (p-1) = 1" {
  assert_eq(@secp256k1.fmul(pm1, pm1), bi(1))
}

// ---- square ----

test "fsquare: matches fmul(a, a)" {
  let a = b16("0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF")
  assert_eq(@secp256k1.fsquare(a), @secp256k1.fmul(a, a))
}

// ---- inverse ----

test "finv: 2 * inv(2) = 1" {
  assert_eq(@secp256k1.fmul(bi(2), @secp256k1.finv(bi(2))), bi(1))
}

test "finv: a * inv(a) = 1 for arbitrary a" {
  let a = b16("BEEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890AB")
  assert_eq(@secp256k1.fmul(a, @secp256k1.finv(a)), bi(1))
}

test "finv: inv(0) returns 0 (defined behavior)" {
  assert_eq(@secp256k1.finv(bi(0)), bi(0))
}

// ---- sqrt ----

test "fsqrt: sqrt(4)^2 = 4" {
  let r = @secp256k1.fsqrt(bi(4))
  assert_eq(@secp256k1.fsquare(r), bi(4))
}

test "fsqrt: sqrt(y^2)^2 = y^2 (roundtrip)" {
  let y = b16("0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF")
  let y2 = @secp256k1.fsquare(y)
  let s = @secp256k1.fsqrt(y2)
  assert_eq(@secp256k1.fsquare(s), y2)
}

// ---- generator point lies on curve ----

test "G satisfies y^2 = x^3 + 7" {
  let gx = b16(
    "79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798",
  )
  let gy = b16(
    "483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8",
  )
  let lhs = @secp256k1.fsquare(gy)
  let x3 = @secp256k1.fmul(@secp256k1.fsquare(gx), gx)
  let rhs = @secp256k1.fadd(x3, @secp256k1.b)
  assert_eq(lhs, rhs)
}

// ---- byte conversion ----

test "from_bytes_be / to_bytes_be roundtrip" {
  let bytes = b"\x01\x23\x45\x67\x89\xAB\xCD\xEF\x01\x23\x45\x67\x89\xAB\xCD\xEF\x01\x23\x45\x67\x89\xAB\xCD\xEF\x01\x23\x45\x67\x89\xAB\xCD\xEF"
  let v = @secp256k1.from_bytes_be(bytes)
  assert_eq(@secp256k1.to_bytes_be(v), bytes)
}

test "to_bytes_be: zero is 32 zero bytes" {
  let z = @secp256k1.to_bytes_be(bi(0))
  assert_eq(z.length(), 32)
  for i = 0; i < 32; i = i + 1 {
    assert_eq(z[i], b'\x00')
  }
}
