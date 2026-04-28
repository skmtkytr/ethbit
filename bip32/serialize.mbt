// BIP-32 xprv/xpub serialization (Base58Check, 78-byte payload) and the
// public-side child derivation (CKDpub).
//
// Layout (78 bytes pre-Base58Check):
//   version(4) || depth(1) || parent_fp(4) || child_number(4)
//     || chain_code(32) || key_data(33)
//
// xprv key_data: 0x00 || private_key(32)
// xpub key_data: compressed_pubkey(33)
//
// Mainnet versions: xprv = 0x0488ADE4, xpub = 0x0488B21E
// Testnet versions: tprv = 0x04358394, tpub = 0x043587CF

///|
pub(all) enum Network {
  Mainnet
  Testnet
}

///|
pub(all) suberror SerializationError {
  WrongNetwork
  // xpub bytes parsed as xprv or vice versa.
  WrongKeyType
  // Post-base58 payload not 78 bytes.
  InvalidLength(Int)
  // Version bytes match no known network/key kind.
  InvalidVersion
  Base58Error(@base58.DecodeError)
  // Priv key not in [1, n-1] or pubkey decode failed.
  KeyOutOfRange
}

///|
pub impl Show for SerializationError with output(self, logger) {
  match self {
    WrongNetwork => logger.write_string("WrongNetwork")
    WrongKeyType => logger.write_string("WrongKeyType")
    InvalidLength(n) => {
      logger.write_string("InvalidLength(")
      logger.write_object(n)
      logger.write_char(')')
    }
    InvalidVersion => logger.write_string("InvalidVersion")
    Base58Error(e) => {
      logger.write_string("Base58Error(")
      logger.write_object(e)
      logger.write_char(')')
    }
    KeyOutOfRange => logger.write_string("KeyOutOfRange")
  }
}

///|
/// Public-side counterpart of `ExtendedPrivateKey`. We keep the affine
/// coordinates as 32-byte big-endian arrays so we can re-encode without
/// recomputing; the underlying `secp256k1.Point` can be reconstructed via
/// `@secp256k1.pubkey_from_bytes` on the compressed encoding.
pub(all) struct ExtendedPublicKey {
  pub_x : Bytes
  pub_y : Bytes
  chain_code : Bytes
  depth : Int
  parent_fingerprint : Bytes
  child_number : UInt
}

///|
/// Internal: which kind of extended key the version bytes encode.
priv enum KeyKind {
  Priv
  Pub
}

///|
/// 4-byte BIP-32 version prefix for (network, kind).
fn version_bytes(network : Network, kind : KeyKind) -> Bytes {
  match (network, kind) {
    (Mainnet, Priv) => b"\x04\x88\xad\xe4"
    (Mainnet, Pub) => b"\x04\x88\xb2\x1e"
    (Testnet, Priv) => b"\x04\x35\x83\x94"
    (Testnet, Pub) => b"\x04\x35\x87\xcf"
  }
}

///|
/// Identify (network, kind) from a 4-byte version prefix. Returns None if
/// the bytes don't match any known prefix.
fn classify_version(v : Bytes) -> (Network, KeyKind)? {
  if bytes_eq(v, b"\x04\x88\xad\xe4") {
    Some((Mainnet, Priv))
  } else if bytes_eq(v, b"\x04\x88\xb2\x1e") {
    Some((Mainnet, Pub))
  } else if bytes_eq(v, b"\x04\x35\x83\x94") {
    Some((Testnet, Priv))
  } else if bytes_eq(v, b"\x04\x35\x87\xcf") {
    Some((Testnet, Pub))
  } else {
    None
  }
}

///|
/// Byte-wise equality on two `Bytes` of any length.
fn bytes_eq(a : Bytes, b : Bytes) -> Bool {
  let la = a.length()
  if la != b.length() {
    return false
  }
  for i = 0; i < la; i = i + 1 {
    if a[i] != b[i] {
      return false
    }
  }
  true
}

///|
/// 4-byte big-endian encoding of a UInt (duplicated locally; the helper in
/// bip32.mbt is private to this package but still file-private).
fn uint_to_be_bytes_serialize(n : UInt) -> Bytes {
  let out : Array[Byte] = Array::make(4, b'\x00')
  out[0] = ((n >> 24) & 0xFFU).reinterpret_as_int().to_byte()
  out[1] = ((n >> 16) & 0xFFU).reinterpret_as_int().to_byte()
  out[2] = ((n >> 8) & 0xFFU).reinterpret_as_int().to_byte()
  out[3] = (n & 0xFFU).reinterpret_as_int().to_byte()
  Bytes::from_array(out[:])
}

///|
/// Compressed SEC1 pubkey (33 bytes) from raw 32-byte x and y. We pick the
/// 0x02/0x03 prefix from the parity of the last byte of `y`.
fn compressed_from_xy(pub_x : Bytes, pub_y : Bytes) -> Bytes {
  let y_last = pub_y[31]
  let prefix = if (y_last.to_int() & 1) == 1 {
    b"\x03"
  } else {
    b"\x02"
  }
  @bytesx.concat([prefix, pub_x])
}

///|
/// Build the 78-byte BIP-32 payload from its component fields.
fn build_payload(
  version : Bytes,
  depth : Int,
  parent_fingerprint : Bytes,
  child_number : UInt,
  chain_code : Bytes,
  key_data : Bytes,
) -> Bytes {
  let depth_byte = Bytes::from_array([depth.to_byte()][:])
  let cn = uint_to_be_bytes_serialize(child_number)
  @bytesx.concat([
    version,
    depth_byte,
    parent_fingerprint,
    cn,
    chain_code,
    key_data,
  ])
}

///|
/// Serialize `key` as an extended private key (xprv on mainnet, tprv on testnet).
pub fn serialize_xprv(key : ExtendedPrivateKey, network : Network) -> String {
  let key_data = @bytesx.concat([b"\x00", key.key.to_octets(length=32)])
  let payload = build_payload(
    version_bytes(network, Priv),
    key.depth,
    key.parent_fingerprint,
    key.child_number,
    key.chain_code,
    key_data,
  )
  @base58.encode_check(payload)
}

///|
/// Serialize `key` as an extended public key (xpub on mainnet, tpub on testnet).
/// Internally derives the compressed pubkey from `key.key`.
pub fn serialize_xpub(key : ExtendedPrivateKey, network : Network) -> String {
  let pub_pt = @secp256k1.pubkey_from_sk(key.key)
  let key_data = @secp256k1.pubkey_to_compressed(pub_pt)
  let payload = build_payload(
    version_bytes(network, Pub),
    key.depth,
    key.parent_fingerprint,
    key.child_number,
    key.chain_code,
    key_data,
  )
  @base58.encode_check(payload)
}

///|
/// Decode a Base58Check-encoded BIP-32 payload, validate its 78-byte length,
/// and return the (network, kind, payload) triple.
fn decode_extended(
  s : String,
) -> Result[(Network, KeyKind, Bytes), SerializationError] {
  let payload = match @base58.decode_check(s) {
    Ok(p) => p
    Err(e) => return Err(Base58Error(e))
  }
  let n = payload.length()
  if n != 78 {
    return Err(InvalidLength(n))
  }
  let version = @bytesx.slice(payload, 0, 4)
  match classify_version(version) {
    Some((net, kind)) => Ok((net, kind, payload))
    None => Err(InvalidVersion)
  }
}

///|
/// Parse an extended private key string. Returns:
///   - `WrongNetwork` if the version's network doesn't match `network`
///   - `WrongKeyType` if the version is for a public key
///   - `Base58Error(InvalidChecksum)` for tampered input
///   - `KeyOutOfRange` if the inner private key isn't in [1, n-1]
pub fn parse_xprv(
  s : String,
  network : Network,
) -> Result[ExtendedPrivateKey, SerializationError] {
  let (net, kind, payload) = match decode_extended(s) {
    Ok(t) => t
    Err(e) => return Err(e)
  }
  match kind {
    Pub => return Err(WrongKeyType)
    Priv => ()
  }
  if !network_eq(net, network) {
    return Err(WrongNetwork)
  }
  let depth = payload[4].to_int()
  let parent_fingerprint = @bytesx.slice(payload, 5, 9)
  let child_number = u32_be(@bytesx.slice(payload, 9, 13))
  let chain_code = @bytesx.slice(payload, 13, 45)
  let key_data = @bytesx.slice(payload, 45, 78)
  // xprv key_data must be 0x00 || priv32.
  if key_data[0] != b'\x00' {
    return Err(KeyOutOfRange)
  }
  let priv_key = @bigint.BigInt::from_octets(@bytesx.slice(key_data, 1, 33))
  if !@secp256k1.is_valid_scalar(priv_key) {
    return Err(KeyOutOfRange)
  }
  Ok({
    key: priv_key,
    chain_code,
    depth,
    parent_fingerprint,
    child_number,
  })
}

///|
/// Parse an extended public key string. Returns the same error categories
/// as `parse_xprv` (with `WrongKeyType` if the version is for a private key)
/// and `KeyOutOfRange` if the compressed pubkey fails to decode.
pub fn parse_xpub(
  s : String,
  network : Network,
) -> Result[ExtendedPublicKey, SerializationError] {
  let (net, kind, payload) = match decode_extended(s) {
    Ok(t) => t
    Err(e) => return Err(e)
  }
  match kind {
    Priv => return Err(WrongKeyType)
    Pub => ()
  }
  if !network_eq(net, network) {
    return Err(WrongNetwork)
  }
  let depth = payload[4].to_int()
  let parent_fingerprint = @bytesx.slice(payload, 5, 9)
  let child_number = u32_be(@bytesx.slice(payload, 9, 13))
  let chain_code = @bytesx.slice(payload, 13, 45)
  let key_data = @bytesx.slice(payload, 45, 78)
  // Decode the compressed pubkey to recover (x, y).
  let pt = match @secp256k1.pubkey_from_bytes(key_data) {
    Some(p) => p
    None => return Err(KeyOutOfRange)
  }
  let (x, y) = @secp256k1.to_affine(pt)
  Ok({
    pub_x: x.to_octets(length=32),
    pub_y: y.to_octets(length=32),
    chain_code,
    depth,
    parent_fingerprint,
    child_number,
  })
}

///|
/// Project the public side of an extended private key.
pub fn extended_to_public(key : ExtendedPrivateKey) -> ExtendedPublicKey {
  let pk_pt = @secp256k1.pubkey_from_sk(key.key)
  let (x, y) = @secp256k1.to_affine(pk_pt)
  {
    pub_x: x.to_octets(length=32),
    pub_y: y.to_octets(length=32),
    chain_code: key.chain_code,
    depth: key.depth,
    parent_fingerprint: key.parent_fingerprint,
    child_number: key.child_number,
  }
}

///|
/// Public-side child derivation (CKDpub, BIP-32 §3.2 normal child only).
/// Hardened indices (>= 0x80000000) are rejected with `InvalidPath`.
///
///   data = serP(parent_pub) || index_be       (33 + 4 = 37 bytes)
///   I = HMAC-SHA512(parent.chain_code, data)
///   IL = I[0..32], IR = I[32..64]
///   child_pub = parent_pub + IL*G   (reject if IL >= n or result is infinity)
///   child_chain_code = IR
pub fn derive_child_pub(
  parent : ExtendedPublicKey,
  index : UInt,
) -> Result[ExtendedPublicKey, DeriveError] {
  if index >= 0x80000000U {
    return Err(InvalidPath("hardened CKDpub not allowed"))
  }
  let parent_compressed = compressed_from_xy(parent.pub_x, parent.pub_y)
  let parent_pt = match @secp256k1.pubkey_from_bytes(parent_compressed) {
    Some(p) => p
    None => return Err(KeyNotInRange)
  }
  let index_be = uint_to_be_bytes_serialize(index)
  let data = @bytesx.concat([parent_compressed, index_be])
  let i = @sha512.hmac(parent.chain_code, data)
  let il = @bytesx.slice(i, 0, 32)
  let ir = @bytesx.slice(i, 32, 64)
  let il_int = @bigint.BigInt::from_octets(il)
  if il_int >= @secp256k1.n {
    return Err(KeyNotInRange)
  }
  let il_g = @secp256k1.mul_g(il_int)
  let child_pt = @secp256k1.point_add(parent_pt, il_g)
  if @secp256k1.is_infinity(child_pt) {
    return Err(KeyNotInRange)
  }
  let (cx, cy) = @secp256k1.to_affine(child_pt)
  // parent_fingerprint = ripemd160(sha256(serP(parent_pub)))[:4]
  let pub_sha = @sha256.sha256(parent_compressed)
  let pub_rip = @ripemd160.ripemd160(pub_sha)
  let fingerprint = @bytesx.slice(pub_rip, 0, 4)
  Ok({
    pub_x: cx.to_octets(length=32),
    pub_y: cy.to_octets(length=32),
    chain_code: ir,
    depth: parent.depth + 1,
    parent_fingerprint: fingerprint,
    child_number: index,
  })
}

///|
/// Equality on `Network` (it's a no-payload enum so we just match).
fn network_eq(a : Network, b : Network) -> Bool {
  match (a, b) {
    (Mainnet, Mainnet) => true
    (Testnet, Testnet) => true
    _ => false
  }
}

///|
/// 4-byte big-endian decode to UInt.
fn u32_be(b : Bytes) -> UInt {
  (b[0].to_uint() << 24) |
  (b[1].to_uint() << 16) |
  (b[2].to_uint() << 8) |
  b[3].to_uint()
}
