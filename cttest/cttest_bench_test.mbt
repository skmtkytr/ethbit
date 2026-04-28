// Differential timing bench.
//
// For each implementation, two extreme inputs are exercised:
//   - early_diff: a and b differ at byte 0 (first iteration mismatches)
//   - all_eq:    a and b are bytewise equal (loop runs to completion)
// If timing varies between the two extremes, the implementation leaks the
// position of the first mismatch through wall-clock time.
//
// Sizes: 32B (Ethereum scalar / hash word) and 1KB (amplifies any per-byte gap).

fn buf(n : Int, fill : Byte) -> Bytes {
  Bytes::make(n, fill)
}

fn early_diff_pair(n : Int) -> (Bytes, Bytes) {
  let a_arr : Array[Byte] = Array::make(n, b'\x00')
  a_arr[0] = b'\xff'
  (Bytes::from_array(a_arr[:]), buf(n, b'\x00'))
}

fn all_eq_pair(n : Int) -> (Bytes, Bytes) {
  (buf(n, b'\x00'), buf(n, b'\x00'))
}

// ---- naive (early-return) ----

test "naive 32B early_diff" (it : @bench.T) {
  let (a, b) = early_diff_pair(32)
  it.bench(fn() { it.keep(@cttest.bytes_eq_naive(a, b)) })
}

test "naive 32B all_eq" (it : @bench.T) {
  let (a, b) = all_eq_pair(32)
  it.bench(fn() { it.keep(@cttest.bytes_eq_naive(a, b)) })
}

test "naive 1KB early_diff" (it : @bench.T) {
  let (a, b) = early_diff_pair(1024)
  it.bench(fn() { it.keep(@cttest.bytes_eq_naive(a, b)) })
}

test "naive 1KB all_eq" (it : @bench.T) {
  let (a, b) = all_eq_pair(1024)
  it.bench(fn() { it.keep(@cttest.bytes_eq_naive(a, b)) })
}

// ---- xorfold ("branchless" at source level) ----

test "xorfold 32B early_diff" (it : @bench.T) {
  let (a, b) = early_diff_pair(32)
  it.bench(fn() { it.keep(@cttest.bytes_eq_xorfold(a, b)) })
}

test "xorfold 32B all_eq" (it : @bench.T) {
  let (a, b) = all_eq_pair(32)
  it.bench(fn() { it.keep(@cttest.bytes_eq_xorfold(a, b)) })
}

test "xorfold 1KB early_diff" (it : @bench.T) {
  let (a, b) = early_diff_pair(1024)
  it.bench(fn() { it.keep(@cttest.bytes_eq_xorfold(a, b)) })
}

test "xorfold 1KB all_eq" (it : @bench.T) {
  let (a, b) = all_eq_pair(1024)
  it.bench(fn() { it.keep(@cttest.bytes_eq_xorfold(a, b)) })
}

// ---- conditional select: branch vs mask ----

test "select_branch 32B cond=true" (it : @bench.T) {
  let a = buf(32, b'\xaa')
  let b = buf(32, b'\xbb')
  it.bench(fn() { it.keep(@cttest.select_branch(true, a, b)) })
}

test "select_branch 32B cond=false" (it : @bench.T) {
  let a = buf(32, b'\xaa')
  let b = buf(32, b'\xbb')
  it.bench(fn() { it.keep(@cttest.select_branch(false, a, b)) })
}

test "select_mask 32B cond=0xFF" (it : @bench.T) {
  let a = buf(32, b'\xaa')
  let b = buf(32, b'\xbb')
  it.bench(fn() { it.keep(@cttest.select_mask(0xFF, a, b)) })
}

test "select_mask 32B cond=0x00" (it : @bench.T) {
  let a = buf(32, b'\xaa')
  let b = buf(32, b'\xbb')
  it.bench(fn() { it.keep(@cttest.select_mask(0x00, a, b)) })
}
