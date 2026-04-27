// Test vectors are pre-NIST Keccak-256 (the variant Ethereum uses), NOT NIST SHA3-256.
// Differences: Keccak-256 padding is 0x01..0x80, SHA3-256 is 0x06..0x80.
//
// Multi-block / boundary / single-byte vectors below were generated with
// js-sha3 (npm) so we are not just verifying our impl against itself.
// Short text vectors are public Ethereum-published values cross-checked
// against eth-hash, noble-hashes, and go-ethereum.

fn h(s : String) -> Bytes {
  match @hex.decode(s) {
    Ok(b) => b
    Err(_) => abort("invalid hex literal in test")
  }
}

fn popcount_diff(a : Bytes, b : Bytes) -> Int {
  let mut diff = 0
  for i = 0; i < a.length(); i = i + 1 {
    diff = diff + (a[i] ^ b[i]).popcnt()
  }
  diff
}

// ---- Short Ethereum-published vectors ----

test "keccak256: empty input" {
  let want = h("0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470")
  assert_eq(@keccak.keccak256(b""), want)
}

test "keccak256: \"abc\"" {
  let want = h("0x4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45")
  assert_eq(@keccak.keccak256(b"abc"), want)
}

test "keccak256: \"hello\"" {
  let want = h("0x1c8aff950685c2ed4bc3174f3472287b56d9517b9c948127319a09a7a36deac8")
  assert_eq(@keccak.keccak256(b"hello"), want)
}

test "keccak256: \"The quick brown fox jumps over the lazy dog\"" {
  let want = h("0x4d741b6f1eb29cb2a9b9911c82f56fa8d73b04959d3d9d222895df6c0b28aa15")
  assert_eq(@keccak.keccak256(b"The quick brown fox jumps over the lazy dog"), want)
}

test "keccak256: ERC20 transfer selector" {
  // First 4 bytes of keccak256("transfer(address,uint256)") = 0xa9059cbb.
  let digest = @keccak.keccak256(b"transfer(address,uint256)")
  assert_eq(digest.length(), 32)
  assert_eq(digest[0], b'\xa9')
  assert_eq(digest[1], b'\x05')
  assert_eq(digest[2], b'\x9c')
  assert_eq(digest[3], b'\xbb')
}

// ---- Output length ----

test "keccak256: 32-byte output length always" {
  assert_eq(@keccak.keccak256(b"").length(), 32)
  assert_eq(@keccak.keccak256(b"a").length(), 32)
  assert_eq(
    @keccak.keccak256(b"the quick brown fox jumps over the lazy dog").length(),
    32,
  )
}

// ---- Single-byte inputs ----

test "keccak256: single byte 0x00" {
  let want = h("0xbc36789e7a1e281436464229828f817d6612f7b477d66591ff96a9e064bcc98a")
  assert_eq(@keccak.keccak256(b"\x00"), want)
}

test "keccak256: single byte 0xff" {
  let want = h("0x8b1a944cf13a9a1c08facb2c9e98623ef3254d2ddb48113885c3e8e97fec8db9")
  assert_eq(@keccak.keccak256(b"\xff"), want)
}

// ---- Padding-boundary length tests (rate = 136 bytes) ----
//
// These exercise the highest-risk paths in absorb/pad/squeeze:
// - len = rate-1 (135): 0x01 and 0x80 land in the SAME byte (last of block).
// - len = rate   (136): forces an extra pure-padding block.
// - len = 2*rate-1 (271): same-byte padding wrap on the 2nd boundary.
// - len = 2*rate   (272): two full blocks then a pure-padding block.
// - len = 2*rate+1 (273): trailing single byte after two full blocks.

test "keccak256: 135 zero bytes (rate-1, padding wraps to same byte)" {
  let want = h("0x29e3704feeca7fb9ba229f0fa04d9b36449cf3ad6e1d85d9cfff3a10df9abc3e")
  assert_eq(@keccak.keccak256(Bytes::make(135, b'\x00')), want)
}

test "keccak256: 136 zero bytes (= rate, forces pure-padding block)" {
  let want = h("0x3a5912a7c5faa06ee4fe906253e339467a9ce87d533c65be3c15cb231cdb25f9")
  assert_eq(@keccak.keccak256(Bytes::make(136, b'\x00')), want)
}

test "keccak256: 137 zero bytes (one full block + 1)" {
  let want = h("0xbee7fbb405cb0d91a8775e338c4a5e4b5d6b2d051f687fa942043cffdc73bd28")
  assert_eq(@keccak.keccak256(Bytes::make(137, b'\x00')), want)
}

test "keccak256: 271 zero bytes (2*rate-1, padding wrap)" {
  let want = h("0x3bb611e98ca876adc01436a582979ecfd012389033aca7dbf76dcb424fe02a0c")
  assert_eq(@keccak.keccak256(Bytes::make(271, b'\x00')), want)
}

test "keccak256: 272 zero bytes (= 2*rate)" {
  let want = h("0xa8005c7a3125b6c3629b4181eca54d18721e41fef639718d205beb00b366ed7d")
  assert_eq(@keccak.keccak256(Bytes::make(272, b'\x00')), want)
}

test "keccak256: 273 zero bytes (2*rate+1)" {
  let want = h("0x20494ff4ca5f71c4edb30f159611d235a403fdd6beb95a7c386176842c3fd109")
  assert_eq(@keccak.keccak256(Bytes::make(273, b'\x00')), want)
}

// ---- Diverse byte values ----

test "keccak256: 256 incrementing bytes 0..255" {
  let arr : Array[Byte] = Array::makei(256, fn(i) { i.to_byte() })
  let input = Bytes::from_array(arr[:])
  let want = h("0xdc924469b334aed2a19fac7252e9961aea41f8d91996366029dbe0884229bf36")
  assert_eq(@keccak.keccak256(input), want)
}

test "keccak256: 200 bytes of 'a'" {
  let want = h("0x96ea54061def936c4be90b518992fdc6f12f535068a256229aca54267b4d084d")
  assert_eq(@keccak.keccak256(Bytes::make(200, b'\x61')), want)
}

test "keccak256: 1000 bytes of 'a' (~7 blocks)" {
  let want = h("0xb6a4ac1f51884d71f30fa397a5e155de3099e11fc0edef5d08b646e621e19de9")
  assert_eq(@keccak.keccak256(Bytes::make(1000, b'\x61')), want)
}

// ---- Idempotence / determinism guard ----

test "keccak256: same input produces same digest twice" {
  let input = Bytes::make(200, b'\x42')
  let d1 = @keccak.keccak256(input)
  let d2 = @keccak.keccak256(input)
  assert_eq(d1, d2)
}

// ---- Avalanche smoke test ----

test "keccak256: 1-bit input change flips many output bits" {
  // Lenient threshold: random function would expect ~128 differing bits;
  // anything >96 confirms no obvious diffusion failure.
  let d0 = @keccak.keccak256(b"\x00")
  let d1 = @keccak.keccak256(b"\x01")
  let differing = popcount_diff(d0, d1)
  assert_true(differing > 96)
}
