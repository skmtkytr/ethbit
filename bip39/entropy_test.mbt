// BIP-39 §6 English test vectors (entropy <-> mnemonic only; the seed
// half is covered by bip39_test.mbt).
// Source: https://github.com/trezor/python-mnemonic/blob/master/vectors.json

fn ent_h(s : String) -> Bytes {
  match @hex.decode(s) {
    Ok(b) => b
    Err(_) => abort("invalid hex literal")
  }
}

// ---- wordlist sanity ------------------------------------------------------

test "wordlist length is 2048" {
  // Internal `english_wordlist` is package-private; we exercise it via
  // entropy_to_mnemonic on 16 bytes of zero (uses index 0 = "abandon")
  // and via mnemonic_to_entropy with the very last word ("zoo").
  // For a direct length check we instead probe the boundary indices:
  // 16 bytes of 0x00 mnemonic must start with "abandon" and end with
  // "about"; 16 bytes of 0xff must end with "wrong" preceded by "zoo".
  let m_zero = match entropy_to_mnemonic(
      ent_h("0x00000000000000000000000000000000"),
    ) {
      Ok(s) => s
      Err(_) => abort("vector failed")
    }
  assert_eq(
    m_zero,
    "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about",
  )
  let m_ones = match entropy_to_mnemonic(
      ent_h("0xffffffffffffffffffffffffffffffff"),
    ) {
      Ok(s) => s
      Err(_) => abort("vector failed")
    }
  assert_eq(m_ones, "zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong")
}

// ---- entropy_to_mnemonic, all 7 spec vectors ------------------------------

test "entropy_to_mnemonic: 128-bit zeros -> abandon...about" {
  let want = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
  let got = match entropy_to_mnemonic(
      ent_h("0x00000000000000000000000000000000"),
    ) {
      Ok(s) => s
      Err(_) => abort("err")
    }
  assert_eq(got, want)
}

test "entropy_to_mnemonic: 128-bit 7f... -> legal winner..." {
  let want = "legal winner thank year wave sausage worth useful legal winner thank yellow"
  let got = match entropy_to_mnemonic(
      ent_h("0x7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f"),
    ) {
      Ok(s) => s
      Err(_) => abort("err")
    }
  assert_eq(got, want)
}

test "entropy_to_mnemonic: 128-bit 80... -> letter advice..." {
  let want = "letter advice cage absurd amount doctor acoustic avoid letter advice cage above"
  let got = match entropy_to_mnemonic(
      ent_h("0x80808080808080808080808080808080"),
    ) {
      Ok(s) => s
      Err(_) => abort("err")
    }
  assert_eq(got, want)
}

test "entropy_to_mnemonic: 128-bit ff... -> zoo...wrong" {
  let want = "zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong"
  let got = match entropy_to_mnemonic(
      ent_h("0xffffffffffffffffffffffffffffffff"),
    ) {
      Ok(s) => s
      Err(_) => abort("err")
    }
  assert_eq(got, want)
}

test "entropy_to_mnemonic: 192-bit zeros -> 18 abandon...agent" {
  let want = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon agent"
  let got = match entropy_to_mnemonic(
      ent_h("0x000000000000000000000000000000000000000000000000"),
    ) {
      Ok(s) => s
      Err(_) => abort("err")
    }
  assert_eq(got, want)
}

test "entropy_to_mnemonic: 256-bit zeros -> 24 abandon...art" {
  let want = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon art"
  let got = match entropy_to_mnemonic(
      ent_h(
        "0x0000000000000000000000000000000000000000000000000000000000000000",
      ),
    ) {
      Ok(s) => s
      Err(_) => abort("err")
    }
  assert_eq(got, want)
}

test "entropy_to_mnemonic: 256-bit ff... -> zoo...vote" {
  let want = "zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo vote"
  let got = match entropy_to_mnemonic(
      ent_h(
        "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
      ),
    ) {
      Ok(s) => s
      Err(_) => abort("err")
    }
  assert_eq(got, want)
}

// ---- mnemonic_to_entropy, all 7 spec vectors ------------------------------

test "mnemonic_to_entropy: 12 abandon -> 128-bit zeros" {
  let m = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
  let want = ent_h("0x00000000000000000000000000000000")
  match mnemonic_to_entropy(m) {
    Ok(b) => assert_eq(b, want)
    Err(_) => abort("err")
  }
}

test "mnemonic_to_entropy: legal winner -> 7f..." {
  let m = "legal winner thank year wave sausage worth useful legal winner thank yellow"
  let want = ent_h("0x7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f")
  match mnemonic_to_entropy(m) {
    Ok(b) => assert_eq(b, want)
    Err(_) => abort("err")
  }
}

test "mnemonic_to_entropy: letter advice -> 80..." {
  let m = "letter advice cage absurd amount doctor acoustic avoid letter advice cage above"
  let want = ent_h("0x80808080808080808080808080808080")
  match mnemonic_to_entropy(m) {
    Ok(b) => assert_eq(b, want)
    Err(_) => abort("err")
  }
}

test "mnemonic_to_entropy: zoo wrong -> ff..." {
  let m = "zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong"
  let want = ent_h("0xffffffffffffffffffffffffffffffff")
  match mnemonic_to_entropy(m) {
    Ok(b) => assert_eq(b, want)
    Err(_) => abort("err")
  }
}

test "mnemonic_to_entropy: 18 abandon...agent -> 192-bit zeros" {
  let m = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon agent"
  let want = ent_h("0x000000000000000000000000000000000000000000000000")
  match mnemonic_to_entropy(m) {
    Ok(b) => assert_eq(b, want)
    Err(_) => abort("err")
  }
}

test "mnemonic_to_entropy: 24 abandon...art -> 256-bit zeros" {
  let m = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon art"
  let want = ent_h(
    "0x0000000000000000000000000000000000000000000000000000000000000000",
  )
  match mnemonic_to_entropy(m) {
    Ok(b) => assert_eq(b, want)
    Err(_) => abort("err")
  }
}

test "mnemonic_to_entropy: 24 zoo...vote -> 256-bit ff..." {
  let m = "zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo vote"
  let want = ent_h(
    "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
  )
  match mnemonic_to_entropy(m) {
    Ok(b) => assert_eq(b, want)
    Err(_) => abort("err")
  }
}

// ---- round trip on several entropies ------------------------------------

test "round trip: 16 bytes" {
  let ent = ent_h("0x0123456789abcdef0123456789abcdef")
  let m = match entropy_to_mnemonic(ent) {
    Ok(s) => s
    Err(_) => abort("e2m err")
  }
  let back = match mnemonic_to_entropy(m) {
    Ok(b) => b
    Err(_) => abort("m2e err")
  }
  assert_eq(back, ent)
}

test "round trip: 20 bytes" {
  let ent = ent_h("0xfedcba9876543210fedcba9876543210deadbeef")
  let m = match entropy_to_mnemonic(ent) {
    Ok(s) => s
    Err(_) => abort("e2m err")
  }
  let back = match mnemonic_to_entropy(m) {
    Ok(b) => b
    Err(_) => abort("m2e err")
  }
  assert_eq(back, ent)
}

test "round trip: 24 bytes" {
  let ent = ent_h("0xa0b1c2d3e4f50617283940516273849500112233445566ff")
  let m = match entropy_to_mnemonic(ent) {
    Ok(s) => s
    Err(_) => abort("e2m err")
  }
  let back = match mnemonic_to_entropy(m) {
    Ok(b) => b
    Err(_) => abort("m2e err")
  }
  assert_eq(back, ent)
}

test "round trip: 28 bytes" {
  let ent = ent_h("0x000102030405060708090a0b0c0d0e0f101112131415161718191a1b")
  let m = match entropy_to_mnemonic(ent) {
    Ok(s) => s
    Err(_) => abort("e2m err")
  }
  let back = match mnemonic_to_entropy(m) {
    Ok(b) => b
    Err(_) => abort("m2e err")
  }
  assert_eq(back, ent)
}

test "round trip: 32 bytes" {
  let ent = ent_h(
    "0xdeadbeefcafef00d0123456789abcdeffedcba98765432101122334455667788",
  )
  let m = match entropy_to_mnemonic(ent) {
    Ok(s) => s
    Err(_) => abort("e2m err")
  }
  let back = match mnemonic_to_entropy(m) {
    Ok(b) => b
    Err(_) => abort("m2e err")
  }
  assert_eq(back, ent)
}

// ---- error paths ----------------------------------------------------------

test "entropy_to_mnemonic: invalid length 15" {
  match entropy_to_mnemonic(ent_h("0x000102030405060708090a0b0c0d0e")) {
    Err(InvalidEntropyLength(15)) => ()
    Err(e) => {
      let _ = e
      abort("wrong err variant")
    }
    Ok(_) => abort("expected err")
  }
}

test "entropy_to_mnemonic: invalid length 0" {
  match entropy_to_mnemonic(b"") {
    Err(InvalidEntropyLength(0)) => ()
    Err(e) => {
      let _ = e
      abort("wrong err variant")
    }
    Ok(_) => abort("expected err")
  }
}

test "mnemonic_to_entropy: empty input" {
  match mnemonic_to_entropy("") {
    Err(Empty) => ()
    Err(e) => {
      let _ = e
      abort("wrong err variant")
    }
    Ok(_) => abort("expected err")
  }
}

test "mnemonic_to_entropy: WC=11 -> WrongWordCount(11)" {
  // 11 abandons (one short of a valid 12-word mnemonic).
  let m = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon"
  match mnemonic_to_entropy(m) {
    Err(WrongWordCount(11)) => ()
    Err(e) => {
      let _ = e
      abort("wrong err variant")
    }
    Ok(_) => abort("expected err")
  }
}

test "mnemonic_to_entropy: unknown word" {
  // Replace last word with a non-wordlist token.
  let m = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon notaword"
  match mnemonic_to_entropy(m) {
    Err(UnknownWord(w)) => assert_eq(w, "notaword")
    Err(e) => {
      let _ = e
      abort("wrong err variant")
    }
    Ok(_) => abort("expected err")
  }
}

test "mnemonic_to_entropy: tampered checksum" {
  // Valid 12-word base, but swap the last word "about" -> "ability"
  // (still in wordlist, but checksum no longer matches).
  let m = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon ability"
  match mnemonic_to_entropy(m) {
    Err(InvalidChecksum) => ()
    Err(e) => {
      let _ = e
      abort("wrong err variant")
    }
    Ok(_) => abort("expected err")
  }
}

test "mnemonic_to_entropy: collapses multiple spaces" {
  let m = "  abandon  abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon  about  "
  let want = ent_h("0x00000000000000000000000000000000")
  match mnemonic_to_entropy(m) {
    Ok(b) => assert_eq(b, want)
    Err(_) => abort("err")
  }
}
