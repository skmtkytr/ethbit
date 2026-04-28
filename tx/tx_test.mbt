// All reference values were generated with viem (npm)'s
// `serializeTransaction` / `keccak256`, so we are not just verifying our
// impl against itself.

fn h(s : String) -> Bytes {
  match @hex.decode(s) {
    Ok(b) => b
    Err(_) => abort("invalid hex literal in test")
  }
}

fn make_legacy() -> @tx.TxLegacy {
  {
    nonce: b"",
    gas_price: h("0x04a817c800"), // 20 gwei
    gas_limit: h("0x5208"), // 21000
    to: h("0x52908400098527886E0F7030069857D2E4169EE7"),
    value: h("0x0de0b6b3a7640000"), // 1 ETH
    data: b"",
  }
}

fn make_1559() -> @tx.Tx1559 {
  {
    chain_id: h("0x01"),
    nonce: b"",
    max_priority_fee_per_gas: h("0x59682f00"), // 1.5 gwei
    max_fee_per_gas: h("0x06fc23ac00"), // 30 gwei
    gas_limit: h("0x5208"),
    to: h("0x52908400098527886E0F7030069857D2E4169EE7"),
    value: h("0x0de0b6b3a7640000"),
    data: b"",
    access_list: [],
  }
}

// ---------- legacy ----------

test "legacy EIP-155 unsigned encoding (chain_id=1)" {
  let want = h(
    "0xec808504a817c8008252089452908400098527886e0f7030069857d2e4169ee7880de0b6b3a764000080018080",
  )
  assert_eq(@tx.encode_unsigned_legacy(make_legacy(), h("0x01")), want)
}

test "legacy EIP-155 unsigned hash" {
  let want = h("0xc8bffdd06db37ac84c8c6a2d0633530ddf64a1bad9ccba193087e5d1265340c7")
  assert_eq(@tx.hash_unsigned_legacy(make_legacy(), h("0x01")), want)
}

test "legacy signed encoding" {
  let sig : @tx.Signature = {
    v: h("0x25"), // 37
    r: h("0xd5a8c8c0b6da45f29051b7f6e29f9e9b9f3f2f5e8c8a8b8c8d8e8f9f0f1f2f3f"),
    s: h("0x4c4d4e4f5051525354555657585960616263646566676869706a716b6c6d6e6f"),
  }
  let want = h(
    "0xf86c808504a817c8008252089452908400098527886e0f7030069857d2e4169ee7880de0b6b3a76400008025a0d5a8c8c0b6da45f29051b7f6e29f9e9b9f3f2f5e8c8a8b8c8d8e8f9f0f1f2f3fa04c4d4e4f5051525354555657585960616263646566676869706a716b6c6d6e6f",
  )
  assert_eq(@tx.encode_signed_legacy(make_legacy(), sig), want)
}

test "legacy signed tx hash" {
  let sig : @tx.Signature = {
    v: h("0x25"),
    r: h("0xd5a8c8c0b6da45f29051b7f6e29f9e9b9f3f2f5e8c8a8b8c8d8e8f9f0f1f2f3f"),
    s: h("0x4c4d4e4f5051525354555657585960616263646566676869706a716b6c6d6e6f"),
  }
  let want = h("0x22bfa03f55b61ff84996be984c3ee0c9afcb323f3f33de99f40b5ac24beef63b")
  assert_eq(@tx.hash_signed_legacy(make_legacy(), sig), want)
}

// ---------- EIP-1559 ----------

test "EIP-1559 unsigned encoding (no access list)" {
  let want = h(
    "0x02f001808459682f008506fc23ac008252089452908400098527886e0f7030069857d2e4169ee7880de0b6b3a764000080c0",
  )
  assert_eq(@tx.encode_unsigned_1559(make_1559()), want)
}

test "EIP-1559 unsigned hash" {
  let want = h("0x73403f3afaeffeefb806554de377ac5f3b1a7696dbfa45204dd47f9ef6f23f83")
  assert_eq(@tx.hash_unsigned_1559(make_1559()), want)
}

test "EIP-1559 signed encoding (yParity=0)" {
  let sig : @tx.Signature = {
    v: b"", // yParity=0 -> empty Bytes (RLP integer 0)
    r: h("0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"),
    s: h("0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"),
  }
  let want = h(
    "0x02f87301808459682f008506fc23ac008252089452908400098527886e0f7030069857d2e4169ee7880de0b6b3a764000080c080a0aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa0bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  )
  assert_eq(@tx.encode_signed_1559(make_1559(), sig), want)
}

test "EIP-1559 signed tx hash" {
  let sig : @tx.Signature = {
    v: b"",
    r: h("0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"),
    s: h("0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"),
  }
  let want = h("0xe3a24c684820a276a0023a7fe3e8b13d242a27cfa15f1970cd71f7e7cd7ae3f0")
  assert_eq(@tx.hash_signed_1559(make_1559(), sig), want)
}

test "EIP-1559 with access list (1 entry, 2 keys)" {
  let mut tx = make_1559()
  tx = {
    ..tx,
    access_list: [
      {
        address: h("0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed"),
        storage_keys: [
          h("0x0000000000000000000000000000000000000000000000000000000000000001"),
          h("0x0000000000000000000000000000000000000000000000000000000000000002"),
        ],
      },
    ],
  }
  let want = h(
    "0x02f88c01808459682f008506fc23ac008252089452908400098527886e0f7030069857d2e4169ee7880de0b6b3a764000080f85bf859945aaeb6053f3e94c9b9a09f33669435e7ef1beaedf842a00000000000000000000000000000000000000000000000000000000000000001a00000000000000000000000000000000000000000000000000000000000000002",
  )
  assert_eq(@tx.encode_unsigned_1559(tx), want)
  assert_eq(
    @tx.hash_unsigned_1559(tx),
    h("0xcaec35caaa97b611b5335ef9db8ce85b8968f66f0011eb559755fc0771786dab"),
  )
}

test "EIP-1559 contract creation (to = empty)" {
  let tx : @tx.Tx1559 = {
    chain_id: h("0x01"),
    nonce: h("0x05"),
    max_priority_fee_per_gas: h("0x3b9aca00"), // 1 gwei
    max_fee_per_gas: h("0x04a817c800"), // 20 gwei
    gas_limit: h("0x0186a0"), // 100000
    to: b"", // contract creation
    value: b"",
    data: h("0x60806040"),
    access_list: [],
  }
  let want = h("0x02d90105843b9aca008504a817c800830186a080808460806040c0")
  assert_eq(@tx.encode_unsigned_1559(tx), want)
  assert_eq(
    @tx.hash_unsigned_1559(tx),
    h("0xc0233a77a1cf4954d77f1d3baa002dcbee3d100c375645f12da99a8fe3190e1d"),
  )
}
