# sha512

SHA-512 (FIPS 180-4) and HMAC-SHA-512 (RFC 2104). Pure MoonBit.

## Status

Complete. Validated against NIST CAVS short-message vectors and RFC 4231
HMAC-SHA-512 test cases. Single-shot API (no incremental update/finalize).
Not constant-time; HMAC comparison is left to callers.

## Import

```
// In your moon.pkg:
import {
  "skmtkytr/ethbit/sha512" @sha512,
}
```

## Quick example

```moonbit
let digest = @sha512.sha512(b"abc")
// digest is the 64-byte SHA-512 of "abc"

let mac = @sha512.hmac(b"Bitcoin seed", seed_bytes)
// mac is the 64-byte HMAC-SHA-512 (BIP-32 master key derivation)
```

## API

| Symbol | Type | Description |
|---|---|---|
| `sha512` | `(Bytes) -> Bytes` | SHA-512 hash. Returns exactly 64 bytes. |
| `hmac` | `(Bytes, Bytes) -> Bytes` | HMAC-SHA-512 with arbitrary-length key and message. Returns 64 bytes. Keys longer than 128 bytes are pre-hashed; shorter keys are zero-padded. |

## References

- FIPS 180-4 §6.4 (SHA-512)
- RFC 2104 (HMAC), RFC 4231 (HMAC-SHA-2 test vectors)
- Used by: `bip32` (master key, child key derivation), `bip39` (PBKDF2 seed)
