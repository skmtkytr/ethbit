# cttest

Testbed for empirical timing-leak detection on MoonBit-compiled code. **Not
a production library** — this package exists to anchor the security position
of [`../secp256k1`](../secp256k1) (see
[`../secp256k1/SECURITY.md`](../secp256k1/SECURITY.md)) with reproducible
measurements rather than appeals to authority.

## Status

Two layers:

1. **Reference micro-implementations** in `cttest.mbt`:
   - `bytes_eq_naive` — early-return byte-array equality (deliberately
     leaky; baseline for "definitely-detectable")
   - `bytes_eq_xorfold` — XOR-fold across all bytes; "branchless" only at
     the source level (the compiler is free to lower it as it pleases)
   - `select_branch` — `if cond { a } else { b }`
   - `select_mask` — byte-wise `(a & m) | (b & ~m)` over the full length

2. **dudect-style timing harness** in `dudect.mbt`:
   `dudect_compare(name, fa, fb, …)` runs interleaved batches of two
   closures, crops top-percentile outliers, and reports Welch's two-sample
   *t* statistic plus a leak verdict (`|t| > threshold`, default 4.5).

A null result here is a **lower bound**: "no leak detected at this
resolution, this run, this target." It does not prove constant-time
behavior. Measured results across `native`, `wasm-gc`, and `js` backends —
including framework noise-floor characterization (twin-closure sanity check)
and known limitations (cache-timing not covered, real secp256k1 ladders not
measured) — are recorded in [`REPORT.md`](REPORT.md).

## Import

```
// In your moon.pkg:
import {
  "skmtkytr/ethbit/cttest" @cttest,
}
```

In normal use only `cttest.mbt` and `dudect.mbt` are callable. The
`*_bench_test.mbt` and `cttest_dudect_test.mbt` files run the actual
measurements — drive them with:

```fish
moon bench --target native  -p skmtkytr/ethbit/cttest --release
moon bench --target wasm-gc -p skmtkytr/ethbit/cttest --release
moon bench --target js      -p skmtkytr/ethbit/cttest --release

moon test --target native  --release -p skmtkytr/ethbit/cttest -F 'dudect*'
```

## Quick example

```moonbit
// Compare a leaky vs branchless equality on the same input pair.
let a : Bytes = Bytes::make(32, b'\x00')
let b_eq : Bytes = Bytes::make(32, b'\x00')
let b_diff : Bytes = b"\xff" + Bytes::make(31, b'\x00')

let res = @cttest.dudect_compare(
  "bytes_eq_naive 32B early_diff vs all_eq",
  () => { let _ = @cttest.bytes_eq_naive(a, b_diff) },
  () => { let _ = @cttest.bytes_eq_naive(a, b_eq) },
)
// res.t, res.leak_detected, res.mean_a_us, res.mean_b_us, ...
```

## API

### cttest.mbt — reference implementations

| Symbol | Type | Description |
|---|---|---|
| `bytes_eq_naive` | `(Bytes, Bytes) -> Bool` | early-return; deliberately leaky |
| `bytes_eq_xorfold` | `(Bytes, Bytes) -> Bool` | XOR-fold; branchless at source level |
| `select_branch` | `(Bool, Bytes, Bytes) -> Bytes` | `if cond { a } else { b }` |
| `select_mask` | `(Int, Bytes, Bytes) -> Bytes` | byte-wise mask select; `cond` ∈ {0x00, 0xFF} |

### dudect.mbt — timing-leak detector

| Symbol | Type | Description |
|---|---|---|
| `CtResult` | `struct { name, n_batches, batch_size, mean_a_us, mean_b_us, std_a_us, std_b_us, t, threshold, leak_detected }` | – |
| `dudect_compare` | `(String, () -> Unit, () -> Unit, batch_size~, n_batches~, warmup_batches~, threshold~, crop_top_pct~) -> CtResult` | Welch *t* on per-batch means |

Defaults: `batch_size = 5000`, `n_batches = 200`, `warmup_batches = 20`,
`crop_top_pct = 5.0`, `threshold = 4.5` (≈ p < 1e-5; dudect convention).

## References

- [`REPORT.md`](REPORT.md) — empirical measurements + interpretation + limitations
- [`../secp256k1/SECURITY.md`](../secp256k1/SECURITY.md) — the security
  position this report supports
- Reparaz, Balasch, Verbauwhede (2017), "Dude, is my code constant time?"
- noble-curves security note:
  <https://github.com/paulmillr/noble-curves#security>
