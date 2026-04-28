# ripemd160

RIPEMD-160 (Dobbertin, Bosselaers, Preneel, 1996). Pure MoonBit.

## Status

Complete. Validated against the official RIPEMD-160 test vectors. 32-bit
little-endian word ordering, two parallel 5-round pipelines, 20-byte digest.
Single-shot API (no incremental update/finalize). Not constant-time.

## Import

```
// In your moon.pkg:
import {
  "skmtkytr/ethbit/ripemd160" @ripemd160,
}
```

## Quick example

```moonbit
let h = @ripemd160.ripemd160(b"")
// h is the 20-byte RIPEMD-160 of the empty string,
// i.e. 0x9c1185a5c5e9fc54612808977ee8f548b2258d31
```

## API

| Symbol | Type | Description |
|---|---|---|
| `ripemd160` | `(Bytes) -> Bytes` | RIPEMD-160 hash. Returns exactly 20 bytes. |

## References

- Dobbertin, Bosselaers, Preneel, "RIPEMD-160: A Strengthened Version of RIPEMD" (1996)
- ISO/IEC 10118-3:2004
- Used by: `bip32` (`hash160` = RIPEMD-160(SHA-256(x)) for fingerprints / public-key identifiers)
