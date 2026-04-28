// Constant-time test bed.
//
// Two implementations of byte-array equality and one of conditional select.
// Each is exercised under "extreme" inputs in cttest_bench_test.mbt to see
// whether wall-clock timing is observably correlated with the input contents.
//
// This is NOT a proof of constant-time-ness. A null result here is a lower
// bound: we did not see a leak at this scale, on this target, with this
// compiler. The language does not promise constant-time semantics.

///|
/// Early-return on first mismatch. Timing depends on prefix-match length.
pub fn bytes_eq_naive(a : Bytes, b : Bytes) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i = 0; i < a.length(); i = i + 1 {
    if a[i] != b[i] {
      return false
    }
  }
  true
}

///|
/// XOR-fold across all bytes; visits every index regardless of contents.
/// "Branchless" only at source level — the compiler is free to lower this
/// however it wants, including reintroducing branches (e.g. for bounds checks).
pub fn bytes_eq_xorfold(a : Bytes, b : Bytes) -> Bool {
  if a.length() != b.length() {
    return false
  }
  let mut acc : Int = 0
  for i = 0; i < a.length(); i = i + 1 {
    acc = acc | (a[i].to_int() ^ b[i].to_int())
  }
  acc == 0
}

///|
/// Mask-based byte-wise select between `a` and `b`.
/// `cond` must be 0xFF (pick `a`) or 0x00 (pick `b`).
/// Visits every index; no source-level branch on `cond`.
pub fn select_mask(cond : Int, a : Bytes, b : Bytes) -> Bytes {
  let n = a.length()
  let m = cond & 0xFF
  let nm = m ^ 0xFF
  let out : Array[Byte] = Array::make(n, b'\x00')
  for i = 0; i < n; i = i + 1 {
    let av = a[i].to_int()
    let bv = b[i].to_int()
    out[i] = ((av & m) | (bv & nm)).to_byte()
  }
  Bytes::from_array(out[:])
}

///|
/// Source-level `if` select. Returns the chosen Bytes by reference; no copy.
/// Timing is dominated by the branch decision, not the data.
pub fn select_branch(cond : Bool, a : Bytes, b : Bytes) -> Bytes {
  if cond {
    a
  } else {
    b
  }
}
