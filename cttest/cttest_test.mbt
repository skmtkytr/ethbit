// Sanity tests — both implementations must agree on a range of inputs.

fn mk(n : Int, fill : Byte) -> Bytes {
  Bytes::make(n, fill)
}

test "bytes_eq agreement: identical 32B" {
  let a = mk(32, b'\xab')
  let b = mk(32, b'\xab')
  assert_eq(@cttest.bytes_eq_naive(a, b), true)
  assert_eq(@cttest.bytes_eq_xorfold(a, b), true)
}

test "bytes_eq agreement: differ at byte 0" {
  let a = mk(32, b'\x00')
  let b = mk(32, b'\x00')
  let arr_a : Array[Byte] = Array::make(32, b'\x00')
  for i = 0; i < 32; i = i + 1 {
    arr_a[i] = a[i]
  }
  arr_a[0] = b'\xff'
  let a2 = Bytes::from_array(arr_a[:])
  assert_eq(@cttest.bytes_eq_naive(a2, b), false)
  assert_eq(@cttest.bytes_eq_xorfold(a2, b), false)
}

test "bytes_eq agreement: differ at last byte" {
  let a = mk(32, b'\x00')
  let arr_b : Array[Byte] = Array::make(32, b'\x00')
  arr_b[31] = b'\xff'
  let b = Bytes::from_array(arr_b[:])
  assert_eq(@cttest.bytes_eq_naive(a, b), false)
  assert_eq(@cttest.bytes_eq_xorfold(a, b), false)
}

test "bytes_eq agreement: length mismatch" {
  assert_eq(@cttest.bytes_eq_naive(mk(31, b'\x00'), mk(32, b'\x00')), false)
  assert_eq(@cttest.bytes_eq_xorfold(mk(31, b'\x00'), mk(32, b'\x00')), false)
}

test "select_mask: cond=0xFF picks a" {
  let a = mk(8, b'\xaa')
  let b = mk(8, b'\xbb')
  assert_eq(@cttest.select_mask(0xFF, a, b), a)
}

test "select_mask: cond=0x00 picks b" {
  let a = mk(8, b'\xaa')
  let b = mk(8, b'\xbb')
  assert_eq(@cttest.select_mask(0x00, a, b), b)
}

test "select_branch: agrees with select_mask on both polarities" {
  let a = mk(8, b'\xaa')
  let b = mk(8, b'\xbb')
  assert_eq(@cttest.select_branch(true, a, b), @cttest.select_mask(0xFF, a, b))
  assert_eq(@cttest.select_branch(false, a, b), @cttest.select_mask(0x00, a, b))
}
