// HMAC-SHA-256 (RFC 2104).

const HMAC_BLOCK : Int = 64

///|
/// HMAC-SHA-256 with arbitrary-length key and message. Returns 32 bytes.
pub fn hmac(key : Bytes, message : Bytes) -> Bytes {
  // Normalize key to a 64-byte block (zero-padded; hash if longer).
  let k_norm = if key.length() > HMAC_BLOCK {
    sha256(key)
  } else {
    key
  }
  let k_pad : FixedArray[Byte] = FixedArray::make(HMAC_BLOCK, b'\x00')
  for i = 0; i < k_norm.length(); i = i + 1 {
    k_pad[i] = k_norm[i]
  }
  // Inner = SHA-256((K_pad XOR ipad) || message)
  let inner_buf : Array[Byte] = Array::make(HMAC_BLOCK + message.length(), b'\x00')
  for i = 0; i < HMAC_BLOCK; i = i + 1 {
    inner_buf[i] = (k_pad[i].to_int() ^ 0x36).to_byte()
  }
  for i = 0; i < message.length(); i = i + 1 {
    inner_buf[HMAC_BLOCK + i] = message[i]
  }
  let inner_hash = sha256(Bytes::from_array(inner_buf[:]))
  // Outer = SHA-256((K_pad XOR opad) || inner_hash)
  let outer_buf : Array[Byte] = Array::make(HMAC_BLOCK + 32, b'\x00')
  for i = 0; i < HMAC_BLOCK; i = i + 1 {
    outer_buf[i] = (k_pad[i].to_int() ^ 0x5c).to_byte()
  }
  for i = 0; i < 32; i = i + 1 {
    outer_buf[HMAC_BLOCK + i] = inner_hash[i]
  }
  sha256(Bytes::from_array(outer_buf[:]))
}
