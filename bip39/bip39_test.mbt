// BIP-39 reference vectors from the Trezor test suite:
// https://github.com/trezor/python-mnemonic/blob/master/vectors.json
//
// All vectors here use English (wordlist-independent: we only test the
// PBKDF2-HMAC-SHA-512 seed-derivation step).

fn b39_h(s : String) -> Bytes {
  match @hex.decode(s) {
    Ok(b) => b
    Err(_) => abort("invalid hex literal")
  }
}

test "Trezor vector: 12 abandon... + TREZOR" {
  let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
  let want = b39_h(
    "0xc55257c360c07c72029aebc1b53c05ed0362ada38ead3e3e9efa3708e53495531f09a6987599d18264c1e1c92f2cf141630c7a3c4ab7c81b2f001698e7463b04",
  )
  assert_eq(mnemonic_to_seed(mnemonic, "TREZOR"), want)
}

test "Trezor vector: 12 legal winner... + TREZOR" {
  let mnemonic = "legal winner thank year wave sausage worth useful legal winner thank yellow"
  let want = b39_h(
    "0x2e8905819b8723fe2c1d161860e5ee1830318dbf49a83bd451cfb8440c28bd6fa457fe1296106559a3c80937a1c1069be3a3a5bd381ee6260e8d9739fce1f607",
  )
  assert_eq(mnemonic_to_seed(mnemonic, "TREZOR"), want)
}

test "Trezor vector: 12 letter advice... + TREZOR" {
  let mnemonic = "letter advice cage absurd amount doctor acoustic avoid letter advice cage above"
  let want = b39_h(
    "0xd71de856f81a8acc65e6fc851a38d4d7ec216fd0796d0a6827a3ad6ed5511a30fa280f12eb2e47ed2ac03b5c462a0358d18d69fe4f985ec81778c1b370b652a8",
  )
  assert_eq(mnemonic_to_seed(mnemonic, "TREZOR"), want)
}

test "Trezor vector: 24 abandon...art + TREZOR" {
  let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon art"
  let want = b39_h(
    "0xbda85446c68413707090a52022edd26a1c9462295029f2e60cd7c4f2bbd3097170af7a4d73245cafa9c3cca8d561a7c3de6f5d4a10be8ed2a5e608d68f92fcc8",
  )
  assert_eq(mnemonic_to_seed(mnemonic, "TREZOR"), want)
}

test "Trezor vector: 12 abandon... + empty passphrase" {
  let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
  let want = b39_h(
    "0x5eb00bbddcf069084889a8ab9155568165f5c453ccb85e70811aaed6f6da5fc19a5ac40b389cd370d086206dec8aa6c43daea6690f20ad3d8d48b2d2ce9e38e4",
  )
  assert_eq(mnemonic_to_seed(mnemonic, ""), want)
}
