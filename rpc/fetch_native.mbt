// Native HTTP transport for the rpc package, via libcurl.
//
// Available only when compiled to the `native` target. Uses libcurl
// synchronously: fetch_post blocks until the HTTP exchange completes,
// then dispatches the same callback API the JS variant uses.
//
// Build requirement: libcurl headers + library on the host (`libcurl-dev`
// on Debian/Ubuntu, `libcurl-devel` on Fedora; macOS and Windows ship
// libcurl). Linking is configured in moon.pkg.

#borrow(url_utf8, body)
extern "c" fn moonbit_curl_post(url_utf8 : Bytes, body : Bytes) -> Int = "moonbit_curl_post"

extern "c" fn moonbit_curl_last_response() -> Bytes = "moonbit_curl_last_response"

extern "c" fn moonbit_curl_last_error_utf8() -> Bytes = "moonbit_curl_last_error_utf8"

///|
fn bytes_to_utf8_string(b : Bytes) -> String {
  @utf8.decode_lossy(b[:])
}

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
/// Synchronous POST. Blocks until the HTTP exchange completes, then
/// invokes either `on_ok(response_body)` on a 2xx, or `on_err(message)`
/// on any other status / network failure.
///
/// Same shape as the js-target variant — both fire the callbacks before
/// any async observer would be able to interleave.
pub fn fetch_post(
  url : String,
  body : String,
  on_ok : (String) -> Unit,
  on_err : (String) -> Unit,
) -> Unit {
  let url_bytes = @utf8.encode(url[:])
  let body_bytes = @utf8.encode(body[:])
  let rc = moonbit_curl_post(url_bytes, body_bytes)
  if rc == 0 {
    on_ok(bytes_to_utf8_string(moonbit_curl_last_response()))
  } else {
    on_err(bytes_to_utf8_string(moonbit_curl_last_error_utf8()))
  }
}

///|
/// Convenience: encode the Request, POST, then decode the Response.
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
  }, fn(msg) { on_err(NetworkError(msg)) })
}
