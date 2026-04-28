// BIP-32 serialization and CKDpub tests. Test vectors come from
// https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki#test-vectors

fn hex_decode(s : String) -> Bytes {
  match @hex.decode(s) {
    Ok(b) => b
    Err(_) => abort("invalid hex literal in test")
  }
}

fn unwrap_xprv_ser(
  r : Result[@bip32.ExtendedPrivateKey, @bip32.DeriveError],
) -> @bip32.ExtendedPrivateKey {
  match r {
    Ok(x) => x
    Err(_) => abort("expected Ok in test (DeriveError)")
  }
}

fn unwrap_parsed_xprv(
  r : Result[@bip32.ExtendedPrivateKey, @bip32.SerializationError],
) -> @bip32.ExtendedPrivateKey {
  match r {
    Ok(x) => x
    Err(_) => abort("expected Ok parsing xprv")
  }
}

fn unwrap_parsed_xpub(
  r : Result[@bip32.ExtendedPublicKey, @bip32.SerializationError],
) -> @bip32.ExtendedPublicKey {
  match r {
    Ok(x) => x
    Err(_) => abort("expected Ok parsing xpub")
  }
}

fn unwrap_xpub_derived(
  r : Result[@bip32.ExtendedPublicKey, @bip32.DeriveError],
) -> @bip32.ExtendedPublicKey {
  match r {
    Ok(x) => x
    Err(_) => abort("expected Ok deriving xpub")
  }
}

// Test Vector 1 master xprv/xpub.
let tv1_seed_hex : String = "000102030405060708090a0b0c0d0e0f"

let tv1_master_xprv : String =
  "xprv9s21ZrQH143K3QTDL4LXw2F7HEK3wJUD2nW2nRk4stbPy6cq3jPPqjiChkVvvNKmPGJxWUtg6LnF5kejMRNNU3TGtRBeJgk33yuGBxrMPHi"

let tv1_master_xpub : String =
  "xpub661MyMwAqRbcFtXgS5sYJABqqG9YLmC4Q1Rdap9gSE8NqtwybGhePY2gZ29ESFjqJoCu1Rupje8YtGqsefD265TMg7usUDFdp6W1EGMcet8"

let tv1_m0h_xprv : String =
  "xprv9uHRZZhk6KAJC1avXpDAp4MDc3sQKNxDiPvvkX8Br5ngLNv1TxvUxt4cV1rGL5hj6KCesnDYUhd7oWgT11eZG7XnxHrnYeSvkzY7d2bhkJ7"

let tv1_m0h1_xpub : String =
  "xpub6ASuArnXKPbfEwhqN6e3mwBcDTgzisQN1wXN9BJcM47sSikHjJf3UFHKkNAWbWMiGj7Wf5uMash7SyYq527Hqck2AxYysAA7xmALppuCkwQ"

// ---- serialize_xprv / serialize_xpub on master ----

test "serialize_xprv: master matches BIP-32 Test Vector 1 mainnet" {
  let seed = hex_decode(tv1_seed_hex)
  let m = unwrap_xprv_ser(@bip32.master_from_seed(seed))
  let s = @bip32.serialize_xprv(m, Mainnet)
  assert_eq(s, tv1_master_xprv)
}

test "serialize_xpub: master matches BIP-32 Test Vector 1 mainnet" {
  let seed = hex_decode(tv1_seed_hex)
  let m = unwrap_xprv_ser(@bip32.master_from_seed(seed))
  let s = @bip32.serialize_xpub(m, Mainnet)
  assert_eq(s, tv1_master_xpub)
}

test "serialize_xprv: m/0' matches BIP-32 Test Vector 1 mainnet" {
  let seed = hex_decode(tv1_seed_hex)
  let x = unwrap_xprv_ser(@bip32.derive_path(seed, "m/0'"))
  let s = @bip32.serialize_xprv(x, Mainnet)
  assert_eq(s, tv1_m0h_xprv)
}

test "serialize_xpub: m/0'/1 matches BIP-32 Test Vector 1 mainnet" {
  let seed = hex_decode(tv1_seed_hex)
  let x = unwrap_xprv_ser(@bip32.derive_path(seed, "m/0'/1"))
  let s = @bip32.serialize_xpub(x, Mainnet)
  assert_eq(s, tv1_m0h1_xpub)
}

// ---- parse_xprv / parse_xpub ----

test "parse_xprv: master xprv reconstructs master_from_seed result" {
  let seed = hex_decode(tv1_seed_hex)
  let m = unwrap_xprv_ser(@bip32.master_from_seed(seed))
  let parsed = unwrap_parsed_xprv(@bip32.parse_xprv(tv1_master_xprv, Mainnet))
  assert_eq(
    parsed.key.to_octets(length=32),
    m.key.to_octets(length=32),
  )
  assert_eq(parsed.chain_code, m.chain_code)
  assert_eq(parsed.depth, m.depth)
  assert_eq(parsed.parent_fingerprint, m.parent_fingerprint)
  assert_eq(parsed.child_number, m.child_number)
}

test "parse_xpub: master xpub yields the right pub_x, pub_y, chain_code" {
  let seed = hex_decode(tv1_seed_hex)
  let m = unwrap_xprv_ser(@bip32.master_from_seed(seed))
  let projected = @bip32.extended_to_public(m)
  let parsed = unwrap_parsed_xpub(@bip32.parse_xpub(tv1_master_xpub, Mainnet))
  assert_eq(parsed.pub_x, projected.pub_x)
  assert_eq(parsed.pub_y, projected.pub_y)
  assert_eq(parsed.chain_code, m.chain_code)
  assert_eq(parsed.depth, 0)
  assert_eq(parsed.parent_fingerprint, b"\x00\x00\x00\x00")
  assert_eq(parsed.child_number, 0U)
}

test "parse_xprv: master xprv with Testnet network -> WrongNetwork" {
  match @bip32.parse_xprv(tv1_master_xprv, Testnet) {
    Err(WrongNetwork) => ()
    _ => abort("expected WrongNetwork")
  }
}

test "parse_xprv: master xpub string -> WrongKeyType" {
  match @bip32.parse_xprv(tv1_master_xpub, Mainnet) {
    Err(WrongKeyType) => ()
    _ => abort("expected WrongKeyType")
  }
}

test "parse_xprv: tampered last char -> Base58Error(InvalidChecksum)" {
  // Replace the last character of the xprv with a different valid base58
  // character; this changes the trailing checksum byte mapping and must
  // surface as InvalidChecksum.
  let chars = tv1_master_xprv.iter().to_array()
  let n = chars.length()
  let last = chars[n - 1]
  // Pick a different base58 character that's definitely in the alphabet.
  let replacement = if last == '1' { '2' } else { '1' }
  let new_chars : Array[Char] = Array::make(n, '1')
  for i = 0; i < n - 1; i = i + 1 {
    new_chars[i] = chars[i]
  }
  new_chars[n - 1] = replacement
  let tampered = String::from_array(new_chars[:])
  match @bip32.parse_xprv(tampered, Mainnet) {
    Err(Base58Error(InvalidChecksum)) => ()
    _ => abort("expected Base58Error(InvalidChecksum)")
  }
}

// ---- extended_to_public ----

test "extended_to_public: master priv pub_x, pub_y match parsed master xpub" {
  let seed = hex_decode(tv1_seed_hex)
  let m = unwrap_xprv_ser(@bip32.master_from_seed(seed))
  let projected = @bip32.extended_to_public(m)
  let parsed = unwrap_parsed_xpub(@bip32.parse_xpub(tv1_master_xpub, Mainnet))
  assert_eq(projected.pub_x, parsed.pub_x)
  assert_eq(projected.pub_y, parsed.pub_y)
  assert_eq(projected.chain_code, parsed.chain_code)
}

// ---- derive_child_pub ----

test "derive_child_pub: m/0 matches derive_path then project" {
  let seed = hex_decode(tv1_seed_hex)
  let m = unwrap_xprv_ser(@bip32.master_from_seed(seed))
  let m_pub = @bip32.extended_to_public(m)
  // CKDpub of m at index 0 (non-hardened) must equal projecting m/0 priv.
  let child_pub = unwrap_xpub_derived(@bip32.derive_child_pub(m_pub, 0U))
  let m0_priv = unwrap_xprv_ser(@bip32.derive_path(seed, "m/0"))
  let m0_proj = @bip32.extended_to_public(m0_priv)
  assert_eq(child_pub.pub_x, m0_proj.pub_x)
  assert_eq(child_pub.pub_y, m0_proj.pub_y)
  assert_eq(child_pub.chain_code, m0_proj.chain_code)
  assert_eq(child_pub.depth, m0_proj.depth)
  assert_eq(child_pub.parent_fingerprint, m0_proj.parent_fingerprint)
  assert_eq(child_pub.child_number, m0_proj.child_number)
}

test "derive_child_pub: hardened index rejected" {
  let seed = hex_decode(tv1_seed_hex)
  let m = unwrap_xprv_ser(@bip32.master_from_seed(seed))
  let m_pub = @bip32.extended_to_public(m)
  match @bip32.derive_child_pub(m_pub, 0x80000000U) {
    Err(InvalidPath(_)) => ()
    _ => abort("expected InvalidPath for hardened CKDpub")
  }
}

// ---- round-trip ----

test "round-trip: serialize_xprv then parse_xprv returns equivalent struct" {
  let seed = hex_decode(tv1_seed_hex)
  let m = unwrap_xprv_ser(@bip32.master_from_seed(seed))
  let s = @bip32.serialize_xprv(m, Mainnet)
  let parsed = unwrap_parsed_xprv(@bip32.parse_xprv(s, Mainnet))
  assert_eq(
    parsed.key.to_octets(length=32),
    m.key.to_octets(length=32),
  )
  assert_eq(parsed.chain_code, m.chain_code)
  assert_eq(parsed.depth, m.depth)
  assert_eq(parsed.parent_fingerprint, m.parent_fingerprint)
  assert_eq(parsed.child_number, m.child_number)
}

test "round-trip: serialize_xpub then parse_xpub returns equivalent struct" {
  let seed = hex_decode(tv1_seed_hex)
  let m = unwrap_xprv_ser(@bip32.master_from_seed(seed))
  let s = @bip32.serialize_xpub(m, Mainnet)
  let parsed = unwrap_parsed_xpub(@bip32.parse_xpub(s, Mainnet))
  let projected = @bip32.extended_to_public(m)
  assert_eq(parsed.pub_x, projected.pub_x)
  assert_eq(parsed.pub_y, projected.pub_y)
  assert_eq(parsed.chain_code, projected.chain_code)
  assert_eq(parsed.depth, projected.depth)
  assert_eq(parsed.parent_fingerprint, projected.parent_fingerprint)
  assert_eq(parsed.child_number, projected.child_number)
}

// Round-trip a derived (non-master) extended key to exercise depth/parent_fp/cn.
test "round-trip: serialize/parse on m/0'/1 (depth=2, normal child)" {
  let seed = hex_decode(tv1_seed_hex)
  let x = unwrap_xprv_ser(@bip32.derive_path(seed, "m/0'/1"))
  let s_priv = @bip32.serialize_xprv(x, Mainnet)
  let parsed_priv = unwrap_parsed_xprv(@bip32.parse_xprv(s_priv, Mainnet))
  assert_eq(
    parsed_priv.key.to_octets(length=32),
    x.key.to_octets(length=32),
  )
  assert_eq(parsed_priv.depth, 2)
  assert_eq(parsed_priv.child_number, 1U)
  let s_pub = @bip32.serialize_xpub(x, Mainnet)
  let parsed_pub = unwrap_parsed_xpub(@bip32.parse_xpub(s_pub, Mainnet))
  assert_eq(parsed_pub.depth, 2)
  assert_eq(parsed_pub.child_number, 1U)
  assert_eq(parsed_pub.parent_fingerprint, parsed_priv.parent_fingerprint)
}

// Sanity: m/0'/1's parent_fingerprint must equal 0x5c1bd648 (BIP-32 vector 1).
test "round-trip: m/0'/1 parent_fingerprint = 0x5c1bd648" {
  let seed = hex_decode(tv1_seed_hex)
  let x = unwrap_xprv_ser(@bip32.derive_path(seed, "m/0'/1"))
  assert_eq(x.parent_fingerprint, hex_decode("5c1bd648"))
}
