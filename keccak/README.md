# keccak

Pre-NIST Keccak-256 (the variant used by Ethereum). Implements the original
Keccak SHA-3 submission v3 with rate 1088 / capacity 512, producing a
32-byte digest.

## Status

Complete. Differs from NIST SHA3-256 only in the domain-separation byte during
padding (Keccak uses `0x01`, SHA3 uses `0x06`); do not use this where
FIPS 202 SHA3-256 is required. Pure MoonBit, single-shot (no streaming
absorber). Not constant-time; not intended for keyed use.

## Import

```
// In your moon.pkg:
import {
  "skmtkytr/ethbit/keccak" @keccak,
}
```

## Quick example

```moonbit
let h = @keccak.keccak256(b"")
// h is the 32-byte Keccak-256 of the empty string,
// i.e. 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470
```

## API

| Symbol | Type | Description |
|---|---|---|
| `keccak256` | `(Bytes) -> Bytes` | Keccak-256 hash. Returns exactly 32 bytes. |

## References

- Keccak SHA-3 submission, v3 (Bertoni, Daemen, Peeters, Van Assche, 2011)
- Ethereum Yellow Paper Appendix H (uses pre-NIST Keccak-256)
- Used by: `address` (EIP-55 checksum), `tx` (transaction hash), `msg` (EIP-191/712), `abi` (event/function selectors)
