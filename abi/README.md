# abi

Solidity ABI encoder and decoder, plus the 4-byte function selector derived
from a canonical signature string.

## Status

Working subset of the Solidity ABI spec. **Supported types:**
`uint{8..256}` (multiples of 8), `address`, `bool`, `bytes{1..32}`, dynamic
`bytes`, `string`, dynamic `T[]`, and tuple. **Not supported:** signed
`int*`, fixed-size arrays (`T[N]`), and function types. Decoding validates
zero-padding for `address`, the boolean range, and UTF-8 for `string`.

## Import

```
// In your moon.pkg:
import {
  "skmtkytr/ethbit/abi" @abi,
}
```

## Quick example

```moonbit
// transfer(address,uint256)
let to = @abi.address(b"\x52\x90\x84\x00\x09\x85\x27\x88\x6e\x0f\x70\x30\x06\x98\x57\xd2\xe4\x16\x9e\xe7")
let amt = @abi.uint256_from_u64(1_000_000UL)
let calldata = @abi.encode_function_call("transfer(address,uint256)", [to, amt])
// calldata = 4-byte selector || 32-byte address word || 32-byte uint256 word

let sel = @abi.selector("transfer(address,uint256)")
// sel == b"\xa9\x05\x9c\xbb"
```

## API

| Symbol | Type | Description |
|---|---|---|
| `AbiType` | `enum` | `TUint(Int)`, `TAddress`, `TBool`, `TFixedBytes(Int)`, `TBytes`, `TString`, `TArray(AbiType)`, `TTuple(Array[AbiType])`. `derive(Eq)`. |
| `AbiValue` | `enum` | `VUint(Int, Bytes)`, `VAddress(Bytes)`, `VBool(Bool)`, `VFixedBytes(Int, Bytes)`, `VBytes(Bytes)`, `VString(String)`, `VArray(AbiType, Array[AbiValue])`, `VTuple(Array[AbiValue])`. `derive(Eq, Show)`. |
| `uint256_from_u64` | `(UInt64) -> AbiValue` | Convenience constructor for a `VUint(256, ...)`. |
| `address` | `(Bytes) -> AbiValue` | Wrap raw 20-byte bytes as `VAddress` (length not validated). |
| `encode` | `(Array[AbiValue]) -> Bytes` | Top-level ABI tuple encoding (head-tail). |
| `selector` | `(String) -> Bytes` | First 4 bytes of `keccak256(signature)`. |
| `encode_function_call` | `(String, Array[AbiValue]) -> Bytes` | Selector concatenated with the encoded argument tuple. |
| `decode` | `(Array[AbiType], Bytes) -> Result[Array[AbiValue], DecodeError]` | Decode a flat `data` blob given the expected type list. |
| `DecodeError` | `suberror` | `Truncated(Int)`, `InvalidBool(Byte)`, `NonZeroAddressPad`, `InvalidUtf8`, `ArrayLengthTooLarge(Int)`. `derive(Eq, Show)`. |

## References

- https://docs.soliditylang.org/en/latest/abi-spec.html
- Selector / signature convention from the Solidity contract ABI spec.
- Used by: `rpc` (eth_call payload construction)
