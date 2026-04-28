# rlp

Recursive Length Prefix (RLP), Ethereum's structural serialization format.
Encoder and decoder for nested `RlpString` / `RlpList` trees over `Bytes`.

## Status

Complete and **canonical-strict**: the decoder rejects well-formed but
non-minimal encodings — single bytes wrapped with `0x81`, payload-length
prefixes with leading zeros, and long-form length headers used where the
short form would fit. Recursion is capped at depth 256.

## Import

```
// In your moon.pkg:
import {
  "skmtkytr/ethbit/rlp" @rlp,
}
```

## Quick example

```moonbit
let v = @rlp.RlpList([
  @rlp.RlpString(b"\xde\xad"),
  @rlp.RlpString(b"\xbe\xef"),
])
let bytes = @rlp.encode(v)

match @rlp.decode(bytes) {
  Ok(decoded) => assert_eq(decoded, v)
  Err(e) => abort(e.to_string())
}
```

## API

| Symbol | Type | Description |
|---|---|---|
| `RlpValue` | `enum` | `RlpString(Bytes)` or `RlpList(Array[RlpValue])`. `derive(Eq, Show)`. |
| `encode` | `(RlpValue) -> Bytes` | Encode a value tree to canonical RLP bytes. |
| `decode` | `(Bytes) -> Result[RlpValue, DecodeError]` | Decode RLP bytes; rejects trailing bytes and non-canonical encodings. |
| `DecodeError` | `suberror` | Variants below. `derive(Eq, Show)`. |
| `EmptyInput` | variant | Input is zero-length. |
| `TruncatedInput(Int, Int)` | variant | Expected end offset and actual byte count. |
| `TrailingBytes(Int)` | variant | Bytes remain after the top-level value at the given offset. |
| `NonCanonicalSingleByte` | variant | Single byte `< 0x80` was wrapped with the `0x81` prefix. |
| `NonCanonicalLength` | variant | Long-form length used where short form would fit (payload <= 55). |
| `NonCanonicalLengthLeadingZero` | variant | Length-prefix bytes contain a leading zero. |
| `RecursionTooDeep(Int)` | variant | Nesting exceeded the 256 depth limit. |

## References

- Ethereum Yellow Paper, Appendix B
- https://ethereum.org/en/developers/docs/data-structures-and-encoding/rlp/
- Used by: `tx`
