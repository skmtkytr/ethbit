// SHA-1 (FIPS 180-4) in pure MoonBit. Used only by the WebSocket handshake
// (Sec-WebSocket-Accept), so kept private to this package. SHA-1 is broken
// for collision-resistance and MUST NOT be used elsewhere.
//
// 32-bit words, big-endian. 80 rounds, four round constants K and the
// initial hash H_0 are fixed by the spec.

const SHA1_BLOCK_BYTES : Int = 64

let sha1_h0 : FixedArray[UInt] = [
  0x67452301U, 0xEFCDAB89U, 0x98BADCFEU, 0x10325476U, 0xC3D2E1F0U,
]

fn rotl32(x : UInt, n : Int) -> UInt {
  (x << n) | (x >> (32 - n))
}

fn sha1_process_block(h : FixedArray[UInt], data : Bytes, offset : Int) -> Unit {
  let w : FixedArray[UInt] = FixedArray::make(80, 0U)
  for i = 0; i < 16; i = i + 1 {
    let p = offset + i * 4
    w[i] = (data[p].to_uint() << 24) |
      (data[p + 1].to_uint() << 16) |
      (data[p + 2].to_uint() << 8) |
      data[p + 3].to_uint()
  }
  for i = 16; i < 80; i = i + 1 {
    w[i] = rotl32(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1)
  }
  let mut a = h[0]
  let mut b = h[1]
  let mut c = h[2]
  let mut d = h[3]
  let mut e = h[4]
  for t = 0; t < 80; t = t + 1 {
    let (f, k) = if t < 20 {
      ((b & c) | (b.lnot() & d), 0x5A827999U)
    } else if t < 40 {
      (b ^ c ^ d, 0x6ED9EBA1U)
    } else if t < 60 {
      ((b & c) | (b & d) | (c & d), 0x8F1BBCDCU)
    } else {
      (b ^ c ^ d, 0xCA62C1D6U)
    }
    let temp = rotl32(a, 5) + f + e + k + w[t]
    e = d
    d = c
    c = rotl32(b, 30)
    b = a
    a = temp
  }
  h[0] = h[0] + a
  h[1] = h[1] + b
  h[2] = h[2] + c
  h[3] = h[3] + d
  h[4] = h[4] + e
}

fn sha1_pad(input : Bytes) -> Bytes {
  let len = input.length()
  let bit_len : UInt64 = (len * 8).to_uint64()
  // Append 0x80, then zeros, then 8-byte big-endian bit length, padded to a
  // multiple of 64 bytes.
  let rem = (len + 1) % SHA1_BLOCK_BYTES
  let zeros = if rem <= 56 {
    56 - rem
  } else {
    56 + (SHA1_BLOCK_BYTES - rem)
  }
  let total = len + 1 + zeros + 8
  let out : Array[Byte] = Array::make(total, b'\x00')
  for i = 0; i < len; i = i + 1 {
    out[i] = input[i]
  }
  out[len] = b'\x80'
  for i = 0; i < 8; i = i + 1 {
    let shift = (7 - i) * 8
    out[total - 8 + i] = ((bit_len >> shift) & 0xFFUL).to_byte()
  }
  Bytes::from_array(out[:])
}

///|
/// SHA-1 of `input`. Returns 20 bytes. Package-private — only the WebSocket
/// handshake (Sec-WebSocket-Accept) uses this.
fn sha1(input : Bytes) -> Bytes {
  let h : FixedArray[UInt] = FixedArray::make(5, 0U)
  for i = 0; i < 5; i = i + 1 {
    h[i] = sha1_h0[i]
  }
  let padded = sha1_pad(input)
  let n_blocks = padded.length() / SHA1_BLOCK_BYTES
  for blk = 0; blk < n_blocks; blk = blk + 1 {
    sha1_process_block(h, padded, blk * SHA1_BLOCK_BYTES)
  }
  let out : Array[Byte] = Array::make(20, b'\x00')
  for i = 0; i < 5; i = i + 1 {
    let v = h[i]
    out[i * 4] = ((v >> 24) & 0xFFU).reinterpret_as_int().to_byte()
    out[i * 4 + 1] = ((v >> 16) & 0xFFU).reinterpret_as_int().to_byte()
    out[i * 4 + 2] = ((v >> 8) & 0xFFU).reinterpret_as_int().to_byte()
    out[i * 4 + 3] = (v & 0xFFU).reinterpret_as_int().to_byte()
  }
  Bytes::from_array(out[:])
}
