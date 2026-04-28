# ethbit

Multi-platform Ethereum wallet toolkit in MoonBit. Targets `wasm-gc`,
`native`, and `js` from a single source.

## Status

Pre-1.0. The cryptographic primitives, RLP / ABI / address / unit conversion,
transaction encoding and signing (legacy / EIP-1559 / EIP-4844),
EIP-191 / EIP-712 message signing, BIP-32 HD key derivation,
BIP-39 mnemonics, Base58 / Base58Check, JSON-RPC encoder/decoder for the
`eth_` / `debug_` / `trace_` / `net_` / `web3_` / `txpool_` namespaces,
and the WebSocket protocol layer are implemented and validated against
the relevant standards and against viem v2 byte-for-byte where applicable.

What is **not** in the box:

- A network transport layer. `rpc` and `ws` produce and consume strings;
  the user pumps them through their target's HTTP / WS / TCP / TLS client.
- ENS, contract helpers, and a Web3 keystore (v3 JSON encrypt/decrypt).
- Full ICAP / EIP-1191 chain-aware checksum.
- Decoders for signed transaction bytes (encoding only).

See [`TODO.md`](TODO.md) for the full deferred-work list.

## Security position

This library follows the same position as `noble-curves`: best-effort
algorithmic constant time, **no language-level constant-time guarantee**.
`@bigint` arithmetic is variable-time on every backend; the `secp256k1`
package uses a Montgomery ladder at the algorithmic level but cannot
prevent the underlying compiler / runtime from re-introducing
secret-dependent branches.

For real-funds production use, bridge to `libsecp256k1` (or equivalent)
via FFI. For educational and testnet use, this library is appropriate.

The position is documented in [`secp256k1/SECURITY.md`](secp256k1/SECURITY.md)
and the empirical timing-leak measurements that anchor it are in
[`cttest/REPORT.md`](cttest/REPORT.md).

## Packages

### Cryptographic primitives

| Package | Summary |
|---|---|
| [`hex`](hex/README.md) | 0x-prefixed hex encode / decode |
| [`keccak`](keccak/README.md) | Keccak-256 (Ethereum variant; pre-NIST) |
| [`sha256`](sha256/README.md) | SHA-256 + HMAC-SHA-256 (FIPS 180-4 + RFC 2104) |
| [`sha512`](sha512/README.md) | SHA-512 + HMAC-SHA-512 |
| [`ripemd160`](ripemd160/README.md) | RIPEMD-160 |
| [`base58`](base58/README.md) | Base58 + Base58Check (Bitcoin / BIP-32 convention) |

### Encoding

| Package | Summary |
|---|---|
| [`bytesx`](bytesx/README.md) | Small `Bytes` helpers shared across packages |
| [`rlp`](rlp/README.md) | RLP encode / decode (canonical-strict) |
| [`abi`](abi/README.md) | Solidity ABI encode / decode + 4-byte selector |

### Ethereum primitives

| Package | Summary |
|---|---|
| [`address`](address/README.md) | EIP-55 checksum + public-key → 20-byte address |
| [`units`](units/README.md) | ether / gwei / wei parse + format (viem-compatible) |
| [`tx`](tx/README.md) | Legacy (EIP-155), EIP-1559, EIP-4844 transactions |
| [`msg`](msg/README.md) | EIP-191 personal_sign + full EIP-712 typed-data signing |

### Wallet / HD

| Package | Summary |
|---|---|
| [`secp256k1`](secp256k1/README.md) | ECDSA with RFC 6979 deterministic nonces |
| [`bip32`](bip32/README.md) | BIP-32 HD derivation + xprv / xpub serialization |
| [`bip39`](bip39/README.md) | BIP-39 mnemonics (English wordlist + entropy ↔ seed) |

### Network protocols

| Package | Summary |
|---|---|
| [`rpc`](rpc/README.md) | JSON-RPC 2.0 encoder / decoder for the standard Ethereum namespaces |
| [`ws`](ws/README.md) | WebSocket (RFC 6455) frame and handshake helpers |

### Testing

| Package | Summary |
|---|---|
| [`cttest`](cttest/README.md) | Empirical timing-leak testbed (dudect-style) |

## Quick example

Sign and encode an EIP-1559 transaction with a known private key:

```moonbit
let tx : @tx.Tx1559 = {
  chain_id: b"\x01",
  nonce: b"",
  max_priority_fee_per_gas: b"\x59\x68\x2f\x00",       // 1.5 gwei
  max_fee_per_gas: b"\x06\xfc\x23\xac\x00",            // 30 gwei
  gas_limit: b"\x52\x08",                              // 21000
  to: hex_decode("0x52908400098527886E0F7030069857D2E4169EE7"),
  value: b"\x0d\xe0\xb6\xb3\xa7\x64\x00\x00",          // 1 ETH
  data: b"",
  access_list: [],
}
let sk = @bigint.BigInt::from_int(1)
let raw = @tx.sign_and_encode_1559(tx, sk)
// raw is the broadcastable 0x02-prefixed bytes
```

Derive an Ethereum address from a private key:

```moonbit
let pk = @secp256k1.pubkey_from_sk(@bigint.BigInt::from_int(1))
let xy = @secp256k1.pubkey_to_xy_bytes(pk)
let addr = @address.from_pubkey_xy(xy) // 0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf
```

Each package's `README.md` has more focused examples.

## Building and testing

```fish
moon check                              # type-check
moon test                               # run all tests on the default target
moon test --target wasm-gc              # cross-target
moon test --target js
```

Benchmarks are in `*_bench_test.mbt` files; run with `moon bench`.

## Development conventions

See [`TODO.md`](TODO.md) for outstanding work.

Cross-library validation against viem (npm) v2 is the bar for
interoperability. Vectors are pinned in `*_viem_vectors_test.mbt` files
inside the relevant packages. The script that produced them lives outside
the repo (instructions can be regenerated; see commit history if needed).

## License

MIT. See [`LICENSE`](LICENSE).
