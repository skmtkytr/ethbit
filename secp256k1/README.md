# secp256k1

ECDSA over the secp256k1 curve with RFC 6979 deterministic nonces and BIP-62 /
EIP-2 low-s normalization. Layered as `field.mbt` (F_p), `scalar.mbt` (F_n),
`point.mbt` (Jacobian + Montgomery ladder), `rfc6979.mbt`, `ecdsa.mbt`, and a
public-key facade in `secp256k1.mbt`.

## Status

Covers signing, verification, recovery, and SEC1 public-key encoding
(33-byte compressed, 65-byte uncompressed). Validated against:

- RFC 6979 §A.2.5 deterministic-nonce vectors
- Pinned `viem` (npm v2) byte-equivalent (r, s, yParity) cross-check vectors
  in `viem_vectors_test.mbt`
- Internal ECDSA round-trip + recovery tests

Recovery id follows the Ethereum convention: bit 0 = yParity, bit 1 =
x-overflow (`R.x >= n`, vanishingly rare).

## Security position: NO constant-time guarantee

This implementation **does not** provide constant-time guarantees and **must
not** be used to handle real funds on a hot key. The underlying
`@bigint.BigInt` arithmetic is variable-time, the modular reduction in
`field.mbt` branches on the sign of an intermediate value, and MoonBit itself
does not specify constant-time semantics for any current backend (native /
wasm-gc / js).

The Montgomery ladder in `point_mul` is structurally branch-free on the
secret scalar, and RFC 6979 removes the RNG dependency, but neither closes
the gap. Empirical timing measurements that anchor this position are recorded
in [`../cttest/REPORT.md`](../cttest/REPORT.md).

For full rationale, threat model, known leaks, and recommended use, see
[`SECURITY.md`](SECURITY.md). For production wallets bridge to libsecp256k1.

## Import

```
// In your moon.pkg:
import {
  "skmtkytr/ethbit/secp256k1" @secp256k1,
}
```

## Quick example

```moonbit
let sk : @bigint.BigInt = @bigint.BigInt::from_string(
  "C9AFA9D845BA75166B5C215767B1D6934E50C3DB36E89B127B8A622B120F6721",
  radix=16,
)
let digest : Bytes = msg_hash // 32-byte keccak256 of the signed payload
let sig : @secp256k1.EcdsaSig = @secp256k1.sign(sk, digest)
// sig.r, sig.s, sig.recid

let pk = @secp256k1.pubkey_from_sk(sk)
let ok = @secp256k1.verify_with_pubkey(pk, digest, sig)
let recovered = @secp256k1.recover(digest, sig)

let sec1_uncompressed = @secp256k1.pubkey_to_uncompressed(pk) // 65 B, 0x04...
let sec1_compressed   = @secp256k1.pubkey_to_compressed(pk)   // 33 B, 0x02/0x03
let xy_only           = @secp256k1.pubkey_to_xy_bytes(pk)     // 64 B (Ethereum)
```

## API

### Curve constants

| Symbol | Type | Description |
|---|---|---|
| `p` | `@bigint.BigInt` | Field prime |
| `n` | `@bigint.BigInt` | Group order |
| `b` | `@bigint.BigInt` | Curve constant (= 7) |
| `g` | `Point` | Generator G |
| `infinity` | `Point` | Point at infinity |

### Field / scalar arithmetic

| Symbol | Type | Description |
|---|---|---|
| `fadd`, `fsub`, `fneg`, `fmul`, `fsquare` | `(BigInt, BigInt) -> BigInt` | F_p ops |
| `finv` | `BigInt -> BigInt` | F_p inverse via Fermat |
| `fsqrt` | `BigInt -> BigInt` | sqrt mod p (caller verifies) |
| `from_bytes_be`, `to_bytes_be` | – | 32-byte BE codec |
| `nadd`, `nsub`, `nneg`, `nmul`, `ninv` | – | F_n ops |
| `reduce_scalar` | `BigInt -> BigInt` | reduce into [0, n) |
| `is_valid_scalar` | `BigInt -> Bool` | true iff in [1, n-1] |

### Point ops

| Symbol | Type | Description |
|---|---|---|
| `Point` | `struct { x, y, z }` | Jacobian point |
| `is_infinity`, `to_affine`, `on_curve`, `point_eq`, `point_neg` | – | basics |
| `point_add`, `point_double` | – | group ops |
| `point_mul` | `(BigInt, Point) -> Point` | k·P, Montgomery ladder |
| `mul_g` | `BigInt -> Point` | k·G |

### ECDSA / RFC 6979

| Symbol | Type | Description |
|---|---|---|
| `EcdsaSig` | `struct { r, s, recid }` | signature triple |
| `sign` | `(BigInt, Bytes) -> EcdsaSig` | deterministic ECDSA |
| `verify_with_pubkey` | `(Point, Bytes, EcdsaSig) -> Bool` | – |
| `recover` | `(Bytes, EcdsaSig) -> Point?` | recover pubkey |
| `rfc6979_k` | `(Bytes, Bytes) -> BigInt` | nonce derivation |

### Public-key facade

| Symbol | Type | Description |
|---|---|---|
| `pubkey_from_sk` | `BigInt -> Point` | sk·G |
| `pubkey_to_uncompressed` | `Point -> Bytes` | SEC1 65-byte 0x04 \|\| x \|\| y |
| `pubkey_to_xy_bytes` | `Point -> Bytes` | 64-byte x \|\| y (Ethereum) |
| `pubkey_to_compressed` | `Point -> Bytes` | SEC1 33-byte 0x02/0x03 \|\| x |
| `pubkey_from_bytes` | `Bytes -> Point?` | decode 33B/65B SEC1 |

## References

- SEC1 v2.0: <https://www.secg.org/sec1-v2.pdf>
- RFC 6979 — Deterministic Usage of DSA and ECDSA
- BIP-62 / EIP-2 low-s normalization
- [`SECURITY.md`](SECURITY.md) — threat model and known leaks
- [`../cttest/REPORT.md`](../cttest/REPORT.md) — empirical timing measurements
- noble-curves: <https://github.com/paulmillr/noble-curves>
- libsecp256k1: <https://github.com/bitcoin-core/secp256k1>
