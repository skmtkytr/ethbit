# msg

Ethereum message signing: EIP-191 `personal_sign` and EIP-712 typed-data
(version 4) — including a full type-string encoder, `structHash`, and a
high-level `sign_typed_data_v4` that mirrors viem's `signTypedData`.

## Status

Both EIP-191 and EIP-712 v4 paths are implemented. The EIP-712 layer
includes dependency-walking `encode_type`, cycle detection, dynamic
arrays (`T[]`), nested structs, and the canonical viem-ordered
`EIP712Domain` (only `Some` fields participate). Validated against the
EIP-712 spec example (Mail/Person from the EIP body) plus a viem-derived
signer-address vector for `sk = 1`. Pre-computed-digest helpers
(`typed_data_digest`, `sign_typed_data`) are kept alongside the
description-driven layer for callers that compute hashes themselves.

Output convention matches viem / ethers.js for ECDSA recovery:
`r` and `s` are 32-byte big-endian zero-padded; `v` is a single byte
`0x1B` (yParity = 0) or `0x1C` (yParity = 1) — never empty.

## Import

```
// In your moon.pkg:
import {
  "moonbitlang/core/bigint" @bigint,
  "skmtkytr/ethbit/msg" @msg,
}
```

## Quick example

```moonbit
// EIP-191 personal_sign
let sig = @msg.personal_sign(sk, b"hello")
// sig.r / sig.s : 32-byte BE; sig.v : b"\x1b" or b"\x1c"

// EIP-712 typed-data v4
let domain : @msg.Domain = {
  name: Some("MyDApp"),
  version: Some("1"),
  chain_id: Some(@bigint.BigInt::from_int(1)),
  verifying_contract: Some(verifying_contract_20_bytes),
  salt: None,
}
let types : @msg.TypeRegistry = Map::new()
types.set("Mail", [
  { name: "from", type_: "Person" },
  { name: "to", type_: "Person" },
  { name: "contents", type_: "string" },
])
types.set("Person", [
  { name: "name", type_: "string" },
  { name: "wallet", type_: "address" },
])
let message : @msg.Value = @msg.V_struct("Mail", [
  ("from", @msg.V_struct("Person", [("name", @msg.V_string("Alice")), ("wallet", @msg.V_address(alice_addr))])),
  ("to", @msg.V_struct("Person", [("name", @msg.V_string("Bob")), ("wallet", @msg.V_address(bob_addr))])),
  ("contents", @msg.V_string("hi")),
])
match @msg.sign_typed_data_v4(sk, domain, "Mail", types, message) {
  Ok(signed) => ()
  Err(e) => abort(e.to_string())
}
```

## API

| Symbol | Type | Description |
|---|---|---|
| `SignedMessage` | `struct` | `{ r : Bytes, s : Bytes, v : Bytes }`. `r`/`s` are 32-byte BE; `v` is `b"\x1b"` or `b"\x1c"`. |
| `int_to_ascii_decimal` | `(Int) -> Bytes` | ASCII decimal encoding of a non-negative `Int`; `0` -> `b"0"`. |
| `personal_message_hash` | `(Bytes) -> Bytes` | EIP-191 preimage digest: `keccak256(0x19 \|\| "Ethereum Signed Message:\n" \|\| len_ascii \|\| message)`. |
| `personal_sign` | `(BigInt, Bytes) -> SignedMessage` | Sign the EIP-191 preimage. |
| `typed_data_digest` | `(Bytes, Bytes) -> Bytes` | `keccak256(0x19 0x01 \|\| domain_separator \|\| struct_hash)`; both inputs must be 32 bytes. |
| `sign_typed_data` | `(BigInt, Bytes, Bytes) -> SignedMessage` | Sign a pre-computed EIP-712 digest. |
| `Domain` | `struct` | EIP-712 domain — all fields optional; `name`, `version`, `chain_id`, `verifying_contract`, `salt`. |
| `Field` | `struct` | `{ name : String, type_ : String }`. |
| `Value` | `enum` | Typed-data value tree: `V_uint(Int, BigInt)`, `V_int(Int, BigInt)`, `V_bool(Bool)`, `V_address(Bytes)`, `V_bytes_n(Int, Bytes)`, `V_bytes(Bytes)`, `V_string(String)`, `V_array(String, Array[Value])`, `V_struct(String, Array[(String, Value)])`. |
| `TypeRegistry` | `Map[String, Array[Field]]` | Struct-name to ordered fields; `EIP712Domain` is built internally from `Domain`. |
| `encode_type` | `(String, TypeRegistry) -> Result[String, Eip712Error]` | Canonical EIP-712 `encodeType` (primary first, deps sorted alphabetically). |
| `type_hash` | `(String, TypeRegistry) -> Result[Bytes, Eip712Error]` | `keccak256(encode_type(...))`. |
| `struct_hash` | `(String, TypeRegistry, Value) -> Result[Bytes, Eip712Error]` | `keccak256(typeHash \|\| encodeData(message))`. |
| `domain_separator` | `(Domain) -> Bytes` | `structHash("EIP712Domain", domain)`. |
| `hash_typed_data` | `(Domain, String, TypeRegistry, Value) -> Result[Bytes, Eip712Error]` | Full EIP-712 v4 digest. |
| `sign_typed_data_v4` | `(BigInt, Domain, String, TypeRegistry, Value) -> Result[SignedMessage, Eip712Error]` | Description-driven EIP-712 v4 signing. |
| `Eip712Error` | `suberror` | `UnknownType(String)`, `TypeMismatch(String, String)`, `InvalidAddress(Int)`, `InvalidBytesN(Int, Int)`, `CircularType(String)`. `derive(Show)`. |

## References

- EIP-191 (signed-data standard): https://eips.ethereum.org/EIPS/eip-191
- EIP-712 (typed structured data): https://eips.ethereum.org/EIPS/eip-712
- viem `signTypedData`: https://viem.sh/docs/actions/wallet/signTypedData
- Validated against the EIP-712 spec Mail/Person example; signer-address vector cross-checked with viem.
- Depends on: `keccak`, `secp256k1`, `bytesx`
