# bip32

BIP-32 hierarchical deterministic key derivation, plus xprv/xpub
Base58Check serialization and the public-side child derivation (CKDpub).
Spec: <https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki>.

## Status

Implements both the private (CKDpriv) and public (CKDpub) derivation paths,
master-from-seed, path parsing/derivation, and the 78-byte serialized form
used for xprv/tprv and xpub/tpub. Validated against BIP-32 Test Vector 1
(seed `0x000102…0f`) — see `bip32_test.mbt` and `serialize_test.mbt`.

Hardened indices are accepted on the private side (high bit `0x80000000`)
and rejected with `InvalidPath` on `derive_child_pub`.

## Import

```
// In your moon.pkg:
import {
  "skmtkytr/ethbit/bip32" @bip32,
}
```

## Quick example

```moonbit
// Master key from BIP-39 seed.
let seed : Bytes = mnemonic_seed // 64 bytes
let master = @bip32.master_from_seed(seed).unwrap()

// Derive an Ethereum account: m/44'/60'/0'/0/0
let leaf = @bip32.derive_path(seed, "m/44'/60'/0'/0/0").unwrap()

// Serialize (mainnet xprv / xpub).
let xprv : String = @bip32.serialize_xprv(leaf, Mainnet)
let xpub : String = @bip32.serialize_xpub(leaf, Mainnet)

// Public-only walk (no secret involved).
let xpub_obj = @bip32.parse_xpub(xpub, Mainnet).unwrap()
let child_pub = @bip32.derive_child_pub(xpub_obj, 0U).unwrap()
```

## API

### Types

| Symbol | Type | Description |
|---|---|---|
| `ExtendedPrivateKey` | `struct { key, chain_code, depth, parent_fingerprint, child_number }` | private node |
| `ExtendedPublicKey` | `struct { pub_x, pub_y, chain_code, depth, parent_fingerprint, child_number }` | public node |
| `Network` | `enum { Mainnet, Testnet }` | xprv/tprv version select |
| `DeriveError` | `suberror { InvalidSeedLength, InvalidPath, IndexOutOfRange, KeyNotInRange }` | – |
| `SerializationError` | `suberror { WrongNetwork, WrongKeyType, InvalidLength, InvalidVersion, Base58Error, KeyOutOfRange }` | – |

### Functions

| Symbol | Type | Description |
|---|---|---|
| `master_from_seed` | `Bytes -> Result[ExtendedPrivateKey, DeriveError]` | BIP-32 §3.1 |
| `derive_child` | `(ExtendedPrivateKey, UInt) -> Result[ExtendedPrivateKey, DeriveError]` | CKDpriv |
| `parse_path` | `String -> Result[Array[UInt], DeriveError]` | parses `m/44'/60'/...` |
| `derive_path` | `(Bytes, String) -> Result[ExtendedPrivateKey, DeriveError]` | seed + path → leaf |
| `serialize_xprv` | `(ExtendedPrivateKey, Network) -> String` | Base58Check xprv/tprv |
| `serialize_xpub` | `(ExtendedPrivateKey, Network) -> String` | Base58Check xpub/tpub |
| `parse_xprv` | `(String, Network) -> Result[ExtendedPrivateKey, SerializationError]` | – |
| `parse_xpub` | `(String, Network) -> Result[ExtendedPublicKey, SerializationError]` | – |
| `extended_to_public` | `ExtendedPrivateKey -> ExtendedPublicKey` | project public side |
| `derive_child_pub` | `(ExtendedPublicKey, UInt) -> Result[ExtendedPublicKey, DeriveError]` | CKDpub (non-hardened) |

## References

- BIP-32: <https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki>
- BIP-32 Test Vectors: <https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki#test-vectors>
- Sibling packages: [`../secp256k1`](../secp256k1), [`../base58`](../base58),
  [`../sha256`](../sha256), [`../sha512`](../sha512), [`../ripemd160`](../ripemd160)
