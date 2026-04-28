// Test vectors mirror viem v2's parseUnits / formatUnits behavior.

fn bi(s : String) -> @bigint.BigInt {
  @bigint.BigInt::from_string(s, radix=10)
}

fn unwrap_parse(
  r : Result[@bigint.BigInt, @units.ParseError],
) -> @bigint.BigInt {
  match r {
    Ok(v) => v
    Err(e) => abort("expected Ok, got Err: " + e.to_string())
  }
}

// ============================================================================
// parse_units: success cases
// ============================================================================

test "parse_units: \"1\" with decimals=18 -> 1e18" {
  assert_eq(unwrap_parse(@units.parse_units("1", 18)), bi("1000000000000000000"))
}

test "parse_units: \"1.5\" with decimals=18 -> 1.5e18" {
  assert_eq(
    unwrap_parse(@units.parse_units("1.5", 18)),
    bi("1500000000000000000"),
  )
}

test "parse_units: \"0.5\" with decimals=18 -> 5e17" {
  assert_eq(
    unwrap_parse(@units.parse_units("0.5", 18)),
    bi("500000000000000000"),
  )
}

test "parse_units: \"0\" with decimals=18 -> 0" {
  assert_eq(unwrap_parse(@units.parse_units("0", 18)), bi("0"))
}

test "parse_units: minimum precision (0.000...01 with 18 decimals) -> 1" {
  assert_eq(
    unwrap_parse(@units.parse_units("0.000000000000000001", 18)),
    bi("1"),
  )
}

test "parse_units: \"123.456\" with decimals=18" {
  assert_eq(
    unwrap_parse(@units.parse_units("123.456", 18)),
    bi("123456000000000000000"),
  )
}

test "parse_units: leading dot \".5\" treated as 0.5" {
  assert_eq(
    unwrap_parse(@units.parse_units(".5", 18)),
    bi("500000000000000000"),
  )
}

test "parse_units: trailing dot \"1.\" treated as 1.0" {
  assert_eq(
    unwrap_parse(@units.parse_units("1.", 18)),
    bi("1000000000000000000"),
  )
}

test "parse_units: all-zero fractional part \"1.000\" -> 1e18" {
  assert_eq(
    unwrap_parse(@units.parse_units("1.000", 18)),
    bi("1000000000000000000"),
  )
}

test "parse_units: decimals=0 (integer mode)" {
  assert_eq(unwrap_parse(@units.parse_units("0", 0)), bi("0"))
  assert_eq(unwrap_parse(@units.parse_units("123", 0)), bi("123"))
  assert_eq(unwrap_parse(@units.parse_units("1000000", 0)), bi("1000000"))
}

test "parse_units: decimals=6 (USDC-style)" {
  assert_eq(unwrap_parse(@units.parse_units("1", 6)), bi("1000000"))
  assert_eq(unwrap_parse(@units.parse_units("1.5", 6)), bi("1500000"))
  assert_eq(unwrap_parse(@units.parse_units("0.000001", 6)), bi("1"))
  assert_eq(
    unwrap_parse(@units.parse_units("123.456789", 6)),
    bi("123456789"),
  )
}

test "parse_units: very large value (> 1e30 wei)" {
  // 1_000_000 ether = 1e6 * 1e18 = 1e24 wei
  assert_eq(
    unwrap_parse(@units.parse_units("1000000", 18)),
    bi("1000000000000000000000000"),
  )
  // 1e12 ether = 1e30 wei
  assert_eq(
    unwrap_parse(@units.parse_units("1000000000000", 18)),
    bi("1000000000000000000000000000000"),
  )
}

test "parse_units: leading zeros in integer part are accepted" {
  assert_eq(
    unwrap_parse(@units.parse_units("001.5", 18)),
    bi("1500000000000000000"),
  )
}

// ============================================================================
// parse_units: error cases
// ============================================================================

test "parse_units: empty string -> Empty" {
  assert_eq(@units.parse_units("", 18), Err(Empty))
}

test "parse_units: \"-1\" -> NegativeNotAllowed" {
  assert_eq(@units.parse_units("-1", 18), Err(NegativeNotAllowed))
}

test "parse_units: \"-0.5\" -> NegativeNotAllowed" {
  assert_eq(@units.parse_units("-0.5", 18), Err(NegativeNotAllowed))
}

test "parse_units: \"1..5\" -> MultipleDots" {
  assert_eq(@units.parse_units("1..5", 18), Err(MultipleDots))
}

test "parse_units: \"1.2.3\" -> MultipleDots" {
  assert_eq(@units.parse_units("1.2.3", 18), Err(MultipleDots))
}

test "parse_units: \"1e5\" -> ScientificNotationNotAllowed" {
  assert_eq(@units.parse_units("1e5", 18), Err(ScientificNotationNotAllowed))
}

test "parse_units: \"1E5\" -> ScientificNotationNotAllowed" {
  assert_eq(@units.parse_units("1E5", 18), Err(ScientificNotationNotAllowed))
}

test "parse_units: 19-decimal fractional with decimals=18 -> TooManyDecimals(19)" {
  assert_eq(
    @units.parse_units("1.5000000000000000001", 18),
    Err(TooManyDecimals(19)),
  )
}

test "parse_units: \"abc\" -> InvalidChar(0)" {
  assert_eq(@units.parse_units("abc", 18), Err(InvalidChar(0)))
}

test "parse_units: \"1a\" -> InvalidChar(1)" {
  assert_eq(@units.parse_units("1a", 18), Err(InvalidChar(1)))
}

test "parse_units: \" 1\" (leading space) -> InvalidChar(0)" {
  assert_eq(@units.parse_units(" 1", 18), Err(InvalidChar(0)))
}

test "parse_units: decimals=0 with fractional part -> TooManyDecimals" {
  assert_eq(@units.parse_units("1.5", 0), Err(TooManyDecimals(1)))
}

// ============================================================================
// format_units
// ============================================================================

test "format_units: 1.5e18 with decimals=18 -> \"1.5\"" {
  assert_eq(@units.format_units(bi("1500000000000000000"), 18), "1.5")
}

test "format_units: 1e18 with decimals=18 -> \"1\" (no trailing .)" {
  assert_eq(@units.format_units(bi("1000000000000000000"), 18), "1")
}

test "format_units: 0 with decimals=18 -> \"0\"" {
  assert_eq(@units.format_units(bi("0"), 18), "0")
}

test "format_units: 1 with decimals=18 -> minimum precision" {
  assert_eq(@units.format_units(bi("1"), 18), "0.000000000000000001")
}

test "format_units: pure-fractional 0.123...678 with decimals=18" {
  assert_eq(
    @units.format_units(bi("123456789012345678"), 18),
    "0.123456789012345678",
  )
}

test "format_units: negative value -> -prefix" {
  assert_eq(@units.format_units(-bi("1"), 18), "-0.000000000000000001")
  assert_eq(@units.format_units(-bi("1500000000000000000"), 18), "-1.5")
  assert_eq(@units.format_units(-bi("1000000000000000000"), 18), "-1")
}

test "format_units: trailing zeros stripped (1.50000... -> 1.5)" {
  // 1.5e18 should display as 1.5, not 1.500000000000000000
  assert_eq(@units.format_units(bi("1500000000000000000"), 18), "1.5")
  // 0.1e18 = 100000000000000000 wei -> 0.1
  assert_eq(@units.format_units(bi("100000000000000000"), 18), "0.1")
}

test "format_units: decimals=0 -> integer string" {
  assert_eq(@units.format_units(bi("0"), 0), "0")
  assert_eq(@units.format_units(bi("123"), 0), "123")
  assert_eq(@units.format_units(-bi("123"), 0), "-123")
}

test "format_units: decimals=6 (USDC-style)" {
  assert_eq(@units.format_units(bi("1000000"), 6), "1")
  assert_eq(@units.format_units(bi("1500000"), 6), "1.5")
  assert_eq(@units.format_units(bi("1"), 6), "0.000001")
  assert_eq(@units.format_units(bi("123456789"), 6), "123.456789")
}

test "format_units: very large value (1e30 wei -> 1e12 ether)" {
  assert_eq(
    @units.format_units(bi("1000000000000000000000000000000"), 18),
    "1000000000000",
  )
}

test "format_units: integer part with non-trivial fractional" {
  // 12.345 ether = 12345000000000000000 wei
  assert_eq(@units.format_units(bi("12345000000000000000"), 18), "12.345")
}

// ============================================================================
// Round-trip: parse(format(x)) == x
// ============================================================================

test "round-trip: parse(format(0)) == 0" {
  let x = bi("0")
  assert_eq(unwrap_parse(@units.parse_units(@units.format_units(x, 18), 18)), x)
}

test "round-trip: parse(format(1)) == 1" {
  let x = bi("1")
  assert_eq(unwrap_parse(@units.parse_units(@units.format_units(x, 18), 18)), x)
}

test "round-trip: parse(format(1.5e18)) == 1.5e18" {
  let x = bi("1500000000000000000")
  assert_eq(unwrap_parse(@units.parse_units(@units.format_units(x, 18), 18)), x)
}

test "round-trip: parse(format(123.456789012345678e18)) preserved" {
  let x = bi("123456789012345678901234567")
  assert_eq(unwrap_parse(@units.parse_units(@units.format_units(x, 18), 18)), x)
}

test "round-trip: parse(format(1e30)) preserved" {
  let x = bi("1000000000000000000000000000000")
  assert_eq(unwrap_parse(@units.parse_units(@units.format_units(x, 18), 18)), x)
}

test "round-trip: decimals=6" {
  let x = bi("123456789")
  assert_eq(unwrap_parse(@units.parse_units(@units.format_units(x, 6), 6)), x)
}

test "round-trip: decimals=0" {
  let x = bi("999999999999")
  assert_eq(unwrap_parse(@units.parse_units(@units.format_units(x, 0), 0)), x)
}

// ============================================================================
// Parse-then-format equivalence
// ============================================================================

test "parse-then-format: \"1.5\" -> 1.5e18 -> \"1.5\"" {
  let v = unwrap_parse(@units.parse_units("1.5", 18))
  assert_eq(@units.format_units(v, 18), "1.5")
}

test "parse-then-format: \"123.456\" -> ... -> \"123.456\"" {
  let v = unwrap_parse(@units.parse_units("123.456", 18))
  assert_eq(@units.format_units(v, 18), "123.456")
}

test "parse-then-format: trailing zeros are dropped" {
  // "1.50" parses as 1.5e18, formats as "1.5" (canonicalized)
  let v = unwrap_parse(@units.parse_units("1.50", 18))
  assert_eq(@units.format_units(v, 18), "1.5")
}

test "parse-then-format: leading dot canonicalized" {
  // ".5" parses as 5e17, formats as "0.5" (canonicalized)
  let v = unwrap_parse(@units.parse_units(".5", 18))
  assert_eq(@units.format_units(v, 18), "0.5")
}

test "parse-then-format: trailing dot canonicalized" {
  // "1." parses as 1e18, formats as "1"
  let v = unwrap_parse(@units.parse_units("1.", 18))
  assert_eq(@units.format_units(v, 18), "1")
}

// ============================================================================
// parse_ether / parse_gwei / format_ether / format_gwei
// ============================================================================

test "parse_ether: \"1\" -> 1e18 wei" {
  assert_eq(unwrap_parse(@units.parse_ether("1")), bi("1000000000000000000"))
}

test "parse_ether: \"0.000000000000000001\" -> 1 wei" {
  assert_eq(unwrap_parse(@units.parse_ether("0.000000000000000001")), bi("1"))
}

test "parse_gwei: \"1\" -> 1e9 wei" {
  assert_eq(unwrap_parse(@units.parse_gwei("1")), bi("1000000000"))
}

test "parse_gwei: \"1.5\" -> 1.5e9 wei" {
  assert_eq(unwrap_parse(@units.parse_gwei("1.5")), bi("1500000000"))
}

test "parse_gwei: \"0.000000001\" -> 1 wei (minimum gwei precision)" {
  assert_eq(unwrap_parse(@units.parse_gwei("0.000000001")), bi("1"))
}

test "parse_gwei: 10-decimal fraction -> TooManyDecimals(10)" {
  assert_eq(@units.parse_gwei("0.0000000001"), Err(TooManyDecimals(10)))
}

test "format_ether: 1e18 wei -> \"1\"" {
  assert_eq(@units.format_ether(bi("1000000000000000000")), "1")
}

test "format_ether: 1 wei -> minimum-precision string" {
  assert_eq(@units.format_ether(bi("1")), "0.000000000000000001")
}

test "format_gwei: 1e9 wei -> \"1\"" {
  assert_eq(@units.format_gwei(bi("1000000000")), "1")
}

test "format_gwei: 1500000000 wei -> \"1.5\"" {
  assert_eq(@units.format_gwei(bi("1500000000")), "1.5")
}

test "format_gwei: 1 wei -> \"0.000000001\"" {
  assert_eq(@units.format_gwei(bi("1")), "0.000000001")
}

// ============================================================================
// Show impl for ParseError
// ============================================================================

test "ParseError Show: each variant renders distinctly" {
  let e_empty : @units.ParseError = Empty
  assert_eq(e_empty.to_string(), "Empty")
  let e_neg : @units.ParseError = NegativeNotAllowed
  assert_eq(e_neg.to_string(), "NegativeNotAllowed")
  let e_dots : @units.ParseError = MultipleDots
  assert_eq(e_dots.to_string(), "MultipleDots")
  let e_sci : @units.ParseError = ScientificNotationNotAllowed
  assert_eq(e_sci.to_string(), "ScientificNotationNotAllowed")
  let e_inv : @units.ParseError = InvalidChar(7)
  assert_eq(e_inv.to_string(), "InvalidChar(7)")
  let e_too : @units.ParseError = TooManyDecimals(19)
  assert_eq(e_too.to_string(), "TooManyDecimals(19)")
}
