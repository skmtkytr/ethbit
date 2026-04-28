// HMAC-SHA-512 (RFC 2104).

const HMAC_BLOCK : Int = 128

///|
/// HMAC-SHA-512 with arbitrary-length key and message. Returns 64 bytes.
pub fn hmac(key : Bytes, message : Bytes) -> Bytes {
  // Normalize key to a 128-byte block (zero-padded; hash if longer).
  let k_norm = if key.length() > HMAC_BLOCK {
    sha512(key)
  } else {
    key
  }
  let k_pad : FixedArray[Byte] = FixedArray::make(HMAC_BLOCK, b'\x00')
  for i = 0; i < k_norm.length(); i = i + 1 {
    k_pad[i] = k_norm[i]
  }
  // Inner = SHA-512((K_pad XOR ipad) || message)
  let inner_buf : Array[Byte] = Array::make(HMAC_BLOCK + message.length(), b'\x00')
  for i = 0; i < HMAC_BLOCK; i = i + 1 {
    inner_buf[i] = (k_pad[i].to_int() ^ 0x36).to_byte()
  }
  for i = 0; i < message.length(); i = i + 1 {
    inner_buf[HMAC_BLOCK + i] = message[i]
  }
  let inner_hash = sha512(Bytes::from_array(inner_buf[:]))
  // Outer = SHA-512((K_pad XOR opad) || inner_hash)
  let outer_buf : Array[Byte] = Array::make(HMAC_BLOCK + 64, b'\x00')
  for i = 0; i < HMAC_BLOCK; i = i + 1 {
    outer_buf[i] = (k_pad[i].to_int() ^ 0x5c).to_byte()
  }
  for i = 0; i < 64; i = i + 1 {
    outer_buf[HMAC_BLOCK + i] = inner_hash[i]
  }
  sha512(Bytes::from_array(outer_buf[:]))
}
