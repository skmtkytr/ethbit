// WebSocket subscription support for the JSON-RPC `eth_*` namespace.
// Spec: https://geth.ethereum.org/docs/interacting-with-geth/rpc/pubsub
//
// This file provides only the JSON encoder/decoder pieces. The package is
// transport-free — the caller pumps the resulting strings into whatever
// WebSocket client they have (browser `WebSocket`, the `ws` npm package,
// a native socket library, etc.) and feeds incoming frames back to
// `parse_notification`.
//
// Two request shapes are supported:
//   - `eth_subscribe` with a kind discriminator (and an optional log filter)
//   - `eth_unsubscribe` with a server-assigned subscription handle
//
// Server-pushed notifications use a method (no `id`) envelope:
//   {"jsonrpc":"2.0","method":"eth_subscription",
//    "params":{"subscription":"0xabc","result":<payload>}}
// `parse_notification` decodes that envelope. The inner `result` payload
// is shape-dependent (block header, log entry, tx hash string, ...) so it
// is returned as a raw `Json` value — the caller decodes it per kind.

///|
/// Subscription kind discriminator passed to `eth_subscribe`.
/// Mirrors the four documented topics geth/erigon/reth accept.
pub(all) enum SubscriptionKind {
  NewHeads
  Logs(LogFilter)
  NewPendingTransactions
  Syncing
}

///|
/// Server-pushed notification frame for `eth_subscription`.
///
/// `subscription` is the server-assigned handle (typically a 16-byte value,
/// but format-agnostic — whatever bytes the hex string decodes to).
/// `result` is the raw inner payload; callers decode it per the kind they
/// originally subscribed to.
pub(all) struct Notification {
  subscription : Bytes
  result : Json
}

///|
pub impl Eq for Notification with equal(a, b) {
  a.subscription == b.subscription && a.result == b.result
}

///|
pub impl Show for Notification with output(self, logger) {
  logger.write_string("Notification{ subscription: ")
  logger.write_object(@hex.encode(self.subscription))
  logger.write_string(", result: ")
  logger.write_object(self.result)
  logger.write_string(" }")
}

// ---------- request constructors ----------

///|
/// `eth_subscribe(kind)`. `params` is shaped per the kind:
///   - `NewHeads`               -> `["newHeads"]`
///   - `Logs(filter)`           -> `["logs", <log_filter_to_json>]`
///   - `NewPendingTransactions` -> `["newPendingTransactions"]`
///   - `Syncing`                -> `["syncing"]`
pub fn eth_subscribe(kind : SubscriptionKind) -> Request {
  let params : Array[Json] = match kind {
    NewHeads => [Json::string("newHeads")]
    Logs(filter) => [Json::string("logs"), log_filter_to_json(filter)]
    NewPendingTransactions => [Json::string("newPendingTransactions")]
    Syncing => [Json::string("syncing")]
  }
  { id: 0, method: "eth_subscribe", params }
}

///|
/// `eth_unsubscribe(id)`. `id` is the bytes of the subscription handle
/// returned by a prior `eth_subscribe` response. Format-agnostic: whatever
/// bytes the user passes are emitted as `"0x"`-prefixed lowercase hex.
pub fn eth_unsubscribe(id : Bytes) -> Request {
  {
    id: 0,
    method: "eth_unsubscribe",
    params: [Json::string(@hex.encode(id))],
  }
}

// ---------- notification parser ----------

///|
/// Parse a server-pushed `eth_subscription` notification frame.
/// Returns `None` on:
///   - malformed JSON
///   - non-object root
///   - missing or non-`"2.0"` `jsonrpc`
///   - `method` absent or not `"eth_subscription"` (this is how we
///     distinguish a notification from a regular response, which has
///     `id` + `result`/`error` instead)
///   - `params` absent or not an object
///   - `params.subscription` absent or not a `"0x"`-hex string
///   - `params.result` absent
///   - subscription hex with odd-length body (rejected by `@hex.decode`)
pub fn parse_notification(body : String) -> Notification? {
  let parsed = try? @json.parse(body)
  let root = match parsed {
    Ok(j) => j
    Err(_) => return None
  }
  let obj = match root {
    Object(m) => m
    _ => return None
  }
  // jsonrpc must be present and equal to "2.0".
  match obj.get("jsonrpc") {
    Some(String("2.0")) => ()
    _ => return None
  }
  // method must be "eth_subscription". Any other value (or absence) means
  // this is not a notification frame.
  match obj.get("method") {
    Some(String("eth_subscription")) => ()
    _ => return None
  }
  let params = match obj.get("params") {
    Some(Object(m)) => m
    _ => return None
  }
  let sub_bytes = match params.get("subscription") {
    Some(String(s)) =>
      match @hex.decode(s) {
        Ok(b) => b
        Err(_) => return None
      }
    _ => return None
  }
  let result = match params.get("result") {
    Some(j) => j
    None => return None
  }
  Some({ subscription: sub_bytes, result })
}
