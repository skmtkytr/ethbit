// Constructors for the `net_`, `web3_` and `txpool_` namespaces.
//
//   - `net_*`   — peer/network status. Universal across geth/erigon/reth.
//   - `web3_*`  — legacy utility namespace; still exposed by every major
//                 client. `web3_clientVersion` returns a free-form string,
//                 `web3_sha3` returns the keccak-256 of the input bytes.
//   - `txpool_*`— transaction-pool inspection. Geth/erigon expose the full
//                 set; reth implements a compatible subset.
//
// Every constructor returns a `Request` with `id = 0` as a placeholder;
// callers should set their own request id before passing the value to
// `encode_request`.

// ---------- net_ ----------

///|
/// `net_listening()` — `true` if the node is actively listening for peers.
pub fn net_listening() -> Request {
  { id: 0, method: "net_listening", params: [] }
}

///|
/// `net_peerCount()` — current peer count, as a JSON-RPC quantity hex string.
pub fn net_peer_count() -> Request {
  { id: 0, method: "net_peerCount", params: [] }
}

///|
/// `net_version()` — chain network id as a decimal string (e.g. `"1"` for
/// mainnet). Distinct from `eth_chainId`, which returns a hex quantity.
pub fn net_version() -> Request {
  { id: 0, method: "net_version", params: [] }
}

// ---------- web3_ ----------

///|
/// `web3_clientVersion()` — free-form node software version string
/// (e.g. `"Geth/v1.13.14-stable/.../go1.22.0"`).
pub fn web3_client_version() -> Request {
  { id: 0, method: "web3_clientVersion", params: [] }
}

///|
/// `web3_sha3(data)` — keccak-256 hash of the given bytes.
/// Despite the method name (`sha3` is the original SHA-3 family), the
/// implementation is keccak-256 — historical Ethereum quirk preserved by
/// every client.
pub fn web3_sha3(data : Bytes) -> Request {
  { id: 0, method: "web3_sha3", params: [Json::string(data_from_bytes(data))] }
}

// ---------- txpool_ ----------

///|
/// `txpool_content()` — full pending+queued tx pool dump.
pub fn txpool_content() -> Request {
  { id: 0, method: "txpool_content", params: [] }
}

///|
/// `txpool_contentFrom(address)` — pending+queued txs whose `from` is the
/// given address.
pub fn txpool_content_from(address : Bytes) -> Request {
  {
    id: 0,
    method: "txpool_contentFrom",
    params: [Json::string(data_from_bytes(address))],
  }
}

///|
/// `txpool_inspect()` — concise summary of pending+queued txs (one line each).
pub fn txpool_inspect() -> Request {
  { id: 0, method: "txpool_inspect", params: [] }
}

///|
/// `txpool_status()` — counts of pending and queued txs.
pub fn txpool_status() -> Request {
  { id: 0, method: "txpool_status", params: [] }
}
