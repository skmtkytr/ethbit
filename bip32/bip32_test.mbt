// BIP-32 test vectors come from the spec:
// https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki#test-vectors

fn h(s : String) -> Bytes {
  match @hex.decode(s) {
    Ok(b) => b
    Err(_) => abort("invalid hex literal in test")
  }
}

fn unwrap_xprv(
  r : Result[@bip32.ExtendedPrivateKey, @bip32.DeriveError],
) -> @bip32.ExtendedPrivateKey {
  match r {
    Ok(x) => x
    Err(_) => abort("expected Ok in test")
  }
}

fn unwrap_path(
  r : Result[Array[UInt], @bip32.DeriveError],
) -> Array[UInt] {
  match r {
    Ok(x) => x
    Err(_) => abort("expected Ok in test")
  }
}

// ---- master_from_seed ----

test "master_from_seed: BIP-32 Test Vector 1" {
  let seed = h("000102030405060708090a0b0c0d0e0f")
  let m = unwrap_xprv(@bip32.master_from_seed(seed))
  assert_eq(
    m.key.to_octets(length=32),
    h("e8f32e723decf4051aefac8e2c93c9c5b214313817cdb01a1494b917c8436b35"),
  )
  assert_eq(
    m.chain_code,
    h("873dff81c02f525623fd1fe5167eac3a55a049de3d314bb42ee227ffed37d508"),
  )
  assert_eq(m.depth, 0)
  assert_eq(m.parent_fingerprint, b"\x00\x00\x00\x00")
  assert_eq(m.child_number, 0U)
}

test "master_from_seed: rejects too-short seed" {
  let seed = h("00010203")
  let r = @bip32.master_from_seed(seed)
  match r {
    Err(InvalidSeedLength(4)) => ()
    _ => abort("expected InvalidSeedLength(4)")
  }
}

test "master_from_seed: rejects too-long seed" {
  // 65 bytes
  let mut s = ""
  for i = 0; i < 65; i = i + 1 {
    let _ = i
    s = s + "00"
  }
  let seed = h(s)
  let r = @bip32.master_from_seed(seed)
  match r {
    Err(InvalidSeedLength(65)) => ()
    _ => abort("expected InvalidSeedLength(65)")
  }
}

// ---- derive_child ----

test "derive_child: m/0' (hardened) matches BIP-32 Test Vector 1" {
  let seed = h("000102030405060708090a0b0c0d0e0f")
  let m = unwrap_xprv(@bip32.master_from_seed(seed))
  let c = unwrap_xprv(@bip32.derive_child(m, 0x80000000U))
  assert_eq(
    c.key.to_octets(length=32),
    h("edb2e14f9ee77d26dd93b4ecede8d16ed408ce149b6cd80b0715a2d911a0afea"),
  )
  assert_eq(
    c.chain_code,
    h("47fdacbd0f1097043b78c63c20c34ef4ed9a111d980047ad16282c7ae6236141"),
  )
  assert_eq(c.depth, 1)
  assert_eq(c.child_number, 0x80000000U)
  // parent_fingerprint = ripemd160(sha256(serP(master_pub)))[:4].
  // Per BIP-32 vector 1 m: fingerprint = 0x3442193e.
  assert_eq(c.parent_fingerprint, h("3442193e"))
}

test "derive_child: m/0'/1 (normal) matches BIP-32 Test Vector 1" {
  let seed = h("000102030405060708090a0b0c0d0e0f")
  let m = unwrap_xprv(@bip32.master_from_seed(seed))
  let c1 = unwrap_xprv(@bip32.derive_child(m, 0x80000000U))
  let c2 = unwrap_xprv(@bip32.derive_child(c1, 1U))
  assert_eq(
    c2.key.to_octets(length=32),
    h("3c6cb8d0f6a264c91ea8b5030fadaa8e538b020f0a387421a12de9319dc93368"),
  )
  assert_eq(
    c2.chain_code,
    h("2a7857631386ba23dacac34180dd1983734e444fdbf774041578e9b6adb37c19"),
  )
  assert_eq(c2.depth, 2)
  assert_eq(c2.child_number, 1U)
}

// ---- derive_path (chained) ----

test "derive_path: m/0'/1/2' matches BIP-32 Test Vector 1" {
  let seed = h("000102030405060708090a0b0c0d0e0f")
  let x = unwrap_xprv(@bip32.derive_path(seed, "m/0'/1/2'"))
  assert_eq(
    x.key.to_octets(length=32),
    h("cbce0d719ecf7431d88e6a89fa1483e02e35092af60c042b1df2ff59fa424dca"),
  )
  assert_eq(
    x.chain_code,
    h("04466b9cc8e161e966409ca52986c584f07e9dc81f735db683c3ff6ec7b1503f"),
  )
  assert_eq(x.depth, 3)
  assert_eq(x.child_number, 0x80000002U)
}

test "derive_path: 'm' yields master" {
  let seed = h("000102030405060708090a0b0c0d0e0f")
  let m = unwrap_xprv(@bip32.derive_path(seed, "m"))
  assert_eq(
    m.key.to_octets(length=32),
    h("e8f32e723decf4051aefac8e2c93c9c5b214313817cdb01a1494b917c8436b35"),
  )
  assert_eq(m.depth, 0)
}

test "derive_path: 'h' marker is equivalent to apostrophe" {
  let seed = h("000102030405060708090a0b0c0d0e0f")
  let a = unwrap_xprv(@bip32.derive_path(seed, "m/0'"))
  let b = unwrap_xprv(@bip32.derive_path(seed, "m/0h"))
  assert_eq(
    a.key.to_octets(length=32),
    b.key.to_octets(length=32),
  )
  assert_eq(a.chain_code, b.chain_code)
}

test "derive_path: determinism — same path twice gives same key" {
  let seed = h("000102030405060708090a0b0c0d0e0f")
  let a = unwrap_xprv(@bip32.derive_path(seed, "m/44'/60'/0'/0/0"))
  let b = unwrap_xprv(@bip32.derive_path(seed, "m/44'/60'/0'/0/0"))
  assert_eq(
    a.key.to_octets(length=32),
    b.key.to_octets(length=32),
  )
  assert_eq(a.chain_code, b.chain_code)
  assert_eq(a.depth, b.depth)
  assert_eq(a.parent_fingerprint, b.parent_fingerprint)
  assert_eq(a.child_number, b.child_number)
}

// ---- parse_path ----

test "parse_path: 'm' -> []" {
  let p = unwrap_path(@bip32.parse_path("m"))
  assert_eq(p.length(), 0)
}

test "parse_path: 'm/44'/60'/0'/0/0' (Ethereum)" {
  let p = unwrap_path(@bip32.parse_path("m/44'/60'/0'/0/0"))
  assert_eq(p.length(), 5)
  assert_eq(p[0], 0x8000002CU) // 44 hardened
  assert_eq(p[1], 0x8000003CU) // 60 hardened
  assert_eq(p[2], 0x80000000U) // 0 hardened
  assert_eq(p[3], 0U)
  assert_eq(p[4], 0U)
}

test "parse_path: 'h' marker accepted" {
  let p = unwrap_path(@bip32.parse_path("m/44h/60h/0h/0/0"))
  assert_eq(p[0], 0x8000002CU)
  assert_eq(p[1], 0x8000003CU)
  assert_eq(p[2], 0x80000000U)
}

test "parse_path: rejects missing 'm' prefix" {
  match @bip32.parse_path("44'/60'") {
    Err(InvalidPath(_)) => ()
    _ => abort("expected InvalidPath")
  }
}

test "parse_path: rejects empty string" {
  match @bip32.parse_path("") {
    Err(InvalidPath(_)) => ()
    _ => abort("expected InvalidPath")
  }
}

test "parse_path: rejects trailing slash" {
  match @bip32.parse_path("m/0'/") {
    Err(InvalidPath(_)) => ()
    _ => abort("expected InvalidPath")
  }
}

test "parse_path: rejects empty segment ('m//0')" {
  match @bip32.parse_path("m//0") {
    Err(InvalidPath(_)) => ()
    _ => abort("expected InvalidPath")
  }
}

test "parse_path: rejects non-digit token" {
  match @bip32.parse_path("m/abc/0") {
    Err(InvalidPath(_)) => ()
    _ => abort("expected InvalidPath")
  }
}

test "parse_path: rejects standalone hardened marker (m/'/0)" {
  match @bip32.parse_path("m/'/0") {
    Err(InvalidPath(_)) => ()
    _ => abort("expected InvalidPath")
  }
}

test "parse_path: rejects index >= 2^31" {
  match @bip32.parse_path("m/2147483648") {
    Err(IndexOutOfRange) => ()
    _ => abort("expected IndexOutOfRange")
  }
}

test "parse_path: 'm/' rejected (treated as trailing slash)" {
  match @bip32.parse_path("m/") {
    Err(InvalidPath(_)) => ()
    _ => abort("expected InvalidPath")
  }
}

test "parse_path: largest allowed index 2^31 - 1 hardened" {
  let p = unwrap_path(@bip32.parse_path("m/2147483647'"))
  assert_eq(p[0], 0xFFFFFFFFU) // 2^31-1 | 0x80000000 = 2^32-1
}
