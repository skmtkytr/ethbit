# bytesx

Small `Bytes` helpers shared by `rlp`, `abi`, `tx`, and `msg`. Only the
operations that are exercised by multiple packages live here; this is not a
general-purpose bytes library.

## Status

Stable. No external spec — purely internal plumbing. All functions are
total (no error returns). `pad_left` / `pad_right` never truncate.

## Import

```
// In your moon.pkg:
import {
  "skmtkytr/ethbit/bytesx" @bytesx,
}
```

## Quick example

```moonbit
let head = b"\x01\x02"
let tail = b"\x03\x04"
let joined = @bytesx.concat([head, tail])
// joined == b"\x01\x02\x03\x04"

let padded = @bytesx.pad_left(b"\x01", 32, b'\x00')
// padded.length() == 32, last byte is 0x01

let n = @bytesx.from_uint64_be(256UL)
// n == b"\x01\x00"
```

## API

| Symbol | Type | Description |
|---|---|---|
| `concat` | `(Array[Bytes]) -> Bytes` | Concatenate a list of `Bytes` in order. |
| `slice` | `(Bytes, Int, Int) -> Bytes` | Extract `[start, end)` as a new `Bytes`. |
| `pad_left` | `(Bytes, Int, Byte) -> Bytes` | Left-pad with `fill` to `target_len`; returns input unchanged if already long enough. |
| `pad_right` | `(Bytes, Int, Byte) -> Bytes` | Right-pad with `fill` to `target_len`; returns input unchanged if already long enough. |
| `from_uint64_be` | `(UInt64) -> Bytes` | Big-endian byte representation with no leading zeros; `0UL` maps to `b""` (matches RLP integer convention). |

## References

- Used by: `rlp`, `abi`, `address` (transitively), `tx`, `msg`
