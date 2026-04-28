// BIP-39 seed derivation (mnemonic + passphrase -> 64-byte seed).
// Spec: https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki §5
//
// Scope: only the wordlist-independent seed-derivation step. We do NOT
// implement entropy<->mnemonic conversion here (no wordlist bundled).
//
// Per BIP-39 the password and salt must be NFKD-normalized. NFKD is the
// CALLER's responsibility for non-ASCII inputs; for ASCII strings (the
// standard English wordlist case) NFKD is the identity, so this package
// passes UTF-8 bytes through unchanged.

///|
/// BIP-39 seed derivation.
///
/// Returns the 64-byte BIP-39 seed for the given (already-normalized)
/// mnemonic and passphrase. The caller is responsible for NFKD
/// normalization on non-ASCII input; ASCII passes through unchanged.
///
/// Algorithm:
///   password = utf8_bytes(mnemonic)
///   salt     = utf8_bytes("mnemonic" || passphrase)
///   seed     = PBKDF2-HMAC-SHA512(password, salt, c=2048, dkLen=64)
pub fn mnemonic_to_seed(mnemonic : String, passphrase : String) -> Bytes {
  let password = utf8_encode(mnemonic)
  // Build salt = "mnemonic" || passphrase (UTF-8).
  let prefix : FixedArray[Byte] = [
    b'm', b'n', b'e', b'm', b'o', b'n', b'i', b'c',
  ]
  let pass_bytes = utf8_encode(passphrase)
  let salt_buf : Array[Byte] = Array::make(8 + pass_bytes.length(), b'\x00')
  for i = 0; i < 8; i = i + 1 {
    salt_buf[i] = prefix[i]
  }
  for i = 0; i < pass_bytes.length(); i = i + 1 {
    salt_buf[8 + i] = pass_bytes[i]
  }
  let salt = Bytes::from_array(salt_buf[:])
  pbkdf2_hmac_sha512(password, salt, 2048, 64)
}

///|
/// PBKDF2-HMAC-SHA-512 (RFC 8018 §5.2). Private to this package.
///
/// dk_len must be <= 64 (one HMAC-SHA-512 block; we only need 64 here).
fn pbkdf2_hmac_sha512(
  password : Bytes,
  salt : Bytes,
  iterations : Int,
  dk_len : Int,
) -> Bytes {
  // l = ceil(dk_len / 64). For BIP-39 (dk_len=64) l == 1, but support
  // any 1..=64 dk_len for robustness; multi-block (dk_len > 64) is out of
  // scope for this package and would abort.
  if dk_len <= 0 || dk_len > 64 {
    abort("pbkdf2_hmac_sha512: dk_len must be in 1..=64")
  }
  if iterations < 1 {
    abort("pbkdf2_hmac_sha512: iterations must be >= 1")
  }
  // Build salt || INT(1).
  let block_input : Array[Byte] = Array::make(salt.length() + 4, b'\x00')
  for i = 0; i < salt.length(); i = i + 1 {
    block_input[i] = salt[i]
  }
  block_input[salt.length()] = b'\x00'
  block_input[salt.length() + 1] = b'\x00'
  block_input[salt.length() + 2] = b'\x00'
  block_input[salt.length() + 3] = b'\x01'
  // U_1 = HMAC(P, salt || INT(1))
  let mut u = @sha512.hmac(password, Bytes::from_array(block_input[:]))
  // T = U_1
  let t : Array[Byte] = Array::make(64, b'\x00')
  for i = 0; i < 64; i = i + 1 {
    t[i] = u[i]
  }
  // U_j = HMAC(P, U_{j-1}); T ^= U_j   for j = 2..iterations
  for j = 2; j <= iterations; j = j + 1 {
    u = @sha512.hmac(password, u)
    for i = 0; i < 64; i = i + 1 {
      t[i] = (t[i].to_int() ^ u[i].to_int()).to_byte()
    }
  }
  // Truncate to dk_len.
  let out : Array[Byte] = Array::make(dk_len, b'\x00')
  for i = 0; i < dk_len; i = i + 1 {
    out[i] = t[i]
  }
  Bytes::from_array(out[:])
}

///|
/// Encode a MoonBit `String` (UTF-16 internally) to its UTF-8 bytes.
///
/// Handles the full BMP plus surrogate pairs. Used here only because
/// `bip39` deliberately avoids importing `moonbitlang/core/encoding/utf8`
/// to keep the dependency surface minimal.
fn utf8_encode(s : String) -> Bytes {
  let chars = s.iter().to_array()
  // Worst case: every char is 4 bytes.
  let buf : Array[Byte] = Array::make(chars.length() * 4, b'\x00')
  let mut n = 0
  for i = 0; i < chars.length(); i = i + 1 {
    let cp = chars[i].to_int()
    if cp < 0x80 {
      buf[n] = cp.to_byte()
      n = n + 1
    } else if cp < 0x800 {
      buf[n] = (0xc0 | (cp >> 6)).to_byte()
      buf[n + 1] = (0x80 | (cp & 0x3f)).to_byte()
      n = n + 2
    } else if cp < 0x10000 {
      buf[n] = (0xe0 | (cp >> 12)).to_byte()
      buf[n + 1] = (0x80 | ((cp >> 6) & 0x3f)).to_byte()
      buf[n + 2] = (0x80 | (cp & 0x3f)).to_byte()
      n = n + 3
    } else {
      buf[n] = (0xf0 | (cp >> 18)).to_byte()
      buf[n + 1] = (0x80 | ((cp >> 12) & 0x3f)).to_byte()
      buf[n + 2] = (0x80 | ((cp >> 6) & 0x3f)).to_byte()
      buf[n + 3] = (0x80 | (cp & 0x3f)).to_byte()
      n = n + 4
    }
  }
  let out : Array[Byte] = Array::make(n, b'\x00')
  for i = 0; i < n; i = i + 1 {
    out[i] = buf[i]
  }
  Bytes::from_array(out[:])
}
