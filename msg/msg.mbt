// Ethereum message signing: EIP-191 v0x45 ("personal_sign") and EIP-712
// (typed-data, version 4).
//
// Spec references:
//   - EIP-191: https://eips.ethereum.org/EIPS/eip-191
//     Format: 0x19 || 0x45 ("E"... actually the literal byte run)
//             personal_sign uses 0x19 || "Ethereum Signed Message:\n" ||
//             ASCII-decimal length(message) || message
//   - EIP-712: https://eips.ethereum.org/EIPS/eip-712
//     digest = keccak256(0x19 0x01 || domain_separator || struct_hash)
//
// Output convention (matches viem / ethers.js for ECDSA recovery):
//   r, s : 32-byte big-endian, zero-padded (NOT RLP-stripped)
//   v    : single byte 0x1B (yParity=0) or 0x1C (yParity=1); never empty
//
// The recid bit 1 (R.x >= n) case has probability ~2^-128 and is silently
// ignored here (only the yParity low bit is folded into v). Matches the
// behavior of `tx/sign.mbt` in this repo.

///|
pub(all) struct SignedMessage {
  r : Bytes
  s : Bytes
  v : Bytes
}

///|
/// Encode a non-negative `Int` as ASCII-decimal Bytes.
/// 0 → b"0", 13 → b"13", 100 → b"100".
/// Aborts on negative input (callers in this module pass `Bytes::length()`
/// which is always >= 0).
pub fn int_to_ascii_decimal(n : Int) -> Bytes {
  if n < 0 {
    abort("int_to_ascii_decimal: negative input")
  }
  if n == 0 {
    return b"0"
  }
  // Count digits.
  let mut digits = 0
  let mut tmp = n
  while tmp > 0 {
    digits = digits + 1
    tmp = tmp / 10
  }
  let out : Array[Byte] = Array::make(digits, b'0')
  let mut x = n
  for i = digits - 1; i >= 0; i = i - 1 {
    let d = x % 10
    out[i] = (d + 0x30).to_byte()
    x = x / 10
  }
  Bytes::from_array(out[:])
}

///|
/// EIP-191 personal_sign hash.
/// preimage = 0x19 || "Ethereum Signed Message:\n" || ASCII-decimal(len) || message
/// Returns keccak256(preimage), 32 bytes.
pub fn personal_message_hash(message : Bytes) -> Bytes {
  let prefix_static = b"\x19Ethereum Signed Message:\n"
  let len_ascii = int_to_ascii_decimal(message.length())
  let preimage = @bytesx.concat([prefix_static, len_ascii, message])
  @keccak.keccak256(preimage)
}

///|
/// Sign a personal_sign-formatted message.
/// `sk` must satisfy 1 <= sk < n.
pub fn personal_sign(sk : @bigint.BigInt, message : Bytes) -> SignedMessage {
  let h = personal_message_hash(message)
  ecdsa_to_signed_message(@secp256k1.sign(sk, h))
}

///|
/// EIP-712 v4 digest:
///   digest = keccak256(0x19 || 0x01 || domain_separator || struct_hash)
/// Both inputs must be 32 bytes (caller computes them).
pub fn typed_data_digest(
  domain_separator : Bytes,
  struct_hash : Bytes,
) -> Bytes {
  if domain_separator.length() != 32 {
    abort("typed_data_digest: domain_separator must be 32 bytes")
  }
  if struct_hash.length() != 32 {
    abort("typed_data_digest: struct_hash must be 32 bytes")
  }
  let preimage = @bytesx.concat([
    b"\x19\x01", domain_separator, struct_hash,
  ])
  @keccak.keccak256(preimage)
}

///|
/// Sign an EIP-712 typed-data digest.
/// `sk` must satisfy 1 <= sk < n.
pub fn sign_typed_data(
  sk : @bigint.BigInt,
  domain_separator : Bytes,
  struct_hash : Bytes,
) -> SignedMessage {
  let digest = typed_data_digest(domain_separator, struct_hash)
  ecdsa_to_signed_message(@secp256k1.sign(sk, digest))
}

///|
/// Convert an `EcdsaSig` to a `SignedMessage` with personal_sign / EIP-712
/// conventions: r and s zero-padded to 32 bytes, v ∈ {0x1B, 0x1C}.
fn ecdsa_to_signed_message(sig : @secp256k1.EcdsaSig) -> SignedMessage {
  let parity = sig.recid & 1
  let v_byte = if parity == 0 {
    b"\x1b"
  } else {
    b"\x1c"
  }
  {
    r: sig.r.to_octets(length=32),
    s: sig.s.to_octets(length=32),
    v: v_byte,
  }
}
