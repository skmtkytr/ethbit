// Pre-NIST Keccak-256 (Ethereum's variant). Spec: Keccak SHA-3 submission v3.
// Differs from NIST SHA3-256 only in the domain-separation byte during padding
// (Keccak: 0x01, SHA3: 0x06). Output is unconditionally 32 bytes.

const RATE_BYTES : Int = 136 // (1600 - 2*256) / 8

const ROUNDS : Int = 24

let round_constants : FixedArray[UInt64] = [
  0x0000000000000001UL, 0x0000000000008082UL, 0x800000000000808aUL,
  0x8000000080008000UL, 0x000000000000808bUL, 0x0000000080000001UL,
  0x8000000080008081UL, 0x8000000000008009UL, 0x000000000000008aUL,
  0x0000000000000088UL, 0x0000000080008009UL, 0x000000008000000aUL,
  0x000000008000808bUL, 0x800000000000008bUL, 0x8000000000008089UL,
  0x8000000000008003UL, 0x8000000000008002UL, 0x8000000000000080UL,
  0x000000000000800aUL, 0x800000008000000aUL, 0x8000000080008081UL,
  0x8000000000008080UL, 0x0000000080000001UL, 0x8000000080008008UL,
]

// rotation_offsets[x + 5*y]; matches FIPS 202 Table 2.
let rotation_offsets : FixedArray[Int] = [
   0,  1, 62, 28, 27,
  36, 44,  6, 55, 20,
   3, 10, 43, 25, 39,
  41, 45, 15, 21,  8,
  18,  2, 61, 56, 14,
]

fn rotl64(x : UInt64, n : Int) -> UInt64 {
  if n == 0 {
    x
  } else {
    (x << n) | (x >> (64 - n))
  }
}

fn idx(x : Int, y : Int) -> Int {
  x + 5 * y
}

fn keccak_f1600(state : FixedArray[UInt64]) -> Unit {
  let c : FixedArray[UInt64] = FixedArray::make(5, 0UL)
  let d : FixedArray[UInt64] = FixedArray::make(5, 0UL)
  let b : FixedArray[UInt64] = FixedArray::make(25, 0UL)
  for round = 0; round < ROUNDS; round = round + 1 {
    // Theta
    for x = 0; x < 5; x = x + 1 {
      c[x] = state[idx(x, 0)]
        .lxor(state[idx(x, 1)])
        .lxor(state[idx(x, 2)])
        .lxor(state[idx(x, 3)])
        .lxor(state[idx(x, 4)])
    }
    for x = 0; x < 5; x = x + 1 {
      d[x] = c[(x + 4) % 5].lxor(rotl64(c[(x + 1) % 5], 1))
    }
    for x = 0; x < 5; x = x + 1 {
      for y = 0; y < 5; y = y + 1 {
        state[idx(x, y)] = state[idx(x, y)].lxor(d[x])
      }
    }
    // Rho + Pi: B[y, 2x+3y] = rotl(A[x, y], r[x, y])
    for x = 0; x < 5; x = x + 1 {
      for y = 0; y < 5; y = y + 1 {
        b[idx(y, (2 * x + 3 * y) % 5)] = rotl64(
          state[idx(x, y)],
          rotation_offsets[idx(x, y)],
        )
      }
    }
    // Chi
    for x = 0; x < 5; x = x + 1 {
      for y = 0; y < 5; y = y + 1 {
        state[idx(x, y)] = b[idx(x, y)].lxor(
          b[idx((x + 1) % 5, y)].lnot().land(b[idx((x + 2) % 5, y)]),
        )
      }
    }
    // Iota
    state[0] = state[0].lxor(round_constants[round])
  }
}

fn load64_le(src : Bytes, offset : Int) -> UInt64 {
  let mut r : UInt64 = 0UL
  for i = 0; i < 8; i = i + 1 {
    r = r | (src[offset + i].to_uint64() << (i * 8))
  }
  r
}

fn store64_le(dst : Array[Byte], offset : Int, v : UInt64) -> Unit {
  for i = 0; i < 8; i = i + 1 {
    dst[offset + i] = (v >> (i * 8)).to_byte()
  }
}

///|
pub fn keccak256(input : Bytes) -> Bytes {
  let state : FixedArray[UInt64] = FixedArray::make(25, 0UL)
  let len = input.length()
  let mut offset = 0

  // Absorb full rate-sized blocks.
  while len - offset >= RATE_BYTES {
    for lane = 0; lane < RATE_BYTES / 8; lane = lane + 1 {
      state[lane] = state[lane].lxor(load64_le(input, offset + lane * 8))
    }
    keccak_f1600(state)
    offset = offset + RATE_BYTES
  }

  // Pad the final block. Pre-NIST Keccak uses 0x01 ... 0x80.
  let last = FixedArray::make(RATE_BYTES, b'\x00')
  let tail = len - offset
  for i = 0; i < tail; i = i + 1 {
    last[i] = input[offset + i]
  }
  last[tail] = b'\x01'
  last[RATE_BYTES - 1] = last[RATE_BYTES - 1].lor(b'\x80')

  // Absorb the padded final block by reading it lane-by-lane (LE).
  for lane = 0; lane < RATE_BYTES / 8; lane = lane + 1 {
    let mut w : UInt64 = 0UL
    for i = 0; i < 8; i = i + 1 {
      w = w | (last[lane * 8 + i].to_uint64() << (i * 8))
    }
    state[lane] = state[lane] ^ w
  }
  keccak_f1600(state)

  // Squeeze: first 32 bytes (= first 4 lanes) of the state.
  let out : Array[Byte] = Array::make(32, b'\x00')
  for lane = 0; lane < 4; lane = lane + 1 {
    store64_le(out, lane * 8, state[lane])
  }
  Bytes::from_array(out[:])
}
