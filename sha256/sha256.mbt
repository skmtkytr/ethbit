// SHA-256 (FIPS 180-4) in pure MoonBit.
// Output is unconditionally 32 bytes.

const BLOCK_BYTES : Int = 64

let h0 : FixedArray[UInt] = [
  0x6a09e667U, 0xbb67ae85U, 0x3c6ef372U, 0xa54ff53aU, 0x510e527fU,
  0x9b05688cU, 0x1f83d9abU, 0x5be0cd19U,
]

let k_table : FixedArray[UInt] = [
  0x428a2f98U, 0x71374491U, 0xb5c0fbcfU, 0xe9b5dba5U, 0x3956c25bU,
  0x59f111f1U, 0x923f82a4U, 0xab1c5ed5U, 0xd807aa98U, 0x12835b01U,
  0x243185beU, 0x550c7dc3U, 0x72be5d74U, 0x80deb1feU, 0x9bdc06a7U,
  0xc19bf174U, 0xe49b69c1U, 0xefbe4786U, 0x0fc19dc6U, 0x240ca1ccU,
  0x2de92c6fU, 0x4a7484aaU, 0x5cb0a9dcU, 0x76f988daU, 0x983e5152U,
  0xa831c66dU, 0xb00327c8U, 0xbf597fc7U, 0xc6e00bf3U, 0xd5a79147U,
  0x06ca6351U, 0x14292967U, 0x27b70a85U, 0x2e1b2138U, 0x4d2c6dfcU,
  0x53380d13U, 0x650a7354U, 0x766a0abbU, 0x81c2c92eU, 0x92722c85U,
  0xa2bfe8a1U, 0xa81a664bU, 0xc24b8b70U, 0xc76c51a3U, 0xd192e819U,
  0xd6990624U, 0xf40e3585U, 0x106aa070U, 0x19a4c116U, 0x1e376c08U,
  0x2748774cU, 0x34b0bcb5U, 0x391c0cb3U, 0x4ed8aa4aU, 0x5b9cca4fU,
  0x682e6ff3U, 0x748f82eeU, 0x78a5636fU, 0x84c87814U, 0x8cc70208U,
  0x90befffaU, 0xa4506cebU, 0xbef9a3f7U, 0xc67178f2U,
]

fn rotr(x : UInt, n : Int) -> UInt {
  (x >> n) | (x << (32 - n))
}

fn big_sigma0(x : UInt) -> UInt {
  rotr(x, 2) ^ rotr(x, 13) ^ rotr(x, 22)
}

fn big_sigma1(x : UInt) -> UInt {
  rotr(x, 6) ^ rotr(x, 11) ^ rotr(x, 25)
}

fn small_sigma0(x : UInt) -> UInt {
  rotr(x, 7) ^ rotr(x, 18) ^ (x >> 3)
}

fn small_sigma1(x : UInt) -> UInt {
  rotr(x, 17) ^ rotr(x, 19) ^ (x >> 10)
}

fn ch(x : UInt, y : UInt, z : UInt) -> UInt {
  (x & y) ^ (x.lnot() & z)
}

fn maj(x : UInt, y : UInt, z : UInt) -> UInt {
  (x & y) ^ (x & z) ^ (y & z)
}

fn process_block(h : FixedArray[UInt], data : Bytes, offset : Int) -> Unit {
  let w : FixedArray[UInt] = FixedArray::make(64, 0U)
  for i = 0; i < 16; i = i + 1 {
    let p = offset + i * 4
    w[i] = (data[p].to_uint() << 24) |
      (data[p + 1].to_uint() << 16) |
      (data[p + 2].to_uint() << 8) |
      data[p + 3].to_uint()
  }
  for i = 16; i < 64; i = i + 1 {
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
  for t = 0; t < 64; t = t + 1 {
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
  // We need: len + 1 + zeros + 8 ≡ 0 (mod 64), zeros >= 0
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
  // bit length, big-endian, last 8 bytes
  for i = 0; i < 8; i = i + 1 {
    let shift = (7 - i) * 8
    out[total - 8 + i] = ((bit_len >> shift) & 0xFFUL).to_byte()
  }
  Bytes::from_array(out[:])
}

///|
/// Compute SHA-256 of `input`. Returns 32 bytes.
pub fn sha256(input : Bytes) -> Bytes {
  let h : FixedArray[UInt] = FixedArray::make(8, 0U)
  for i = 0; i < 8; i = i + 1 {
    h[i] = h0[i]
  }
  let padded = pad(input)
  let n_blocks = padded.length() / BLOCK_BYTES
  for blk = 0; blk < n_blocks; blk = blk + 1 {
    process_block(h, padded, blk * BLOCK_BYTES)
  }
  let out : Array[Byte] = Array::make(32, b'\x00')
  for i = 0; i < 8; i = i + 1 {
    let v = h[i]
    out[i * 4] = ((v >> 24) & 0xFFU).reinterpret_as_int().to_byte()
    out[i * 4 + 1] = ((v >> 16) & 0xFFU).reinterpret_as_int().to_byte()
    out[i * 4 + 2] = ((v >> 8) & 0xFFU).reinterpret_as_int().to_byte()
    out[i * 4 + 3] = (v & 0xFFU).reinterpret_as_int().to_byte()
  }
  Bytes::from_array(out[:])
}
