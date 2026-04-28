// JS-target HTTP transport for the rpc package.
//
// Available only when compiled to the `js` target. Wraps the host's
// `fetch` global (browser native, Node 18+, Bun, Deno).
//
// API is callback-based: MoonBit calls into JS, JS performs fetch, then
// invokes the on_ok / on_err callback when the Promise settles. This
// avoids requiring MoonBit-level async, which is not yet uniformly
// available on the JS backend.

///|
pub(all) suberror FetchError {
  NetworkError(String)
  HttpStatus(Int, String)
}

///|
pub impl Show for FetchError with output(self, logger) {
  match self {
    NetworkError(msg) => {
      logger.write_string("NetworkError(\"")
      logger.write_string(msg)
      logger.write_string("\")")
    }
    HttpStatus(code, text) => {
      logger.write_string("HttpStatus(")
      logger.write_object(code)
      logger.write_string(", \"")
      logger.write_string(text)
      logger.write_string("\")")
    }
  }
}

///|
/// POST `body` to `url` with Content-Type: application/json. Calls
/// `on_ok(response_body)` on a 2xx, `on_err(message)` on any non-2xx
/// or network failure.
///
/// This function returns to the MoonBit caller IMMEDIATELY; the
/// callbacks fire later when the Promise settles. Standard JavaScript
/// async semantics — the caller must not assume a result is available
/// synchronously after this returns.
pub extern "js" fn fetch_post(
  url : String,
  body : String,
  on_ok : (String) -> Unit,
  on_err : (String) -> Unit,
) -> Unit =
  #| (url, body, on_ok, on_err) => {
  #|   fetch(url, {
  #|     method: "POST",
  #|     headers: { "Content-Type": "application/json" },
  #|     body: body,
  #|   })
  #|     .then(r => {
  #|       if (!r.ok) {
  #|         on_err("HTTP " + r.status + " " + (r.statusText || ""));
  #|         return null;
  #|       }
  #|       return r.text();
  #|     })
  #|     .then(text => { if (text !== null) on_ok(text); })
  #|     .catch(e => on_err(String((e && e.message) || e)));
  #| }

///|
/// Convenience: encode the Request, fetch, then decode the Response.
/// Calls `on_ok(response)` with the parsed Response on success, or
/// `on_err(error)` on transport / decode failure.
pub fn fetch_request(
  url : String,
  req : Request,
  on_ok : (Response) -> Unit,
  on_err : (FetchError) -> Unit,
) -> Unit {
  let body = encode_request(req)
  fetch_post(url, body, fn(text) {
    match decode_response(text) {
      Some(resp) => on_ok(resp)
      None => on_err(NetworkError("malformed JSON-RPC response: " + text))
    }
  }, fn(msg) {
    on_err(NetworkError(msg))
  })
}
