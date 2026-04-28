# tx

Ethereum transaction encoding and signing for legacy (EIP-155),
EIP-1559 (type 2), and EIP-4844 (type 3, blob) transactions.

## Status

Encoding and signing are implemented for all three transaction types.
Signed bytes are cross-checked byte-for-byte against viem's
`signTransaction` (`viem/accounts`) for the same input — see
`viem_vectors_test.mbt` for the recorded vectors.

Numeric fields are passed as **big-endian `Bytes` with no leading zeros**
(matching the RLP integer convention; zero is the empty `Bytes` `b""`).
The caller is responsible for normalizing inputs. `to` is either an exact
20-byte address or `b""` for contract creation.

The signer emits only the low bit of `recid` for `v`. The `recid` bit-1
case (`R.x >= n`) has probability ~2^-128 and is ignored; a higher-assurance
implementation would re-roll the nonce.

## Import

```
// In your moon.pkg:
import {
  "moonbitlang/core/bigint" @bigint,
  "skmtkytr/ethbit/tx" @tx,
}
```

## Quick example

```moonbit
let txn : @tx.Tx1559 = {
  chain_id: b"\x01",
  nonce: b"",
  max_priority_fee_per_gas: b"\x59\x68\x2f\x00",
  max_fee_per_gas: b"\x06\xfc\x23\xac\x00",
  gas_limit: b"\x52\x08",
  to: to_20_bytes,
  value: b"\x0d\xe0\xb6\xb3\xa7\x64\x00\x00",  // 1 ETH in wei
  data: b"",
  access_list: [],
}
let raw = @tx.sign_and_encode_1559(txn, sk)  // ready for eth_sendRawTransaction
```

## API

| Symbol | Type | Description |
|---|---|---|
| `Signature` | `struct` | `{ v : Bytes, r : Bytes, s : Bytes }`. For typed txs `v` carries yParity (`b""` or `b"\x01"`). |
| `AccessListEntry` | `struct` | `{ address : Bytes, storage_keys : Array[Bytes] }`. |
| `TxLegacy` | `struct` | Pre-typed-tx fields: nonce, gas_price, gas_limit, to, value, data. |
| `Tx1559` | `struct` | EIP-1559 fields including `access_list`. |
| `Tx4844` | `struct` | EIP-4844 fields including `max_fee_per_blob_gas` and `blob_versioned_hashes`. |
| `encode_unsigned_legacy` | `(TxLegacy, Bytes) -> Bytes` | EIP-155 unsigned RLP `[..., chainId, 0, 0]`. |
| `encode_signed_legacy` | `(TxLegacy, Signature) -> Bytes` | Signed legacy RLP `[..., v, r, s]`. |
| `hash_unsigned_legacy` / `hash_signed_legacy` | `... -> Bytes` | `keccak256` of the encoding. |
| `encode_unsigned_1559` / `encode_signed_1559` | `... -> Bytes` | `0x02 \|\| rlp([...])`. |
| `hash_unsigned_1559` / `hash_signed_1559` | `... -> Bytes` | `keccak256` of the encoding. |
| `encode_unsigned_4844` / `encode_signed_4844` | `... -> Bytes` | `0x03 \|\| rlp([...])`. |
| `hash_unsigned_4844` / `hash_signed_4844` | `... -> Bytes` | `keccak256` of the encoding. |
| `sign_legacy` | `(TxLegacy, Bytes, BigInt) -> Signature` | RFC 6979 deterministic ECDSA; `v = chain_id*2 + 35 + yParity`. |
| `sign_1559` | `(Tx1559, BigInt) -> Signature` | RFC 6979 deterministic ECDSA; `v` = yParity. |
| `sign_4844` | `(Tx4844, BigInt) -> Signature` | RFC 6979 deterministic ECDSA; `v` = yParity. |
| `sign_and_encode_legacy` | `(TxLegacy, Bytes, BigInt) -> Bytes` | `encode_signed_legacy(tx, sign_legacy(...))`. |
| `sign_and_encode_1559` | `(Tx1559, BigInt) -> Bytes` | `encode_signed_1559(tx, sign_1559(...))`. |
| `sign_and_encode_4844` | `(Tx4844, BigInt) -> Bytes` | `encode_signed_4844(tx, sign_4844(...))`. |

## References

- EIP-155 (chain-id replay protection): https://eips.ethereum.org/EIPS/eip-155
- EIP-2718 (typed envelope): https://eips.ethereum.org/EIPS/eip-2718
- EIP-2930 (access lists): https://eips.ethereum.org/EIPS/eip-2930
- EIP-1559 (fee market): https://eips.ethereum.org/EIPS/eip-1559
- EIP-4844 (blob transactions): https://eips.ethereum.org/EIPS/eip-4844
- viem cross-check: `tx/viem_vectors_test.mbt`
- Depends on: `rlp`, `keccak`, `secp256k1`, `bytesx`
