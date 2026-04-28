# base58

Base58 and Base58Check encoding/decoding using the Bitcoin alphabet
(`123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz`).

## Status

Complete. Leading `0x00` bytes round-trip as leading `'1'` digits.
Base58Check appends `sha256(sha256(payload))[:4]` and verifies it on decode.
`decode` rejects empty input with `Empty`. The byte-by-byte checksum
comparison is not constant-time, but Base58Check is a typo guard, not a
secret authenticator, so this is normally fine.

## Import

```
// In your moon.pkg:
import {
  "skmtkytr/ethbit/base58" @base58,
}
```

## Quick example

```moonbit
// Plain Base58.
let s = @base58.encode(b"\x00\x00hello")
let r = @base58.decode(s) // Ok(b"\x00\x00hello")

// Base58Check (e.g. Bitcoin P2PKH address).
let addr = @base58.encode_check(b"\x00...20-byte hash160...")
match @base58.decode_check(addr) {
  Ok(payload) => ...
  Err(@base58.InvalidChecksum) => ...
  Err(_) => ...
}
```

## API

| Symbol | Type | Description |
|---|---|---|
| `encode` | `(Bytes) -> String` | Plain Base58 encode. No checksum is appended. |
| `decode` | `(String) -> Result[Bytes, DecodeError]` | Plain Base58 decode. Does not verify a checksum. Empty input returns `Empty`. |
| `encode_check` | `(Bytes) -> String` | Base58Check encode: `encode(payload || sha256(sha256(payload))[:4])`. |
| `decode_check` | `(String) -> Result[Bytes, DecodeError]` | Base58Check decode: verifies and strips the trailing 4-byte checksum. |
| `DecodeError` | `suberror` | Variants: `InvalidChar(Int)`, `InvalidChecksum`, `Empty`. |
| `InvalidChar(Int)` | variant | Non-alphabet character at the given input index. |
| `InvalidChecksum` | variant | Checksum mismatch, or decoded body shorter than 4 bytes. |
| `Empty` | variant | Input string was empty. |

## References

- Bitcoin Base58 / Base58Check convention (Wiki: "Base58Check encoding")
- BIP-13 (P2SH addresses), BIP-32 (extended-key serialization uses Base58Check)
- Used by: `bip32` (xprv/xpub serialization)
