# ws

WebSocket protocol layer (RFC 6455): frame parser/builder and opening-
handshake helpers. **No socket I/O.** The caller drives an actual TCP/TLS
transport and pumps bytes through these encoders/decoders.

## Status

Implements the wire-format codec for §5.2 frames (FIN, opcode, mask,
extended payload length 16/64) and the §4 opening handshake (request build
+ response validation, including `Sec-WebSocket-Accept`).
Validated against the RFC 6455 §1.3 handshake example
(`dGhlIHNhbXBsZSBub25jZQ==` →
`s3pPLMBiTxaQ9kYGzzhZRbK+xOo=`) plus assorted small-frame and mask
round-trip tests in `frame_test.mbt` / `handshake_test.mbt`.

Constraints intentionally preserved by the parser:

- RSV1/2/3 set with no negotiated extension → `ReservedBitsSet`
- unknown opcode → `UnknownOpcode(n)`
- control frame (Close/Ping/Pong) > 125 bytes → `ControlFrameTooLarge`
- control frame with FIN=0 → `ControlFrameNotFin`
- truncated input → `Truncated(need_more)`

The 16-byte client key and 4-byte mask must be supplied by the caller from
a CSPRNG; this package never generates randomness.

## Import

```
// In your moon.pkg:
import {
  "skmtkytr/ethbit/ws" @ws,
}
```

## Quick example

```moonbit
// Build the opening handshake and send it (caller does the I/O).
let req : @ws.HandshakeRequest = {
  host: "echo.example.com",
  path: "/ws",
  origin: None,
  protocols: [],
  key: csprng_16_bytes,
}
let http_request : String = @ws.build_handshake_request(req)
// ...write http_request to socket, read response head into `resp`...
match @ws.validate_handshake_response(resp, req.key) {
  Ok(()) => ()
  Err(e) => abort(e.to_string())
}

// Send a text frame (client → server, must be masked).
let frame : @ws.Frame = { fin: true, opcode: Text, payload: b"hello" }
let wire : Bytes = @ws.build_client_frame(frame, csprng_4_bytes)

// Parse one frame from a buffer.
match @ws.parse_frame(buffer) {
  Ok((f, n)) => { /* consumed n bytes; f.payload is unmasked */ }
  Err(Truncated(more)) => { /* need at least `more` more bytes */ }
  Err(e) => abort(e.to_string())
}
```

## API

### Frame layer

| Symbol | Type | Description |
|---|---|---|
| `Opcode` | `enum { Continuation, Text, Binary, Close, Ping, Pong }` | – |
| `Frame` | `struct { fin, opcode, payload }` | unmasked payload |
| `FrameError` | `suberror { Truncated, ReservedBitsSet, UnknownOpcode, ControlFrameTooLarge, ControlFrameNotFin }` | – |
| `parse_frame` | `Bytes -> Result[(Frame, Int), FrameError]` | returns frame + bytes consumed |
| `build_client_frame` | `(Frame, Bytes) -> Bytes` | masked (4-byte mask required) |
| `build_server_frame` | `Frame -> Bytes` | unmasked (per RFC 6455 §5.3) |

### Handshake

| Symbol | Type | Description |
|---|---|---|
| `HandshakeRequest` | `struct { host, path, origin, protocols, key }` | input fields |
| `HandshakeError` | `suberror { NotHttp101, MissingUpgrade, MissingConnectionUpgrade, WrongAccept, Malformed }` | – |
| `build_handshake_request` | `HandshakeRequest -> String` | full HTTP/1.1 request |
| `expected_accept` | `Bytes -> String` | base64(sha1(base64(key) ++ GUID)) |
| `validate_handshake_response` | `(String, Bytes) -> Result[Unit, HandshakeError]` | check status + headers + Accept |

## References

- RFC 6455 (The WebSocket Protocol)
- Sibling packages: [`../rpc`](../rpc) (JSON-RPC 2.0 envelope encoder
  designed to ride over `ws` for `eth_subscribe`)
