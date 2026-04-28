// Ethereum transaction encoding for legacy (with EIP-155) and EIP-1559 (type 2).
// Spec: Yellow Paper, EIP-155, EIP-2718, EIP-1559, EIP-2930.
//
// All numeric fields are passed as big-endian Bytes with no leading zeros
// (matching RLP integer convention; zero is the empty Bytes b""). The caller
// is responsible for normalizing inputs.
//
// `to` is either an exact 20-byte address or empty Bytes (= contract creation).

///|
pub(all) struct Signature {
  v : Bytes // legacy: 27/28 or 35+2*chain+recid; typed (1559): yParity 0/1
  r : Bytes // 32 bytes
  s : Bytes // 32 bytes
}

///|
pub(all) struct AccessListEntry {
  address : Bytes // 20 bytes
  storage_keys : Array[Bytes] // 32 bytes each
}

///|
pub(all) struct TxLegacy {
  nonce : Bytes
  gas_price : Bytes
  gas_limit : Bytes
  to : Bytes
  value : Bytes
  data : Bytes
}

///|
pub(all) struct Tx1559 {
  chain_id : Bytes
  nonce : Bytes
  max_priority_fee_per_gas : Bytes
  max_fee_per_gas : Bytes
  gas_limit : Bytes
  to : Bytes
  value : Bytes
  data : Bytes
  access_list : Array[AccessListEntry]
}

///|
pub(all) struct Tx4844 {
  chain_id : Bytes
  nonce : Bytes
  max_priority_fee_per_gas : Bytes
  max_fee_per_gas : Bytes
  gas_limit : Bytes
  to : Bytes // exactly 20 bytes; not validated here
  value : Bytes
  data : Bytes
  access_list : Array[AccessListEntry]
  max_fee_per_blob_gas : Bytes
  blob_versioned_hashes : Array[Bytes]
}

// ---------- legacy (with EIP-155) ----------

///|
/// EIP-155 unsigned encoding: rlp([nonce, gasPrice, gasLimit, to, value, data, chainId, 0, 0]).
pub fn encode_unsigned_legacy(tx : TxLegacy, chain_id : Bytes) -> Bytes {
  @rlp.encode(
    @rlp.RlpList([
      @rlp.RlpString(tx.nonce),
      @rlp.RlpString(tx.gas_price),
      @rlp.RlpString(tx.gas_limit),
      @rlp.RlpString(tx.to),
      @rlp.RlpString(tx.value),
      @rlp.RlpString(tx.data),
      @rlp.RlpString(chain_id),
      @rlp.RlpString(b""),
      @rlp.RlpString(b""),
    ]),
  )
}

///|
/// Signed legacy encoding: rlp([nonce, gasPrice, gasLimit, to, value, data, v, r, s]).
pub fn encode_signed_legacy(tx : TxLegacy, sig : Signature) -> Bytes {
  @rlp.encode(
    @rlp.RlpList([
      @rlp.RlpString(tx.nonce),
      @rlp.RlpString(tx.gas_price),
      @rlp.RlpString(tx.gas_limit),
      @rlp.RlpString(tx.to),
      @rlp.RlpString(tx.value),
      @rlp.RlpString(tx.data),
      @rlp.RlpString(sig.v),
      @rlp.RlpString(sig.r),
      @rlp.RlpString(sig.s),
    ]),
  )
}

///|
pub fn hash_unsigned_legacy(tx : TxLegacy, chain_id : Bytes) -> Bytes {
  @keccak.keccak256(encode_unsigned_legacy(tx, chain_id))
}

///|
pub fn hash_signed_legacy(tx : TxLegacy, sig : Signature) -> Bytes {
  @keccak.keccak256(encode_signed_legacy(tx, sig))
}

// ---------- EIP-1559 (type 2) ----------

///|
fn encode_access_list(entries : Array[AccessListEntry]) -> @rlp.RlpValue {
  let items : Array[@rlp.RlpValue] = Array::make(entries.length(), @rlp.RlpList([]))
  for i = 0; i < entries.length(); i = i + 1 {
    let e = entries[i]
    let keys : Array[@rlp.RlpValue] = Array::make(e.storage_keys.length(), @rlp.RlpString(b""))
    for j = 0; j < e.storage_keys.length(); j = j + 1 {
      keys[j] = @rlp.RlpString(e.storage_keys[j])
    }
    items[i] = @rlp.RlpList([
      @rlp.RlpString(e.address),
      @rlp.RlpList(keys),
    ])
  }
  @rlp.RlpList(items)
}

///|
/// EIP-1559 unsigned encoding: 0x02 || rlp([chainId, nonce, maxPriorityFeePerGas,
///   maxFeePerGas, gasLimit, to, value, data, accessList]).
pub fn encode_unsigned_1559(tx : Tx1559) -> Bytes {
  let body = @rlp.encode(
    @rlp.RlpList([
      @rlp.RlpString(tx.chain_id),
      @rlp.RlpString(tx.nonce),
      @rlp.RlpString(tx.max_priority_fee_per_gas),
      @rlp.RlpString(tx.max_fee_per_gas),
      @rlp.RlpString(tx.gas_limit),
      @rlp.RlpString(tx.to),
      @rlp.RlpString(tx.value),
      @rlp.RlpString(tx.data),
      encode_access_list(tx.access_list),
    ]),
  )
  @bytesx.concat([b"\x02", body])
}

///|
/// EIP-1559 signed encoding: 0x02 || rlp([chainId, nonce, maxPriorityFeePerGas,
///   maxFeePerGas, gasLimit, to, value, data, accessList, yParity, r, s]).
pub fn encode_signed_1559(tx : Tx1559, sig : Signature) -> Bytes {
  let body = @rlp.encode(
    @rlp.RlpList([
      @rlp.RlpString(tx.chain_id),
      @rlp.RlpString(tx.nonce),
      @rlp.RlpString(tx.max_priority_fee_per_gas),
      @rlp.RlpString(tx.max_fee_per_gas),
      @rlp.RlpString(tx.gas_limit),
      @rlp.RlpString(tx.to),
      @rlp.RlpString(tx.value),
      @rlp.RlpString(tx.data),
      encode_access_list(tx.access_list),
      @rlp.RlpString(sig.v),
      @rlp.RlpString(sig.r),
      @rlp.RlpString(sig.s),
    ]),
  )
  @bytesx.concat([b"\x02", body])
}

///|
pub fn hash_unsigned_1559(tx : Tx1559) -> Bytes {
  @keccak.keccak256(encode_unsigned_1559(tx))
}

///|
pub fn hash_signed_1559(tx : Tx1559, sig : Signature) -> Bytes {
  @keccak.keccak256(encode_signed_1559(tx, sig))
}

// ---------- EIP-4844 (type 3, blob) ----------

///|
fn encode_blob_versioned_hashes(hashes : Array[Bytes]) -> @rlp.RlpValue {
  let items : Array[@rlp.RlpValue] = Array::make(hashes.length(), @rlp.RlpString(b""))
  for i = 0; i < hashes.length(); i = i + 1 {
    items[i] = @rlp.RlpString(hashes[i])
  }
  @rlp.RlpList(items)
}

///|
/// EIP-4844 unsigned encoding: 0x03 || rlp([chainId, nonce, maxPriorityFeePerGas,
///   maxFeePerGas, gasLimit, to, value, data, accessList, maxFeePerBlobGas,
///   blobVersionedHashes]).
pub fn encode_unsigned_4844(tx : Tx4844) -> Bytes {
  let body = @rlp.encode(
    @rlp.RlpList([
      @rlp.RlpString(tx.chain_id),
      @rlp.RlpString(tx.nonce),
      @rlp.RlpString(tx.max_priority_fee_per_gas),
      @rlp.RlpString(tx.max_fee_per_gas),
      @rlp.RlpString(tx.gas_limit),
      @rlp.RlpString(tx.to),
      @rlp.RlpString(tx.value),
      @rlp.RlpString(tx.data),
      encode_access_list(tx.access_list),
      @rlp.RlpString(tx.max_fee_per_blob_gas),
      encode_blob_versioned_hashes(tx.blob_versioned_hashes),
    ]),
  )
  @bytesx.concat([b"\x03", body])
}

///|
/// EIP-4844 signed encoding: 0x03 || rlp([chainId, nonce, maxPriorityFeePerGas,
///   maxFeePerGas, gasLimit, to, value, data, accessList, maxFeePerBlobGas,
///   blobVersionedHashes, yParity, r, s]).
pub fn encode_signed_4844(tx : Tx4844, sig : Signature) -> Bytes {
  let body = @rlp.encode(
    @rlp.RlpList([
      @rlp.RlpString(tx.chain_id),
      @rlp.RlpString(tx.nonce),
      @rlp.RlpString(tx.max_priority_fee_per_gas),
      @rlp.RlpString(tx.max_fee_per_gas),
      @rlp.RlpString(tx.gas_limit),
      @rlp.RlpString(tx.to),
      @rlp.RlpString(tx.value),
      @rlp.RlpString(tx.data),
      encode_access_list(tx.access_list),
      @rlp.RlpString(tx.max_fee_per_blob_gas),
      encode_blob_versioned_hashes(tx.blob_versioned_hashes),
      @rlp.RlpString(sig.v),
      @rlp.RlpString(sig.r),
      @rlp.RlpString(sig.s),
    ]),
  )
  @bytesx.concat([b"\x03", body])
}

///|
pub fn hash_unsigned_4844(tx : Tx4844) -> Bytes {
  @keccak.keccak256(encode_unsigned_4844(tx))
}

///|
pub fn hash_signed_4844(tx : Tx4844, sig : Signature) -> Bytes {
  @keccak.keccak256(encode_signed_4844(tx, sig))
}
