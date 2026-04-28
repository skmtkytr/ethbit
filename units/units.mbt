// Ethereum monetary unit conversions: ether / gwei / wei (and arbitrary decimals).
//
// Mirrors viem v2's parseUnits / formatUnits behavior:
//   - parse_units("1.5", 18)  -> 1500000000000000000  (1.5 ether in wei)
//   - format_units(1500000000000000000, 18) -> "1.5"
//
// Parsing rejects negative numbers, scientific notation, multiple dots, and
// strings whose fractional part is longer than `decimals`. Formatting accepts
// any signed integer; negative values produce a "-" prefix.

///|
pub(all) suberror ParseError {
  Empty
  NegativeNotAllowed
  InvalidChar(Int) // index where invalid char appeared
  MultipleDots
  ScientificNotationNotAllowed
  TooManyDecimals(Int) // actual decimal-place count
} derive(Eq)

///|
pub impl Show for ParseError with output(self, logger) {
  match self {
    Empty => logger.write_string("Empty")
    NegativeNotAllowed => logger.write_string("NegativeNotAllowed")
    InvalidChar(i) => {
      logger.write_string("InvalidChar(")
      logger.write_object(i)
      logger.write_char(')')
    }
    MultipleDots => logger.write_string("MultipleDots")
    ScientificNotationNotAllowed =>
      logger.write_string("ScientificNotationNotAllowed")
    TooManyDecimals(n) => {
      logger.write_string("TooManyDecimals(")
      logger.write_object(n)
      logger.write_char(')')
    }
  }
}

///|
/// Parse a decimal string into a BigInt scaled by 10^decimals.
///
/// Examples:
///   parse_units("1", 18)   -> Ok(1_000_000_000_000_000_000)
///   parse_units("1.5", 18) -> Ok(1_500_000_000_000_000_000)
///   parse_units(".5", 18)  -> Ok(500_000_000_000_000_000)   (leading dot OK)
///   parse_units("1.", 18)  -> Ok(1_000_000_000_000_000_000) (trailing dot OK)
///
/// Errors:
///   - Empty                        : input is empty
///   - NegativeNotAllowed           : input starts with '-'
///   - ScientificNotationNotAllowed : input contains 'e' or 'E'
///   - MultipleDots                 : more than one '.'
///   - TooManyDecimals(n)           : fractional part longer than `decimals`
///   - InvalidChar(i)               : non-digit, non-dot character at index i
pub fn parse_units(
  s : String,
  decimals : Int,
) -> Result[@bigint.BigInt, ParseError] {
  let chars = s.iter().to_array()
  if chars.length() == 0 {
    return Err(Empty)
  }
  if chars[0] == '-' {
    return Err(NegativeNotAllowed)
  }
  // Single pass: validate every char and locate the (single) decimal point.
  // dot_index = -1 means "no dot found yet".
  let mut dot_index = -1
  for i = 0; i < chars.length(); i = i + 1 {
    let c = chars[i]
    if c == '.' {
      if dot_index >= 0 {
        return Err(MultipleDots)
      }
      dot_index = i
    } else if c == 'e' || c == 'E' {
      return Err(ScientificNotationNotAllowed)
    } else if c < '0' || c > '9' {
      return Err(InvalidChar(i))
    }
  }
  // Split into integer and fractional substrings (as char arrays).
  let int_chars : Array[Char] = if dot_index < 0 {
    chars
  } else {
    chars[0:dot_index].to_array()
  }
  let frac_chars : Array[Char] = if dot_index < 0 {
    Array::new()
  } else {
    chars[dot_index + 1:].to_array()
  }
  if frac_chars.length() > decimals {
    return Err(TooManyDecimals(frac_chars.length()))
  }
  // Build the digit string: int_chars ++ frac_chars ++ ('0' * (decimals - frac_len)).
  let pad = decimals - frac_chars.length()
  let total_len = int_chars.length() + frac_chars.length() + pad
  let buf : Array[Char] = Array::make(if total_len == 0 { 1 } else { total_len }, '0')
  let mut p = 0
  for i = 0; i < int_chars.length(); i = i + 1 {
    buf[p] = int_chars[i]
    p = p + 1
  }
  for i = 0; i < frac_chars.length(); i = i + 1 {
    buf[p] = frac_chars[i]
    p = p + 1
  }
  for i = 0; i < pad; i = i + 1 {
    buf[p] = '0'
    p = p + 1
  }
  // Special case: if both int and frac were empty (input was "."), buf is ['0'].
  let digit_str = if total_len == 0 {
    "0"
  } else {
    String::from_array(buf[:])
  }
  Ok(@bigint.BigInt::from_string(digit_str, radix=10))
}

///|
/// Format a BigInt as a decimal string assuming the value is scaled by
/// 10^decimals. Trailing zeros in the fractional part are stripped, and the
/// "." separator is dropped if the fractional part becomes empty.
///
/// Negative input is allowed and produces a "-" prefix.
///
/// Examples:
///   format_units(1_500_000_000_000_000_000, 18) -> "1.5"
///   format_units(1, 18)                         -> "0.000000000000000001"
///   format_units(0, 18)                         -> "0"
///   format_units(-1, 18)                        -> "-0.000000000000000001"
pub fn format_units(value : @bigint.BigInt, decimals : Int) -> String {
  let zero = @bigint.BigInt::from_int(0)
  let negative = value < zero
  let abs_value = if negative { -value } else { value }
  if decimals == 0 {
    if negative {
      "-" + abs_value.to_string()
    } else {
      abs_value.to_string()
    }
  } else {
    let divisor = pow10(decimals)
    let integer_part = abs_value / divisor
    let remainder = abs_value % divisor
    // remainder.to_string() may be shorter than `decimals`; left-pad with '0'.
    let raw_frac = remainder.to_string()
    let pad = decimals - raw_frac.length()
    let padded_frac_buf : Array[Char] = Array::make(decimals, '0')
    let raw_chars = raw_frac.iter().to_array()
    for i = 0; i < raw_chars.length(); i = i + 1 {
      padded_frac_buf[pad + i] = raw_chars[i]
    }
    // Strip trailing zeros.
    let mut end = decimals
    while end > 0 && padded_frac_buf[end - 1] == '0' {
      end = end - 1
    }
    let int_str = integer_part.to_string()
    let sign = if negative { "-" } else { "" }
    if end == 0 {
      sign + int_str
    } else {
      let frac_str = String::from_array(padded_frac_buf[0:end].to_array())
      sign + int_str + "." + frac_str
    }
  }
}

///|
/// parse_units(s, 18) — convert an ether-denominated decimal string to wei.
pub fn parse_ether(s : String) -> Result[@bigint.BigInt, ParseError] {
  parse_units(s, 18)
}

///|
/// parse_units(s, 9) — convert a gwei-denominated decimal string to wei.
pub fn parse_gwei(s : String) -> Result[@bigint.BigInt, ParseError] {
  parse_units(s, 9)
}

///|
/// format_units(value, 18) — render a wei value as an ether decimal string.
pub fn format_ether(value : @bigint.BigInt) -> String {
  format_units(value, 18)
}

///|
/// format_units(value, 9) — render a wei value as a gwei decimal string.
pub fn format_gwei(value : @bigint.BigInt) -> String {
  format_units(value, 9)
}

///|
/// 10^n as a BigInt. n must be >= 0; callers in this module always pass
/// decimals >= 1.
fn pow10(n : Int) -> @bigint.BigInt {
  let ten = @bigint.BigInt::from_int(10)
  let mut acc = @bigint.BigInt::from_int(1)
  for i = 0; i < n; i = i + 1 {
    acc = acc * ten
  }
  acc
}
