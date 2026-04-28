# address

EIP-55 mixed-case checksum address encoding and validation, plus a helper
to derive a 20-byte address from an SEC1 public-key body.

## Status

Complete. `to_checksum` produces the canonical EIP-55 mixed-case form;
`is_valid_checksum` verifies an input matches that form **exactly** —
all-lowercase and all-uppercase strings are rejected even though they
are otherwise valid Ethereum addresses (this preserves the typo-guard
property of EIP-55). `from_pubkey_xy` takes the 64-byte `x || y`
concatenation (no `0x04` SEC1 prefix) and returns the last 20 bytes of
`keccak256(x || y)`.

## Import

```
// In your moon.pkg:
import {
  "skmtkytr/ethbit/address" @address,
}
```

## Quick example

```moonbit
let raw = b"\x52\x90\x84\x00\x09\x85\x27\x88\x6e\x0f\x70\x30\x06\x98\x57\xd2\xe4\x16\x9e\xe7"
match @address.to_checksum(raw) {
  Ok(s) => assert_eq(s, "0x52908400098527886E0F7030069857D2E4169EE7")
  Err(_) => abort("unreachable")
}

let ok = @address.is_valid_checksum("0x52908400098527886E0F7030069857D2E4169EE7")
// ok == true

// Derive an address from secp256k1 public-key xy bytes (64 bytes).
match @address.from_pubkey_xy(xy_64_bytes) {
  Ok(addr20) => ()
  Err(_) => ()
}
```

## API

| Symbol | Type | Description |
|---|---|---|
| `to_checksum` | `(Bytes) -> Result[String, AddressError]` | Render 20-byte address as `0x`-prefixed EIP-55 mixed-case string. |
| `is_valid_checksum` | `(String) -> Bool` | True iff input is `0x` + 40 hex chars whose case matches the EIP-55 checksum exactly. |
| `from_pubkey_xy` | `(Bytes) -> Result[Bytes, AddressError]` | Last 20 bytes of `keccak256(x \|\| y)`; expects exactly 64 bytes. |
| `AddressError` | `suberror` | `InvalidLength(Int)`. `derive(Eq, Show)`. |

## References

- https://eips.ethereum.org/EIPS/eip-55
- Used by: `tx` (tests), `msg` (tests), `bip32`
