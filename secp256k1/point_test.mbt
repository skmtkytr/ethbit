fn p_b16(s : String) -> @bigint.BigInt {
  @bigint.BigInt::from_string(s, radix=16)
}

fn p_bi(n : Int) -> @bigint.BigInt {
  @bigint.BigInt::from_int(n)
}

// ---- basics ----

test "G is on curve" {
  assert_true(@secp256k1.on_curve(@secp256k1.g))
}

test "infinity is on curve" {
  assert_true(@secp256k1.on_curve(@secp256k1.infinity))
}

test "is_infinity: G is not infinity" {
  assert_eq(@secp256k1.is_infinity(@secp256k1.g), false)
}

test "is_infinity: infinity is infinity" {
  assert_eq(@secp256k1.is_infinity(@secp256k1.infinity), true)
}

// ---- identity element ----

test "G + O = G" {
  let r = @secp256k1.point_add(@secp256k1.g, @secp256k1.infinity)
  assert_true(@secp256k1.point_eq(r, @secp256k1.g))
}

test "O + G = G" {
  let r = @secp256k1.point_add(@secp256k1.infinity, @secp256k1.g)
  assert_true(@secp256k1.point_eq(r, @secp256k1.g))
}

test "O + O = O" {
  let r = @secp256k1.point_add(@secp256k1.infinity, @secp256k1.infinity)
  assert_true(@secp256k1.is_infinity(r))
}

// ---- inverse ----

test "G + (-G) = O" {
  let neg_g = @secp256k1.point_neg(@secp256k1.g)
  let r = @secp256k1.point_add(@secp256k1.g, neg_g)
  assert_true(@secp256k1.is_infinity(r))
}

test "double(infinity) = infinity" {
  let r = @secp256k1.point_double(@secp256k1.infinity)
  assert_true(@secp256k1.is_infinity(r))
}

// ---- doubling vs. self-add ----

test "double(G) == add(G, G)" {
  let d = @secp256k1.point_double(@secp256k1.g)
  let s = @secp256k1.point_add(@secp256k1.g, @secp256k1.g)
  assert_true(@secp256k1.point_eq(d, s))
}

test "double(G) is on curve" {
  assert_true(@secp256k1.on_curve(@secp256k1.point_double(@secp256k1.g)))
}

// ---- known multiples of G (from SEC1 / Bitcoin) ----

test "2G affine matches known coordinates" {
  let two_g = @secp256k1.point_double(@secp256k1.g)
  let (x, y) = @secp256k1.to_affine(two_g)
  assert_eq(
    x,
    p_b16("C6047F9441ED7D6D3045406E95C07CD85C778E4B8CEF3CA7ABAC09B95C709EE5"),
  )
  assert_eq(
    y,
    p_b16("1AE168FEA63DC339A3C58419466CEAEEF7F632653266D0E1236431A950CFE52A"),
  )
}

test "3G affine matches known coordinates" {
  let three_g = @secp256k1.point_add(
    @secp256k1.point_double(@secp256k1.g),
    @secp256k1.g,
  )
  let (x, y) = @secp256k1.to_affine(three_g)
  assert_eq(
    x,
    p_b16("F9308A019258C31049344F85F89D5229B531C845836F99B08601F113BCE036F9"),
  )
  assert_eq(
    y,
    p_b16("388F7B0F632DE8140FE337E62A37F3566500A99934C2231B6CB9FD7584B8E672"),
  )
}

// ---- scalar multiplication ----

test "0 * G = O" {
  let r = @secp256k1.mul_g(p_bi(0))
  assert_true(@secp256k1.is_infinity(r))
}

test "1 * G = G" {
  let r = @secp256k1.mul_g(p_bi(1))
  assert_true(@secp256k1.point_eq(r, @secp256k1.g))
}

test "2 * G via mul matches double(G)" {
  let r = @secp256k1.mul_g(p_bi(2))
  let d = @secp256k1.point_double(@secp256k1.g)
  assert_true(@secp256k1.point_eq(r, d))
}

test "3 * G via mul matches add(2G, G)" {
  let r = @secp256k1.mul_g(p_bi(3))
  let three_g = @secp256k1.point_add(
    @secp256k1.point_double(@secp256k1.g),
    @secp256k1.g,
  )
  assert_true(@secp256k1.point_eq(r, three_g))
}

test "n * G = O (group order)" {
  let r = @secp256k1.mul_g(@secp256k1.n)
  assert_true(@secp256k1.is_infinity(r))
}

test "(n-1) * G = -G" {
  let nm1 = @secp256k1.n - p_bi(1)
  let r = @secp256k1.mul_g(nm1)
  let neg_g = @secp256k1.point_neg(@secp256k1.g)
  assert_true(@secp256k1.point_eq(r, neg_g))
}

test "k * G is on curve for arbitrary k" {
  let k = p_b16(
    "00000000000000000000000000000000BEEF1234567890ABCDEF1234567890AB",
  )
  let r = @secp256k1.mul_g(k)
  assert_true(@secp256k1.on_curve(r))
}

test "scalar mul distributes over addition: (a+b)*G = a*G + b*G" {
  let a = p_b16("000000000000000000000000000000000000000000000000000000000000000A")
  let b = p_b16("0000000000000000000000000000000000000000000000000000000000000007")
  let lhs = @secp256k1.mul_g(@secp256k1.nadd(a, b))
  let rhs = @secp256k1.point_add(@secp256k1.mul_g(a), @secp256k1.mul_g(b))
  assert_true(@secp256k1.point_eq(lhs, rhs))
}

test "scalar mul: known large k gives on-curve result" {
  let k = p_b16(
    "AA5E28D6A97A2479A65527F7290311A3624D4CC0FA1578598EE3C2613BF99522",
  )
  let r = @secp256k1.mul_g(k)
  assert_true(@secp256k1.on_curve(r))
  assert_eq(@secp256k1.is_infinity(r), false)
}

// ---- known scalar mul vector (Ethereum-style) ----
// Given priv = 0xc0...01, pub = (gx', gy') matches a known constant.
// Vector source: bitcoin/secp256k1 test vectors. Private key = 1 → pub = G.
// We already test 1*G = G; the next is priv = 0xb7e151628aed2a6abf7158809cf4f3c
// which is pi (sec1 test). Skip for now; viem-derived ECDSA tests in Phase 4
// will exercise scalar mul end-to-end.

test "private key 5: pub = 5G is on curve and matches affine y²=x³+7" {
  let sk = p_b16(
    "0000000000000000000000000000000000000000000000000000000000000005",
  )
  let pk = @secp256k1.mul_g(sk)
  assert_true(@secp256k1.on_curve(pk))
  let (px, py) = @secp256k1.to_affine(pk)
  let y2 = @secp256k1.fmul(py, py)
  let x3 = @secp256k1.fmul(@secp256k1.fmul(px, px), px)
  assert_eq(y2, @secp256k1.fadd(x3, @secp256k1.b))
}
