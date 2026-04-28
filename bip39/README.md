# bip39

BIP-39 mnemonic codec: entropy ↔ mnemonic conversion using the canonical
2048-word English wordlist, plus mnemonic-to-seed (PBKDF2-HMAC-SHA512,
2048 iterations, 64-byte output).
Spec: <https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki>.

## Status

Implements §3 (entropy → words via SHA-256 checksum), §4 (reverse),
and §5 (PBKDF2 seed derivation). The English wordlist is the official
2048-entry list (SHA-256 `2f5eed53…3b24dbda`).

Validated against the canonical Trezor reference vectors
(`https://github.com/trezor/python-mnemonic/blob/master/vectors.json`)
in `entropy_test.mbt` and `bip39_test.mbt` — round-trip checks plus
seed-derivation checks at all five entropy lengths (128/160/192/224/256
bits).

Per BIP-39, NFKD normalization of non-ASCII passphrases is the caller's
responsibility; for the standard English-list ASCII case NFKD is the
identity, so input bytes pass through unchanged.

## Import

```
// In your moon.pkg:
import {
  "skmtkytr/ethbit/bip39" @bip39,
}
```

## Quick example

```moonbit
// Entropy → mnemonic (12 words for 128 bits).
let entropy : Bytes = b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
let mnemonic = @bip39.entropy_to_mnemonic(entropy).unwrap()
// "abandon abandon abandon abandon abandon abandon
//  abandon abandon abandon abandon abandon about"

// Round-trip.
let recovered = @bip39.mnemonic_to_entropy(mnemonic).unwrap()

// Mnemonic → 64-byte seed (BIP-39 §5).
let seed : Bytes = @bip39.mnemonic_to_seed(mnemonic, "TREZOR")
```

## API

| Symbol | Type | Description |
|---|---|---|
| `entropy_to_mnemonic` | `Bytes -> Result[String, EntropyError]` | encode 16/20/24/28/32-byte entropy as 12/15/18/21/24 English words |
| `mnemonic_to_entropy` | `String -> Result[Bytes, EntropyError]` | reverse, with checksum verification |
| `mnemonic_to_seed` | `(String, String) -> Bytes` | PBKDF2-HMAC-SHA512(mnemonic, "mnemonic"+passphrase, 2048, 64) |
| `EntropyError` | `suberror { InvalidEntropyLength, WrongWordCount, UnknownWord, InvalidChecksum, Empty }` | – |

## References

- BIP-39: <https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki>
- English wordlist: <https://github.com/bitcoin/bips/blob/master/bip-0039/english.txt>
- Trezor test vectors: <https://github.com/trezor/python-mnemonic/blob/master/vectors.json>
- RFC 8018 §5.2 (PBKDF2)
- Sibling packages: [`../sha256`](../sha256), [`../sha512`](../sha512),
  [`../bip32`](../bip32)
