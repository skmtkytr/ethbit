// BIP-32 hierarchical deterministic key derivation.
// Spec: https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki
//
// Scope: only private-key (CKDpriv) derivation along a path. We do NOT
// implement xprv/xpub serialization (which needs base58check and would
// drag in another encoding). The struct still tracks `depth`,
// `parent_fingerprint`, and `child_number` so a caller could serialize
// later by appending those fields plus a version byte and base58-checking.

///|
pub(all) struct ExtendedPrivateKey {
  key : @bigint.BigInt
  // 32 bytes of chain code.
  chain_code : Bytes
  depth : Int
  // 4 bytes. b"\x00\x00\x00\x00" for master.
  parent_fingerprint : Bytes
  // 0 for master; for hardened indices the high bit (0x80000000) is set.
  child_number : UInt
}

///|
pub(all) suberror DeriveError {
  // Seed length out of allowed range. BIP-32 §3 allows 16..64 bytes; we
  // accept that range and surface the actual length on rejection.
  InvalidSeedLength(Int)
  // Path string did not parse (bad token, bad char, overflow).
  InvalidPath(String)
  // Parsed index >= 2^32 (UInt range).
  IndexOutOfRange
  // Master IL or child (parent + IL) was 0 or >= n. BIP-32 says the caller
  // should retry with the next index; we surface so the caller can decide.
  KeyNotInRange
}

///|
pub impl Show for DeriveError with output(self, logger) {
  match self {
    InvalidSeedLength(n) => {
      logger.write_string("InvalidSeedLength(")
      logger.write_object(n)
      logger.write_char(')')
    }
    InvalidPath(s) => {
      logger.write_string("InvalidPath(\"")
      logger.write_string(s)
      logger.write_string("\")")
    }
    IndexOutOfRange => logger.write_string("IndexOutOfRange")
    KeyNotInRange => logger.write_string("KeyNotInRange")
  }
}

///|
/// BIP-32 §3.1: master key from seed.
///   I = HMAC-SHA512(key="Bitcoin seed", data=seed)
///   IL = I[0..32], IR = I[32..64]
///   Master priv = IL (must be in [1, n-1])
///   Master chain code = IR
pub fn master_from_seed(seed : Bytes) -> Result[ExtendedPrivateKey, DeriveError] {
  let len = seed.length()
  if len < 16 || len > 64 {
    return Err(InvalidSeedLength(len))
  }
  // HMAC key is the ASCII string "Bitcoin seed".
  let hmac_key = b"Bitcoin seed"
  let i = @sha512.hmac(hmac_key, seed)
  let il = @bytesx.slice(i, 0, 32)
  let ir = @bytesx.slice(i, 32, 64)
  let key = @bigint.BigInt::from_octets(il)
  if !@secp256k1.is_valid_scalar(key) {
    return Err(KeyNotInRange)
  }
  Ok({
    key,
    chain_code: ir,
    depth: 0,
    parent_fingerprint: b"\x00\x00\x00\x00",
    child_number: 0U,
  })
}

///|
/// CKDpriv (BIP-32 §3.2). Hardened iff index >= 0x80000000.
///   data = (hardened) 0x00 || parent_priv (32B) || index_be
///          (normal)   serP(parent_pub) || index_be
///   I = HMAC-SHA512(key=parent.chain_code, data=data)
///   child_priv = (parent_priv + IL) mod n   (must be in [1, n-1])
///   child_chain_code = IR
pub fn derive_child(
  parent : ExtendedPrivateKey,
  index : UInt,
) -> Result[ExtendedPrivateKey, DeriveError] {
  let hardened = index >= 0x80000000U
  let parent_priv_octets = parent.key.to_octets(length=32)
  let parent_pub = @secp256k1.pubkey_from_sk(parent.key)
  let parent_pub_compressed = @secp256k1.pubkey_to_compressed(parent_pub)
  let index_be = uint_to_be_bytes(index)
  let data = if hardened {
    @bytesx.concat([b"\x00", parent_priv_octets, index_be])
  } else {
    @bytesx.concat([parent_pub_compressed, index_be])
  }
  let i = @sha512.hmac(parent.chain_code, data)
  let il = @bytesx.slice(i, 0, 32)
  let ir = @bytesx.slice(i, 32, 64)
  let il_int = @bigint.BigInt::from_octets(il)
  // BIP-32 §3.2: if IL >= n, retry with next index. We surface as KeyNotInRange.
  if il_int >= @secp256k1.n {
    return Err(KeyNotInRange)
  }
  let child_key = @secp256k1.nadd(parent.key, il_int)
  if !@secp256k1.is_valid_scalar(child_key) {
    return Err(KeyNotInRange)
  }
  // Parent fingerprint = first 4 bytes of RIPEMD160(SHA256(serP(parent_pub))).
  let pub_sha = @sha256.sha256(parent_pub_compressed)
  let pub_rip = @ripemd160.ripemd160(pub_sha)
  let fingerprint = @bytesx.slice(pub_rip, 0, 4)
  Ok({
    key: child_key,
    chain_code: ir,
    depth: parent.depth + 1,
    parent_fingerprint: fingerprint,
    child_number: index,
  })
}

///|
/// 4-byte big-endian encoding of a UInt.
fn uint_to_be_bytes(n : UInt) -> Bytes {
  let out : Array[Byte] = Array::make(4, b'\x00')
  out[0] = ((n >> 24) & 0xFFU).reinterpret_as_int().to_byte()
  out[1] = ((n >> 16) & 0xFFU).reinterpret_as_int().to_byte()
  out[2] = ((n >> 8) & 0xFFU).reinterpret_as_int().to_byte()
  out[3] = (n & 0xFFU).reinterpret_as_int().to_byte()
  Bytes::from_array(out[:])
}

///|
/// Parse "m/44'/60'/0'/0/0" into a list of UInt indices.
/// "m" (or empty) yields []. ' (apostrophe) or h after a number marks
/// hardened (sets bit 0x80000000). Numbers must be in [0, 2^31).
///
/// Errors:
///   - InvalidPath if the first segment isn't "m" (or the path is empty)
///   - InvalidPath on empty segments, non-digit chars, leading +/-, etc.
///   - IndexOutOfRange if a parsed number is >= 2^31
pub fn parse_path(path : String) -> Result[Array[UInt], DeriveError] {
  let chars = path.iter().to_array()
  let total = chars.length()
  if total == 0 {
    return Err(InvalidPath(path))
  }
  if chars[0] != 'm' {
    return Err(InvalidPath(path))
  }
  let result : Array[UInt] = Array::new()
  // After "m", the rest must be either empty or start with '/'.
  if total == 1 {
    return Ok(result)
  }
  if chars[1] != '/' {
    return Err(InvalidPath(path))
  }
  // "m/" with no following segment is malformed.
  if total == 2 {
    return Err(InvalidPath(path))
  }
  let mut i = 2
  while i < total {
    // Parse one segment: digits ... optional ' or h marker, terminated by
    // '/' or end-of-string.
    let seg_start = i
    while i < total && chars[i] != '/' {
      i = i + 1
    }
    let seg_end = i
    if seg_end == seg_start {
      // Empty segment (e.g. trailing slash, or "//"): reject.
      return Err(InvalidPath(path))
    }
    // Check for hardened marker in last position.
    let last = chars[seg_end - 1]
    let hardened = last == '\'' || last == 'h'
    let digits_end = if hardened { seg_end - 1 } else { seg_end }
    if digits_end == seg_start {
      // Only the hardened marker, no digits.
      return Err(InvalidPath(path))
    }
    // Validate that all digit chars are 0..9 and accumulate as UInt with
    // overflow check against 2^31 (since we OR the high bit for hardened
    // and don't want to collide with a user-specified 0x8....).
    let mut acc : UInt64 = 0UL
    for j = seg_start; j < digits_end; j = j + 1 {
      let c = chars[j]
      if c < '0' || c > '9' {
        return Err(InvalidPath(path))
      }
      acc = acc * 10UL + (c.to_int() - '0'.to_int()).to_uint64()
      if acc >= 2147483648UL { // 2^31
        return Err(IndexOutOfRange)
      }
    }
    let value = acc.to_uint()
    let final_value = if hardened { value | 0x80000000U } else { value }
    result.push(final_value)
    if i < total && chars[i] == '/' {
      i = i + 1
      // Don't allow trailing slash.
      if i == total {
        return Err(InvalidPath(path))
      }
    }
  }
  Ok(result)
}

///|
/// Convenience: derive_path(seed, "m/44'/60'/0'/0/0") returns the
/// extended private key at the leaf.
pub fn derive_path(
  seed : Bytes,
  path : String,
) -> Result[ExtendedPrivateKey, DeriveError] {
  let indices = match parse_path(path) {
    Ok(xs) => xs
    Err(e) => return Err(e)
  }
  let mut node = match master_from_seed(seed) {
    Ok(m) => m
    Err(e) => return Err(e)
  }
  for idx in indices {
    node = match derive_child(node, idx) {
      Ok(c) => c
      Err(e) => return Err(e)
    }
  }
  Ok(node)
}
