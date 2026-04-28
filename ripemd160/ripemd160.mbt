// RIPEMD-160 (Dobbertin/Bosselaers/Preneel, 1996) in pure MoonBit.
// Output is unconditionally 20 bytes.
//
// 32-bit little-endian words; 512-bit (64-byte) blocks; two parallel pipelines
// of 5 rounds x 16 ops each.

const BLOCK_BYTES : Int = 64

let h0 : FixedArray[UInt] = [
  0x67452301U, 0xEFCDAB89U, 0x98BADCFEU, 0x10325476U, 0xC3D2E1F0U,
]

// Message word selection r (left line), 80 entries.
let r_left : FixedArray[Int] = [
  0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
  7, 4, 13, 1, 10, 6, 15, 3, 12, 0, 9, 5, 2, 14, 11, 8,
  3, 10, 14, 4, 9, 15, 8, 1, 2, 7, 0, 6, 13, 11, 5, 12,
  1, 9, 11, 10, 0, 8, 12, 4, 13, 3, 7, 15, 14, 5, 6, 2,
  4, 0, 5, 9, 7, 12, 2, 10, 14, 1, 3, 8, 11, 6, 15, 13,
]

// Message word selection r' (right line), 80 entries.
let r_right : FixedArray[Int] = [
  5, 14, 7, 0, 9, 2, 11, 4, 13, 6, 15, 8, 1, 10, 3, 12,
  6, 11, 3, 7, 0, 13, 5, 10, 14, 15, 8, 12, 4, 9, 1, 2,
  15, 5, 1, 3, 7, 14, 6, 9, 11, 8, 12, 2, 10, 0, 4, 13,
  8, 6, 4, 1, 3, 11, 15, 0, 5, 12, 2, 13, 9, 7, 10, 14,
  12, 15, 10, 4, 1, 5, 8, 7, 6, 2, 13, 14, 0, 3, 9, 11,
]

// Rotation amounts s (left line), 80 entries.
let s_left : FixedArray[Int] = [
  11, 14, 15, 12, 5, 8, 7, 9, 11, 13, 14, 15, 6, 7, 9, 8,
  7, 6, 8, 13, 11, 9, 7, 15, 7, 12, 15, 9, 11, 7, 13, 12,
  11, 13, 6, 7, 14, 9, 13, 15, 14, 8, 13, 6, 5, 12, 7, 5,
  11, 12, 14, 15, 14, 15, 9, 8, 9, 14, 5, 6, 8, 6, 5, 12,
  9, 15, 5, 11, 6, 8, 13, 12, 5, 12, 13, 14, 11, 8, 5, 6,
]

// Rotation amounts s' (right line), 80 entries.
let s_right : FixedArray[Int] = [
  8, 9, 9, 11, 13, 15, 15, 5, 7, 7, 8, 11, 14, 14, 12, 6,
  9, 13, 15, 7, 12, 8, 9, 11, 7, 7, 12, 7, 6, 15, 13, 11,
  9, 7, 15, 11, 8, 6, 6, 14, 12, 13, 5, 14, 13, 13, 7, 5,
  15, 5, 8, 11, 14, 14, 6, 14, 6, 9, 12, 9, 12, 5, 15, 8,
  8, 5, 12, 9, 12, 5, 14, 6, 8, 13, 6, 5, 15, 13, 11, 11,
]

// Round constants K (left) and K' (right), one per round.
let k_left : FixedArray[UInt] = [
  0x00000000U, 0x5A827999U, 0x6ED9EBA1U, 0x8F1BBCDCU, 0xA953FD4EU,
]

let k_right : FixedArray[UInt] = [
  0x50A28BE6U, 0x5C4DD124U, 0x6D703EF3U, 0x7A6D76E9U, 0x00000000U,
]

fn rotl(x : UInt, n : Int) -> UInt {
  (x << n) | (x >> (32 - n))
}

// Boolean round functions.
fn f_func(x : UInt, y : UInt, z : UInt) -> UInt {
  x ^ y ^ z
}

fn g_func(x : UInt, y : UInt, z : UInt) -> UInt {
  (x & y) | (x.lnot() & z)
}

fn h_func(x : UInt, y : UInt, z : UInt) -> UInt {
  (x | y.lnot()) ^ z
}

fn i_func(x : UInt, y : UInt, z : UInt) -> UInt {
  (x & z) | (y & z.lnot())
}

fn j_func(x : UInt, y : UInt, z : UInt) -> UInt {
  x ^ (y | z.lnot())
}

// Apply the round function for the left pipeline at step j.
// Left order: f -> g -> h -> i -> j (rounds 0..4).
fn left_round(round : Int, x : UInt, y : UInt, z : UInt) -> UInt {
  if round == 0 {
    f_func(x, y, z)
  } else if round == 1 {
    g_func(x, y, z)
  } else if round == 2 {
    h_func(x, y, z)
  } else if round == 3 {
    i_func(x, y, z)
  } else {
    j_func(x, y, z)
  }
}

// Apply the round function for the right pipeline at step j.
// Right order: j -> i -> h -> g -> f (rounds 0..4).
fn right_round(round : Int, x : UInt, y : UInt, z : UInt) -> UInt {
  if round == 0 {
    j_func(x, y, z)
  } else if round == 1 {
    i_func(x, y, z)
  } else if round == 2 {
    h_func(x, y, z)
  } else if round == 3 {
    g_func(x, y, z)
  } else {
    f_func(x, y, z)
  }
}

fn process_block(h : FixedArray[UInt], data : Bytes, offset : Int) -> Unit {
  // Decode 16 little-endian 32-bit words.
  let m : FixedArray[UInt] = FixedArray::make(16, 0U)
  for i = 0; i < 16; i = i + 1 {
    let p = offset + i * 4
    m[i] = data[p].to_uint() |
      (data[p + 1].to_uint() << 8) |
      (data[p + 2].to_uint() << 16) |
      (data[p + 3].to_uint() << 24)
  }
  let mut a = h[0]
  let mut b = h[1]
  let mut c = h[2]
  let mut d = h[3]
  let mut e = h[4]
  let mut a2 = h[0]
  let mut b2 = h[1]
  let mut c2 = h[2]
  let mut d2 = h[3]
  let mut e2 = h[4]
  for j = 0; j < 80; j = j + 1 {
    let round = j / 16
    // Left pipeline.
    let t_left = rotl(
        a + left_round(round, b, c, d) + m[r_left[j]] + k_left[round],
        s_left[j],
      ) +
      e
    a = e
    e = d
    d = rotl(c, 10)
    c = b
    b = t_left
    // Right pipeline.
    let t_right = rotl(
        a2 + right_round(round, b2, c2, d2) + m[r_right[j]] + k_right[round],
        s_right[j],
      ) +
      e2
    a2 = e2
    e2 = d2
    d2 = rotl(c2, 10)
    c2 = b2
    b2 = t_right
  }
  // Combine.
  let t = h[1] + c + d2
  h[1] = h[2] + d + e2
  h[2] = h[3] + e + a2
  h[3] = h[4] + a + b2
  h[4] = h[0] + b + c2
  h[0] = t
}

fn pad(input : Bytes) -> Bytes {
  let len = input.length()
  let bit_len : UInt64 = (len * 8).to_uint64()
  // We need: len + 1 + zeros + 8 ≡ 0 (mod 64), zeros >= 0.
  let rem = (len + 1) % BLOCK_BYTES
  let zeros = if rem <= 56 {
    56 - rem
  } else {
    56 + (BLOCK_BYTES - rem)
  }
  let total = len + 1 + zeros + 8
  let out : Array[Byte] = Array::make(total, b'\x00')
  for i = 0; i < len; i = i + 1 {
    out[i] = input[i]
  }
  out[len] = b'\x80'
  // bit length, little-endian, last 8 bytes.
  for i = 0; i < 8; i = i + 1 {
    let shift = i * 8
    out[total - 8 + i] = ((bit_len >> shift) & 0xFFUL).to_byte()
  }
  Bytes::from_array(out[:])
}

///|
/// Compute RIPEMD-160 of `input`. Returns 20 bytes.
pub fn ripemd160(input : Bytes) -> Bytes {
  let h : FixedArray[UInt] = FixedArray::make(5, 0U)
  for i = 0; i < 5; i = i + 1 {
    h[i] = h0[i]
  }
  let padded = pad(input)
  let n_blocks = padded.length() / BLOCK_BYTES
  for blk = 0; blk < n_blocks; blk = blk + 1 {
    process_block(h, padded, blk * BLOCK_BYTES)
  }
  let out : Array[Byte] = Array::make(20, b'\x00')
  for i = 0; i < 5; i = i + 1 {
    let v = h[i]
    out[i * 4] = (v & 0xFFU).reinterpret_as_int().to_byte()
    out[i * 4 + 1] = ((v >> 8) & 0xFFU).reinterpret_as_int().to_byte()
    out[i * 4 + 2] = ((v >> 16) & 0xFFU).reinterpret_as_int().to_byte()
    out[i * 4 + 3] = ((v >> 24) & 0xFFU).reinterpret_as_int().to_byte()
  }
  Bytes::from_array(out[:])
}
