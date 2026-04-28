# hex

0x-prefixed hexadecimal encoding and decoding for `Bytes`. Encoder always emits
a `0x` prefix; decoder accepts `0x`, `0X`, or no prefix.

## Status

Complete. Decoder rejects odd-length bodies and any non-hex character with a
positional error. Hex digits accept both lower- and uppercase (`0-9`, `a-f`,
`A-F`). Encoder output is always lowercase and prefixed.

## Import

```
// In your moon.pkg:
import {
  "skmtkytr/ethbit/hex" @hex,
}
```

## Quick example

```moonbit
let s = @hex.encode(b"\xde\xad\xbe\xef")
// s == "0xdeadbeef"

let r = @hex.decode("0xDEADBEEF")
// r == Ok(b"\xde\xad\xbe\xef")
```

## API

| Symbol | Type | Description |
|---|---|---|
| `encode` | `(Bytes) -> String` | Encode bytes as a `0x`-prefixed lowercase hex string. |
| `decode` | `(String) -> Result[Bytes, DecodeError]` | Decode `0x`/`0X`/unprefixed hex into bytes. |
| `DecodeError` | `suberror` | Variants: `OddLength(Int)`, `InvalidChar(Char, Int)`. |
| `OddLength(Int)` | variant | Body length (excluding prefix) is odd; carries the body length. |
| `InvalidChar(Char, Int)` | variant | Non-hex character at the given body offset. |

## References

- Ethereum hex string convention (`0x`-prefixed)
- Used by: `address`, `keccak` (tests), `sha256` (tests), `sha512` (tests), `ripemd160` (tests), `base58` (tests), `bip32`, `bip39`, `tx`, `msg`, `rpc`, `ws`, `secp256k1`, `abi`
