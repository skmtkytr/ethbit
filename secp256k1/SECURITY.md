# secp256k1 — Security position

## Constant-time guarantee: **None**

This implementation **does not** provide constant-time guarantees. Use only for:

- Educational / testnet contexts
- Tooling, test fixtures, signature recovery in already-broadcast transactions
- Cases where the private key is **not** under timing-attack threat

For production wallets handling real funds, use a battle-tested implementation
(libsecp256k1 via FFI / WASM) instead.

## Why no guarantee

This library follows the same position as `noble-curves` (the de-facto
pure-JS secp256k1):

> "We're targetting **algorithmic** constant time. JIT-compiler and
> Garbage Collector make 'constant time' extremely hard to achieve ... in
> a scripting language. ... If your goal is absolute security, don't use
> any JS lib — including bindings to native ones. Use low-level libraries
> & languages." — paulmillr/noble-curves README

MoonBit is in the same situation: the language and its current backends
(wasm-gc / native / js) do not specify constant-time semantics, and we
cannot prove their absence by inspection of source code alone.

Empirical measurements supporting this position are recorded in
[`cttest/REPORT.md`](../cttest/REPORT.md).

## What we do

- **Algorithmic constant-time discipline**:
  - Montgomery ladder for scalar multiplication (no branch on the secret scalar)
  - No table lookup indexed by a secret value
  - RFC 6979 deterministic nonce derivation (no RNG dependency)
- **Test coverage**:
  - RFC 6979 test vectors
  - Wycheproof secp256k1 vectors (when integrated)
  - Cross-library checks against viem / ethers reference outputs
- **Honest documentation** of known leaks below.

## Known leaks

1. **`@bigint` arithmetic is not constant-time.** Multiplication / division
   timing depends on operand magnitude. Reduction modulo p is
   variable-length internally. This is the primary source of timing leakage,
   and is the same situation V8's BigInt creates for noble-curves.

2. **Branch-on-secret in `reduce`**: the wrap step `if r < 0 { r + p }` in
   field reduction branches on the sign of an intermediate value. The
   inputs to field arithmetic are derived from secrets in ECDSA signing.

3. **Wall-clock vs micro-architectural leaks**: even where source-level
   branches are avoided, cache / branch-predictor / speculative-execution
   side channels are not analyzed and not mitigated.

## Recommended use

| Use case | Recommendation |
|---|---|
| Sign Ethereum testnet tx | OK |
| Verify a signed tx (no secret involved) | OK |
| Recover address from signature | OK |
| Sign mainnet tx with hot key | **Do not use** — bridge to libsecp256k1 |
| Hardware wallet integration | Out of scope |

## References

- noble-curves README: <https://github.com/paulmillr/noble-curves#security>
- `cttest/REPORT.md` — empirical timing measurements on this codebase
- RFC 6979 — Deterministic Usage of DSA and ECDSA
- libsecp256k1 — <https://github.com/bitcoin-core/secp256k1>
