// dudect-style tests: run dudect_compare on each pair of {function, input class}
// and print verdicts. The framework itself is sanity-checked first.
//
// We do not `assert` on leak/no-leak because results carry a small probability
// of false positives/negatives. The test suite always passes; each test
// prints a CtResult that the operator inspects.

priv struct DudSink {
  mut x : Int
}

fn b2i(b : Bool) -> Int {
  if b {
    1
  } else {
    0
  }
}

fn dud_buf(n : Int, fill : Byte) -> Bytes {
  Bytes::make(n, fill)
}

fn dud_early_diff_pair(n : Int) -> (Bytes, Bytes) {
  let arr : Array[Byte] = Array::make(n, b'\x00')
  arr[0] = b'\xff'
  (Bytes::from_array(arr[:]), dud_buf(n, b'\x00'))
}

fn dud_all_eq_pair(n : Int) -> (Bytes, Bytes) {
  (dud_buf(n, b'\x00'), dud_buf(n, b'\x00'))
}

// ---------- sanity (negative control) ----------

test "dudect sanity A: same closure object both sides" {
  let (a, b) = dud_early_diff_pair(1024)
  let sink : DudSink = { x: 0 }
  let f = fn() {
    let v = @cttest.bytes_eq_naive(a, b)
    sink.x = sink.x ^ b2i(v)
  }
  let r = @cttest.dudect_compare("sanity-same-closure", f, f)
  println(r)
  let _ = sink.x

}

test "dudect sanity B: distinct closures, identical body" {
  let (a, b) = dud_early_diff_pair(1024)
  let sink : DudSink = { x: 0 }
  let r = @cttest.dudect_compare(
    "sanity-twin-closures",
    fn() {
      let v = @cttest.bytes_eq_naive(a, b)
      sink.x = sink.x ^ b2i(v)
    },
    fn() {
      let v = @cttest.bytes_eq_naive(a, b)
      sink.x = sink.x ^ b2i(v)
    },
  )
  println(r)
  let _ = sink.x

}

// ---------- bytes_eq_naive (expected leak) ----------

test "dudect: bytes_eq_naive 1KB early_diff vs all_eq" {
  let (a1, b1) = dud_early_diff_pair(1024)
  let (a2, b2) = dud_all_eq_pair(1024)
  let sink : DudSink = { x: 0 }
  let r = @cttest.dudect_compare(
    "naive-1KB",
    fn() {
      let v = @cttest.bytes_eq_naive(a1, b1)
      sink.x = sink.x ^ b2i(v)
    },
    fn() {
      let v = @cttest.bytes_eq_naive(a2, b2)
      sink.x = sink.x ^ b2i(v)
    },
  )
  println(r)
  let _ = sink.x

}

test "dudect: bytes_eq_naive 32B early_diff vs all_eq" {
  let (a1, b1) = dud_early_diff_pair(32)
  let (a2, b2) = dud_all_eq_pair(32)
  let sink : DudSink = { x: 0 }
  let r = @cttest.dudect_compare(
    "naive-32B",
    fn() {
      let v = @cttest.bytes_eq_naive(a1, b1)
      sink.x = sink.x ^ b2i(v)
    },
    fn() {
      let v = @cttest.bytes_eq_naive(a2, b2)
      sink.x = sink.x ^ b2i(v)
    },
  )
  println(r)
  let _ = sink.x

}

// ---------- bytes_eq_xorfold (expected no leak) ----------

test "dudect: bytes_eq_xorfold 1KB early_diff vs all_eq" {
  let (a1, b1) = dud_early_diff_pair(1024)
  let (a2, b2) = dud_all_eq_pair(1024)
  let sink : DudSink = { x: 0 }
  let r = @cttest.dudect_compare(
    "xorfold-1KB",
    fn() {
      let v = @cttest.bytes_eq_xorfold(a1, b1)
      sink.x = sink.x ^ b2i(v)
    },
    fn() {
      let v = @cttest.bytes_eq_xorfold(a2, b2)
      sink.x = sink.x ^ b2i(v)
    },
  )
  println(r)
  let _ = sink.x

}

test "dudect: bytes_eq_xorfold 32B early_diff vs all_eq" {
  let (a1, b1) = dud_early_diff_pair(32)
  let (a2, b2) = dud_all_eq_pair(32)
  let sink : DudSink = { x: 0 }
  let r = @cttest.dudect_compare(
    "xorfold-32B",
    fn() {
      let v = @cttest.bytes_eq_xorfold(a1, b1)
      sink.x = sink.x ^ b2i(v)
    },
    fn() {
      let v = @cttest.bytes_eq_xorfold(a2, b2)
      sink.x = sink.x ^ b2i(v)
    },
  )
  println(r)
  let _ = sink.x

}

// ---------- select_branch / select_mask ----------

test "dudect: select_branch 32B cond=true vs false" {
  let a = dud_buf(32, b'\xaa')
  let b = dud_buf(32, b'\xbb')
  let sink : DudSink = { x: 0 }
  let r = @cttest.dudect_compare(
    "select_branch-32B",
    fn() {
      let v = @cttest.select_branch(true, a, b)
      sink.x = sink.x ^ v.length()
    },
    fn() {
      let v = @cttest.select_branch(false, a, b)
      sink.x = sink.x ^ v.length()
    },
  )
  println(r)
  let _ = sink.x

}

test "dudect: select_mask 32B cond=0xFF vs 0x00" {
  let a = dud_buf(32, b'\xaa')
  let b = dud_buf(32, b'\xbb')
  let sink : DudSink = { x: 0 }
  let r = @cttest.dudect_compare(
    "select_mask-32B",
    fn() {
      let v = @cttest.select_mask(0xFF, a, b)
      sink.x = sink.x ^ v.length()
    },
    fn() {
      let v = @cttest.select_mask(0x00, a, b)
      sink.x = sink.x ^ v.length()
    },
  )
  println(r)
  let _ = sink.x

}
