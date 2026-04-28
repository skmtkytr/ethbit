// SHA-512 (FIPS 180-4) in pure MoonBit.
// Output is unconditionally 64 bytes.

const BLOCK_BYTES : Int = 128

let h0 : FixedArray[UInt64] = [
  0x6a09e667f3bcc908UL, 0xbb67ae8584caa73bUL, 0x3c6ef372fe94f82bUL,
  0xa54ff53a5f1d36f1UL, 0x510e527fade682d1UL, 0x9b05688c2b3e6c1fUL,
  0x1f83d9abfb41bd6bUL, 0x5be0cd19137e2179UL,
]

let k_table : FixedArray[UInt64] = [
  0x428a2f98d728ae22UL, 0x7137449123ef65cdUL, 0xb5c0fbcfec4d3b2fUL,
  0xe9b5dba58189dbbcUL, 0x3956c25bf348b538UL, 0x59f111f1b605d019UL,
  0x923f82a4af194f9bUL, 0xab1c5ed5da6d8118UL, 0xd807aa98a3030242UL,
  0x12835b0145706fbeUL, 0x243185be4ee4b28cUL, 0x550c7dc3d5ffb4e2UL,
  0x72be5d74f27b896fUL, 0x80deb1fe3b1696b1UL, 0x9bdc06a725c71235UL,
  0xc19bf174cf692694UL, 0xe49b69c19ef14ad2UL, 0xefbe4786384f25e3UL,
  0x0fc19dc68b8cd5b5UL, 0x240ca1cc77ac9c65UL, 0x2de92c6f592b0275UL,
  0x4a7484aa6ea6e483UL, 0x5cb0a9dcbd41fbd4UL, 0x76f988da831153b5UL,
  0x983e5152ee66dfabUL, 0xa831c66d2db43210UL, 0xb00327c898fb213fUL,
  0xbf597fc7beef0ee4UL, 0xc6e00bf33da88fc2UL, 0xd5a79147930aa725UL,
  0x06ca6351e003826fUL, 0x142929670a0e6e70UL, 0x27b70a8546d22ffcUL,
  0x2e1b21385c26c926UL, 0x4d2c6dfc5ac42aedUL, 0x53380d139d95b3dfUL,
  0x650a73548baf63deUL, 0x766a0abb3c77b2a8UL, 0x81c2c92e47edaee6UL,
  0x92722c851482353bUL, 0xa2bfe8a14cf10364UL, 0xa81a664bbc423001UL,
  0xc24b8b70d0f89791UL, 0xc76c51a30654be30UL, 0xd192e819d6ef5218UL,
  0xd69906245565a910UL, 0xf40e35855771202aUL, 0x106aa07032bbd1b8UL,
  0x19a4c116b8d2d0c8UL, 0x1e376c085141ab53UL, 0x2748774cdf8eeb99UL,
  0x34b0bcb5e19b48a8UL, 0x391c0cb3c5c95a63UL, 0x4ed8aa4ae3418acbUL,
  0x5b9cca4f7763e373UL, 0x682e6ff3d6b2b8a3UL, 0x748f82ee5defb2fcUL,
  0x78a5636f43172f60UL, 0x84c87814a1f0ab72UL, 0x8cc702081a6439ecUL,
  0x90befffa23631e28UL, 0xa4506cebde82bde9UL, 0xbef9a3f7b2c67915UL,
  0xc67178f2e372532bUL, 0xca273eceea26619cUL, 0xd186b8c721c0c207UL,
  0xeada7dd6cde0eb1eUL, 0xf57d4f7fee6ed178UL, 0x06f067aa72176fbaUL,
  0x0a637dc5a2c898a6UL, 0x113f9804bef90daeUL, 0x1b710b35131c471bUL,
  0x28db77f523047d84UL, 0x32caab7b40c72493UL, 0x3c9ebe0a15c9bebcUL,
  0x431d67c49c100d4cUL, 0x4cc5d4becb3e42b6UL, 0x597f299cfc657e2aUL,
  0x5fcb6fab3ad6faecUL, 0x6c44198c4a475817UL,
]

fn rotr64(x : UInt64, n : Int) -> UInt64 {
  (x >> n) | (x << (64 - n))
}

fn big_sigma0(x : UInt64) -> UInt64 {
  rotr64(x, 28) ^ rotr64(x, 34) ^ rotr64(x, 39)
}

fn big_sigma1(x : UInt64) -> UInt64 {
  rotr64(x, 14) ^ rotr64(x, 18) ^ rotr64(x, 41)
}

fn small_sigma0(x : UInt64) -> UInt64 {
  rotr64(x, 1) ^ rotr64(x, 8) ^ (x >> 7)
}

fn small_sigma1(x : UInt64) -> UInt64 {
  rotr64(x, 19) ^ rotr64(x, 61) ^ (x >> 6)
}

fn ch(x : UInt64, y : UInt64, z : UInt64) -> UInt64 {
  (x & y) ^ (x.lnot() & z)
}

fn maj(x : UInt64, y : UInt64, z : UInt64) -> UInt64 {
  (x & y) ^ (x & z) ^ (y & z)
}

fn process_block(h : FixedArray[UInt64], data : Bytes, offset : Int) -> Unit {
  let w : FixedArray[UInt64] = FixedArray::make(80, 0UL)
  for i = 0; i < 16; i = i + 1 {
    let p = offset + i * 8
    w[i] = (data[p].to_uint64() << 56) |
      (data[p + 1].to_uint64() << 48) |
      (data[p + 2].to_uint64() << 40) |
      (data[p + 3].to_uint64() << 32) |
      (data[p + 4].to_uint64() << 24) |
      (data[p + 5].to_uint64() << 16) |
      (data[p + 6].to_uint64() << 8) |
      data[p + 7].to_uint64()
  }
  for i = 16; i < 80; i = i + 1 {
    w[i] = small_sigma1(w[i - 2]) + w[i - 7] + small_sigma0(w[i - 15]) +
      w[i - 16]
  }
  let mut a = h[0]
  let mut b = h[1]
  let mut c = h[2]
  let mut d = h[3]
  let mut e = h[4]
  let mut f = h[5]
  let mut g = h[6]
  let mut hh = h[7]
  for t = 0; t < 80; t = t + 1 {
    let t1 = hh + big_sigma1(e) + ch(e, f, g) + k_table[t] + w[t]
    let t2 = big_sigma0(a) + maj(a, b, c)
    hh = g
    g = f
    f = e
    e = d + t1
    d = c
    c = b
    b = a
    a = t1 + t2
  }
  h[0] = h[0] + a
  h[1] = h[1] + b
  h[2] = h[2] + c
  h[3] = h[3] + d
  h[4] = h[4] + e
  h[5] = h[5] + f
  h[6] = h[6] + g
  h[7] = h[7] + hh
}

fn pad(input : Bytes) -> Bytes {
  let len = input.length()
  let bit_len : UInt64 = (len * 8).to_uint64()
  // We need: len + 1 + zeros + 16 ≡ 0 (mod 128), zeros >= 0
  let rem = (len + 1) % BLOCK_BYTES
  let zeros = if rem <= 112 {
    112 - rem
  } else {
    112 + (BLOCK_BYTES - rem)
  }
  let total = len + 1 + zeros + 16
  let out : Array[Byte] = Array::make(total, b'\x00')
  for i = 0; i < len; i = i + 1 {
    out[i] = input[i]
  }
  out[len] = b'\x80'
  // bit length, big-endian, last 16 bytes (high 8 bytes are 0 for messages
  // shorter than 2^64 bits, which is the case for any practical input).
  for i = 0; i < 8; i = i + 1 {
    let shift = (7 - i) * 8
    out[total - 8 + i] = ((bit_len >> shift) & 0xFFUL).to_byte()
  }
  Bytes::from_array(out[:])
}

///|
/// Compute SHA-512 of `input`. Returns 64 bytes.
pub fn sha512(input : Bytes) -> Bytes {
  let h : FixedArray[UInt64] = FixedArray::make(8, 0UL)
  for i = 0; i < 8; i = i + 1 {
    h[i] = h0[i]
  }
  let padded = pad(input)
  let n_blocks = padded.length() / BLOCK_BYTES
  for blk = 0; blk < n_blocks; blk = blk + 1 {
    process_block(h, padded, blk * BLOCK_BYTES)
  }
  let out : Array[Byte] = Array::make(64, b'\x00')
  for i = 0; i < 8; i = i + 1 {
    let v = h[i]
    out[i * 8] = ((v >> 56) & 0xFFUL).to_byte()
    out[i * 8 + 1] = ((v >> 48) & 0xFFUL).to_byte()
    out[i * 8 + 2] = ((v >> 40) & 0xFFUL).to_byte()
    out[i * 8 + 3] = ((v >> 32) & 0xFFUL).to_byte()
    out[i * 8 + 4] = ((v >> 24) & 0xFFUL).to_byte()
    out[i * 8 + 5] = ((v >> 16) & 0xFFUL).to_byte()
    out[i * 8 + 6] = ((v >> 8) & 0xFFUL).to_byte()
    out[i * 8 + 7] = (v & 0xFFUL).to_byte()
  }
  Bytes::from_array(out[:])
}
