# units

Ethereum monetary unit conversions — ether, gwei, wei — plus the generic
`parse_units` / `format_units` pair for arbitrary decimal scales.

## Status

Behavior matches viem v2's `parseUnits` / `formatUnits`. Parsing rejects
negatives, scientific notation, multiple `.`s, and fractional parts longer
than `decimals`; bare leading or trailing `.` is allowed (`.5`, `1.`).
Formatting accepts any signed `BigInt` and emits a `-` prefix for negatives;
trailing fractional zeros are stripped, and the `.` separator is dropped
when the fractional part collapses to empty.

## Import

```
// In your moon.pkg:
import {
  "skmtkytr/ethbit/units" @units,
  "moonbitlang/core/bigint" @bigint,
}
```

## Quick example

```moonbit
let wei = match @units.parse_ether("1.5") {
  Ok(v) => v
  Err(_) => abort("invalid")
}
// wei == 1_500_000_000_000_000_000

let s = @units.format_ether(@bigint.BigInt::from_int64(1_500_000_000_000_000_000L))
// s == "1.5"

let gwei = match @units.parse_gwei("20") {
  Ok(v) => v
  Err(_) => abort("invalid")
}
// gwei == 20_000_000_000  (in wei)
```

## API

| Symbol | Type | Description |
|---|---|---|
| `parse_units` | `(String, Int) -> Result[BigInt, ParseError]` | Parse a decimal string scaled by `10^decimals`. |
| `format_units` | `(BigInt, Int) -> String` | Render a value scaled by `10^decimals`; strips trailing fractional zeros. |
| `parse_ether` | `(String) -> Result[BigInt, ParseError]` | `parse_units(s, 18)`. |
| `parse_gwei` | `(String) -> Result[BigInt, ParseError]` | `parse_units(s, 9)`. |
| `format_ether` | `(BigInt) -> String` | `format_units(v, 18)`. |
| `format_gwei` | `(BigInt) -> String` | `format_units(v, 9)`. |
| `ParseError` | `suberror` | `Empty`, `NegativeNotAllowed`, `InvalidChar(Int)`, `MultipleDots`, `ScientificNotationNotAllowed`, `TooManyDecimals(Int)`. `derive(Eq, Show)`. |

## References

- viem v2 `parseUnits` / `formatUnits`: https://viem.sh/docs/utilities/parseUnits
- Ethereum unit conventions (1 ether = 1e18 wei, 1 gwei = 1e9 wei)
