// BIP-39 entropy <-> mnemonic conversion (BIP-0039 §3, §4).
// Spec: https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki
//
// Uses the official English wordlist embedded in `wordlist.mbt`.
// The checksum is the high-order ENT/32 bits of SHA-256(entropy).

///|
pub(all) suberror EntropyError {
  // Entropy length in bytes must be one of {16, 20, 24, 28, 32}.
  InvalidEntropyLength(Int)
  // Mnemonic word count must be one of {12, 15, 18, 21, 24}.
  WrongWordCount(Int)
  // Word not present in the English wordlist.
  UnknownWord(String)
  // Trailing checksum bits don't match SHA-256(entropy) prefix.
  InvalidChecksum
  // Empty mnemonic input.
  Empty
}

///|
pub impl Show for EntropyError with output(self, logger) {
  match self {
    InvalidEntropyLength(n) => {
      logger.write_string("InvalidEntropyLength(")
      logger.write_object(n)
      logger.write_char(')')
    }
    WrongWordCount(n) => {
      logger.write_string("WrongWordCount(")
      logger.write_object(n)
      logger.write_char(')')
    }
    UnknownWord(w) => {
      logger.write_string("UnknownWord(\"")
      logger.write_string(w)
      logger.write_string("\")")
    }
    InvalidChecksum => logger.write_string("InvalidChecksum")
    Empty => logger.write_string("Empty")
  }
}

///|
/// Encode entropy bytes into a BIP-39 English mnemonic.
///
/// `entropy` must be 16, 20, 24, 28, or 32 bytes (128/160/192/224/256 bits);
/// any other length yields `Err(InvalidEntropyLength)`.
pub fn entropy_to_mnemonic(entropy : Bytes) -> Result[String, EntropyError] {
  let ent_bytes = entropy.length()
  if ent_bytes != 16 &&
    ent_bytes != 20 &&
    ent_bytes != 24 &&
    ent_bytes != 28 &&
    ent_bytes != 32 {
    return Err(InvalidEntropyLength(ent_bytes))
  }
  let ent_bits = ent_bytes * 8
  let cs_bits = ent_bits / 32 // 4..8
  let total_bits = ent_bits + cs_bits // divisible by 11
  let wc = total_bits / 11
  // Combined bit buffer (one Int per bit, 0/1). Cheap and clear; sizes
  // here are <= 264 bits.
  let bits : Array[Int] = Array::make(total_bits, 0)
  for i = 0; i < ent_bytes; i = i + 1 {
    let byte = entropy[i].to_int()
    for j = 0; j < 8; j = j + 1 {
      bits[i * 8 + j] = (byte >> (7 - j)) & 1
    }
  }
  // Append checksum bits: high-order cs_bits of SHA-256(entropy).
  let digest = @sha256.sha256(entropy)
  for j = 0; j < cs_bits; j = j + 1 {
    let byte_idx = j / 8
    let bit_idx = j % 8
    bits[ent_bits + j] = (digest[byte_idx].to_int() >> (7 - bit_idx)) & 1
  }
  // Walk in 11-bit groups; look up each word.
  let words : Array[String] = Array::make(wc, "")
  for w = 0; w < wc; w = w + 1 {
    let mut idx = 0
    for k = 0; k < 11; k = k + 1 {
      idx = (idx << 1) | bits[w * 11 + k]
    }
    words[w] = english_wordlist[idx]
  }
  // Join with single spaces. We avoid Array::join to keep the dep
  // surface trivial; word counts are <= 24.
  let mut s = words[0]
  for w = 1; w < wc; w = w + 1 {
    s = s + " " + words[w]
  }
  Ok(s)
}

///|
/// Decode a BIP-39 English mnemonic back to its entropy bytes.
///
/// Multiple consecutive spaces are collapsed; leading/trailing spaces are
/// ignored. Word count must be one of {12, 15, 18, 21, 24}; every word must
/// appear in the English list; the trailing checksum bits must match.
pub fn mnemonic_to_entropy(mnemonic : String) -> Result[Bytes, EntropyError] {
  // Split on whitespace, collapsing runs.
  let words = split_words(mnemonic)
  let wc = words.length()
  if wc == 0 {
    return Err(Empty)
  }
  if wc != 12 && wc != 15 && wc != 18 && wc != 21 && wc != 24 {
    return Err(WrongWordCount(wc))
  }
  // Convert words to indices (linear scan: 2048 entries, list bounded).
  let indices : Array[Int] = Array::make(wc, 0)
  for i = 0; i < wc; i = i + 1 {
    match wordlist_index(words[i]) {
      Some(idx) => indices[i] = idx
      None => return Err(UnknownWord(words[i]))
    }
  }
  // Bit string of length wc * 11. ENT bits = WC * 11 - cs_bits, cs = WC*11/33.
  let total_bits = wc * 11
  let cs_bits = total_bits / 33
  let ent_bits = total_bits - cs_bits
  let ent_bytes = ent_bits / 8
  let bits : Array[Int] = Array::make(total_bits, 0)
  for i = 0; i < wc; i = i + 1 {
    let v = indices[i]
    for k = 0; k < 11; k = k + 1 {
      bits[i * 11 + k] = (v >> (10 - k)) & 1
    }
  }
  // Pack entropy bits into bytes, big-endian.
  let entropy_buf : Array[Byte] = Array::make(ent_bytes, b'\x00')
  for i = 0; i < ent_bytes; i = i + 1 {
    let mut b = 0
    for j = 0; j < 8; j = j + 1 {
      b = (b << 1) | bits[i * 8 + j]
    }
    entropy_buf[i] = b.to_byte()
  }
  let entropy = Bytes::from_array(entropy_buf[:])
  // Verify checksum.
  let digest = @sha256.sha256(entropy)
  for j = 0; j < cs_bits; j = j + 1 {
    let byte_idx = j / 8
    let bit_idx = j % 8
    let want = (digest[byte_idx].to_int() >> (7 - bit_idx)) & 1
    if bits[ent_bits + j] != want {
      return Err(InvalidChecksum)
    }
  }
  Ok(entropy)
}

///|
/// Split on ASCII spaces (0x20), collapsing runs and dropping leading/
/// trailing empties. We deliberately don't try to Unicode-fold whitespace
/// here; BIP-39 mnemonics are ASCII for the English list.
fn split_words(s : String) -> Array[String] {
  let chars = s.iter().to_array()
  let n = chars.length()
  let out : Array[String] = []
  let mut i = 0
  while i < n {
    // Skip spaces.
    while i < n && chars[i] == ' ' {
      i = i + 1
    }
    if i >= n {
      break
    }
    let start = i
    while i < n && chars[i] != ' ' {
      i = i + 1
    }
    // Build word from chars[start..i].
    let mut w = ""
    for k = start; k < i; k = k + 1 {
      w = w + chars[k].to_string()
    }
    out.push(w)
  }
  out
}

///|
/// Linear lookup in the English wordlist. Returns the 0..2047 index, or
/// None if the word is absent. The list is sorted but using binary search
/// would only buy ~5x on 2048 entries and add complexity; linear is fine
/// at the call frequency expected here (<= 24 lookups per mnemonic).
fn wordlist_index(word : String) -> Int? {
  for i = 0; i < english_wordlist.length(); i = i + 1 {
    if english_wordlist[i] == word {
      return Some(i)
    }
  }
  None
}
