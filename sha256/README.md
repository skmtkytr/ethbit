# sha256

SHA-256 (FIPS 180-4) and HMAC-SHA-256 (RFC 2104). Pure MoonBit.

## Status

Complete. Validated against NIST CAVS short-message vectors and RFC 4231
HMAC-SHA-256 test cases (1, 2, 3, 4, 6). Single-shot API (no incremental
update/finalize). Not constant-time; HMAC comparison is left to callers.

## Import

```
// In your moon.pkg:
import {
  "skmtkytr/ethbit/sha256" @sha256,
}
```

## Quick example

```moonbit
let digest = @sha256.sha256(b"abc")
// digest is the 32-byte SHA-256 of "abc"

let mac = @sha256.hmac(b"key", b"The quick brown fox jumps over the lazy dog")
// mac is the 32-byte HMAC-SHA-256
```

## API

| Symbol | Type | Description |
|---|---|---|
| `sha256` | `(Bytes) -> Bytes` | SHA-256 hash. Returns exactly 32 bytes. |
| `hmac` | `(Bytes, Bytes) -> Bytes` | HMAC-SHA-256 with arbitrary-length key and message. Returns 32 bytes. Keys longer than 64 bytes are pre-hashed; shorter keys are zero-padded. |

## References

- FIPS 180-4 §6.2 (SHA-256)
- RFC 2104 (HMAC), RFC 4231 (HMAC-SHA-2 test vectors)
- Used by: `base58` (Base58Check checksum), `bip32`, `bip39`, `secp256k1` (RFC 6979 nonce)
