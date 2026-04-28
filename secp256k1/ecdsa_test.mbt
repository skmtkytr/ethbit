fn e_b16(s : String) -> @bigint.BigInt {
  @bigint.BigInt::from_string(s, radix=16)
}

let test_sk : @bigint.BigInt = e_b16(
  "C9AFA9D845BA75166B5C215767B1D6934E50C3DB36E89B127B8A622B120F6721",
)

// ---- sign / verify round-trip ----

test "sign + verify_with_pubkey round-trip" {
  let pk = @secp256k1.mul_g(test_sk)
  let msg_hash = @sha256.sha256(b"sample")
  let sig = @secp256k1.sign(test_sk, msg_hash)
  assert_true(@secp256k1.verify_with_pubkey(pk, msg_hash, sig))
}

test "verify rejects signature on different message" {
  let pk = @secp256k1.mul_g(test_sk)
  let h1 = @sha256.sha256(b"sample")
  let h2 = @sha256.sha256(b"test")
  let sig = @secp256k1.sign(test_sk, h1)
  assert_eq(@secp256k1.verify_with_pubkey(pk, h2, sig), false)
}

test "verify rejects signature against wrong public key" {
  let pk_wrong = @secp256k1.mul_g(@secp256k1.nadd(test_sk, e_b16("01")))
  let msg_hash = @sha256.sha256(b"sample")
  let sig = @secp256k1.sign(test_sk, msg_hash)
  assert_eq(@secp256k1.verify_with_pubkey(pk_wrong, msg_hash, sig), false)
}

test "verify rejects tampered s" {
  let pk = @secp256k1.mul_g(test_sk)
  let msg_hash = @sha256.sha256(b"sample")
  let sig = @secp256k1.sign(test_sk, msg_hash)
  let tampered : @secp256k1.EcdsaSig = {
    r: sig.r,
    s: @secp256k1.nadd(sig.s, e_b16("01")),
    recid: sig.recid,
  }
  assert_eq(@secp256k1.verify_with_pubkey(pk, msg_hash, tampered), false)
}

// ---- determinism ----

test "sign is deterministic — same priv+hash gives same sig" {
  let h = @sha256.sha256(b"sample")
  let s1 = @secp256k1.sign(test_sk, h)
  let s2 = @secp256k1.sign(test_sk, h)
  assert_eq(s1.r, s2.r)
  assert_eq(s1.s, s2.s)
  assert_eq(s1.recid, s2.recid)
}

// ---- low-s normalization ----

test "sign produces low-s (s <= n/2)" {
  let h = @sha256.sha256(b"sample")
  let sig = @secp256k1.sign(test_sk, h)
  assert_true(sig.s <= @secp256k1.n / e_b16("02"))
}

// ---- recover ----

test "recover yields the original public key" {
  let pk = @secp256k1.mul_g(test_sk)
  let msg_hash = @sha256.sha256(b"sample")
  let sig = @secp256k1.sign(test_sk, msg_hash)
  match @secp256k1.recover(msg_hash, sig) {
    Some(rec_pk) => assert_true(@secp256k1.point_eq(rec_pk, pk))
    None => assert_true(false)
  }
}

test "recover with wrong recid yields different (or no) key" {
  let pk = @secp256k1.mul_g(test_sk)
  let msg_hash = @sha256.sha256(b"sample")
  let sig = @secp256k1.sign(test_sk, msg_hash)
  let flipped : @secp256k1.EcdsaSig = {
    r: sig.r,
    s: sig.s,
    recid: sig.recid ^ 1, // flip yParity
  }
  match @secp256k1.recover(msg_hash, flipped) {
    Some(other) => assert_eq(@secp256k1.point_eq(other, pk), false)
    None => () // also acceptable
  }
}

test "recover round-trip: many small private keys" {
  let hashes = [b"alpha", b"beta", b"gamma"]
  for sk_int = 1; sk_int <= 5; sk_int = sk_int + 1 {
    let sk = @bigint.BigInt::from_int(sk_int)
    let pk = @secp256k1.mul_g(sk)
    for hi = 0; hi < hashes.length(); hi = hi + 1 {
      let h = @sha256.sha256(hashes[hi])
      let sig = @secp256k1.sign(sk, h)
      match @secp256k1.recover(h, sig) {
        Some(rec) => assert_true(@secp256k1.point_eq(rec, pk))
        None => assert_true(false)
      }
    }
  }
}

// ---- structural checks ----

test "sign result: r and s in [1, n-1]" {
  let h = @sha256.sha256(b"sample")
  let sig = @secp256k1.sign(test_sk, h)
  assert_true(@secp256k1.is_valid_scalar(sig.r))
  assert_true(@secp256k1.is_valid_scalar(sig.s))
}

test "sign result: recid in {0, 1, 2, 3}" {
  let h = @sha256.sha256(b"sample")
  let sig = @secp256k1.sign(test_sk, h)
  assert_true(sig.recid >= 0 && sig.recid <= 3)
}
