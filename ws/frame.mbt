// WebSocket frame parser and builder (RFC 6455 §5.2).
//
// This package provides only the wire-format codec — no socket I/O. The
// caller drives an actual TCP/TLS transport (browser `WebSocket`, the `ws`
// npm package, a native socket library, ...) and pumps bytes through these
// encoders/decoders. This matches the project's transport-free style: the
// `rpc` package is an HTTP/JSON encoder, the `ws` subscription is a JSON
// envelope encoder, and this is the WebSocket frame layer.
//
// Frame format (RFC 6455 §5.2):
//
//  0                   1                   2                   3
//  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
// +-+-+-+-+-------+-+-------------+-------------------------------+
// |F|R|R|R| opcode|M| Payload len |    Extended payload length    |
// |I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
// |N|V|V|V|       |S|             |   (if payload len==126/127)   |
// | |1|2|3|       |K|             |                               |
// +-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
// |     Extended payload length continued, if payload len == 127  |
// + - - - - - - - - - - - - - - - +-------------------------------+
// |                               |Masking-key, if MASK set to 1  |
// +-------------------------------+-------------------------------+
// | Masking-key (continued)       |          Payload Data         |
// +-------------------------------- - - - - - - - - - - - - - - - +
// :                     Payload Data continued ...                :
// + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
// |                     Payload Data continued ...                |
// +---------------------------------------------------------------+

///|
/// WebSocket opcode (RFC 6455 §5.2). Only the 6 defined values are
/// represented; reserved values (0x3-0x7 non-control, 0xB-0xF control) are
/// rejected by the parser as `UnknownOpcode`.
pub(all) enum Opcode {
  Continuation // 0x0
  Text // 0x1
  Binary // 0x2
  Close // 0x8
  Ping // 0x9
  Pong // 0xA
} derive(Eq)

///|
pub impl Show for Opcode with output(self, logger) {
  match self {
    Continuation => logger.write_string("Continuation")
    Text => logger.write_string("Text")
    Binary => logger.write_string("Binary")
    Close => logger.write_string("Close")
    Ping => logger.write_string("Ping")
    Pong => logger.write_string("Pong")
  }
}

///|
/// A parsed or to-be-built WebSocket frame.
///
/// `payload` is the unmasked application payload. The wire-level mask is
/// handled by `build_client_frame` (applies it on the way out) and
/// `parse_frame` (strips it on the way in). RSV1/2/3 are not exposed —
/// extensions are not supported and reserved bits being set causes parse to
/// reject with `ReservedBitsSet`.
pub(all) struct Frame {
  fin : Bool
  opcode : Opcode
  payload : Bytes
} derive(Eq)

///|
pub impl Show for Frame with output(self, logger) {
  logger.write_string("Frame{ fin: ")
  logger.write_object(self.fin)
  logger.write_string(", opcode: ")
  logger.write_object(self.opcode)
  logger.write_string(", payload: ")
  logger.write_object(self.payload)
  logger.write_string(" }")
}

///|
/// Parse-time errors. `Truncated(n)` means the input was a valid prefix of
/// a frame but more bytes are needed; `n` is a lower bound on how many more
/// bytes the caller must read before retrying.
pub(all) suberror FrameError {
  Truncated(Int)
  ReservedBitsSet
  UnknownOpcode(Int)
  ControlFrameTooLarge(Int) // control frames must be ≤ 125 bytes
  ControlFrameNotFin // control frames must have FIN=1
} derive(Eq)

///|
pub impl Show for FrameError with output(self, logger) {
  match self {
    Truncated(n) => {
      logger.write_string("Truncated(")
      logger.write_object(n)
      logger.write_char(')')
    }
    ReservedBitsSet => logger.write_string("ReservedBitsSet")
    UnknownOpcode(n) => {
      logger.write_string("UnknownOpcode(")
      logger.write_object(n)
      logger.write_char(')')
    }
    ControlFrameTooLarge(n) => {
      logger.write_string("ControlFrameTooLarge(")
      logger.write_object(n)
      logger.write_char(')')
    }
    ControlFrameNotFin => logger.write_string("ControlFrameNotFin")
  }
}

fn opcode_value(op : Opcode) -> Int {
  match op {
    Continuation => 0x0
    Text => 0x1
    Binary => 0x2
    Close => 0x8
    Ping => 0x9
    Pong => 0xA
  }
}

fn opcode_from_int(n : Int) -> Opcode? {
  match n {
    0x0 => Some(Continuation)
    0x1 => Some(Text)
    0x2 => Some(Binary)
    0x8 => Some(Close)
    0x9 => Some(Ping)
    0xA => Some(Pong)
    _ => None
  }
}

fn is_control_opcode(op : Opcode) -> Bool {
  match op {
    Close | Ping | Pong => true
    _ => false
  }
}

///|
/// Parse one frame from the start of `bytes`. On success returns the frame
/// and the number of bytes consumed; the caller advances past that.
///
/// Errors:
///   - `Truncated(n)` — input is a valid prefix; need at least `n` more
///     bytes (lower bound). Caller buffers more and retries.
///   - `ReservedBitsSet` — RSV1/2/3 set with no negotiated extension.
///   - `UnknownOpcode(n)` — opcode is not one of {0,1,2,8,9,A}.
///   - `ControlFrameTooLarge(n)` — Close/Ping/Pong with payload > 125.
///   - `ControlFrameNotFin` — control frame with FIN=0 (RFC 6455 §5.5).
pub fn parse_frame(bytes : Bytes) -> Result[(Frame, Int), FrameError] {
  let total = bytes.length()
  if total < 2 {
    return Err(Truncated(2 - total))
  }
  let b0 = bytes[0].to_int()
  let b1 = bytes[1].to_int()
  let fin = (b0 & 0x80) != 0
  let rsv = b0 & 0x70
  if rsv != 0 {
    return Err(ReservedBitsSet)
  }
  let opcode_raw = b0 & 0x0F
  let opcode = match opcode_from_int(opcode_raw) {
    Some(op) => op
    None => return Err(UnknownOpcode(opcode_raw))
  }
  let masked = (b1 & 0x80) != 0
  let len7 = b1 & 0x7F
  let mut header_len = 2
  let payload_len : Int = if len7 < 126 {
    len7
  } else if len7 == 126 {
    header_len = header_len + 2
    if total < header_len {
      return Err(Truncated(header_len - total))
    }
    (bytes[2].to_int() << 8) | bytes[3].to_int()
  } else {
    // len7 == 127: 8-byte big-endian.
    header_len = header_len + 8
    if total < header_len {
      return Err(Truncated(header_len - total))
    }
    let mut acc : UInt64 = 0UL
    for i = 0; i < 8; i = i + 1 {
      acc = (acc << 8) | bytes[2 + i].to_uint64()
    }
    // RFC says the high bit must be 0; we don't enforce that strictly here
    // (the spec language is "MUST be 0", but production servers rarely test
    // the boundary). We do clamp practically: MoonBit's Int is 32-bit, so a
    // payload >= 2^31 cannot be addressed anyway. Treat overflow as
    // truncation-equivalent — the caller can't have buffered that much.
    if acc > 0x7FFFFFFFUL {
      return Err(Truncated(0x7FFFFFFF))
    }
    acc.to_int()
  }
  // Control frame validation: per RFC 6455 §5.5, control frames MUST have
  // payload length <= 125 and MUST NOT be fragmented (FIN=1).
  if is_control_opcode(opcode) {
    if payload_len > 125 {
      return Err(ControlFrameTooLarge(payload_len))
    }
    if !fin {
      return Err(ControlFrameNotFin)
    }
  }
  let mask_len = if masked { 4 } else { 0 }
  let need = header_len + mask_len + payload_len
  if total < need {
    return Err(Truncated(need - total))
  }
  let mask : FixedArray[Byte] = FixedArray::make(4, b'\x00')
  if masked {
    for i = 0; i < 4; i = i + 1 {
      mask[i] = bytes[header_len + i]
    }
  }
  let payload_offset = header_len + mask_len
  let payload : Array[Byte] = Array::make(payload_len, b'\x00')
  for i = 0; i < payload_len; i = i + 1 {
    let raw = bytes[payload_offset + i]
    payload[i] = if masked {
      (raw.to_int() ^ mask[i % 4].to_int()).to_byte()
    } else {
      raw
    }
  }
  Ok((
    { fin, opcode, payload: Bytes::from_array(payload[:]) },
    need,
  ))
}

fn build_header(
  frame : Frame,
  masked : Bool,
  mask : FixedArray[Byte],
) -> Array[Byte] {
  let n = frame.payload.length()
  let mut header_len = 2
  if n >= 126 && n <= 0xFFFF {
    header_len = header_len + 2
  } else if n > 0xFFFF {
    header_len = header_len + 8
  }
  let mask_len = if masked { 4 } else { 0 }
  let header : Array[Byte] = Array::make(header_len + mask_len, b'\x00')
  let fin_bit = if frame.fin { 0x80 } else { 0x00 }
  header[0] = (fin_bit | opcode_value(frame.opcode)).to_byte()
  let mask_bit = if masked { 0x80 } else { 0x00 }
  if n < 126 {
    header[1] = (mask_bit | n).to_byte()
  } else if n <= 0xFFFF {
    header[1] = (mask_bit | 126).to_byte()
    header[2] = ((n >> 8) & 0xFF).to_byte()
    header[3] = (n & 0xFF).to_byte()
  } else {
    header[1] = (mask_bit | 127).to_byte()
    let n64 : UInt64 = n.to_uint64()
    for i = 0; i < 8; i = i + 1 {
      let shift = (7 - i) * 8
      header[2 + i] = ((n64 >> shift) & 0xFFUL).to_byte()
    }
  }
  if masked {
    for i = 0; i < 4; i = i + 1 {
      header[header_len + i] = mask[i]
    }
  }
  header
}

///|
/// Build a client→server frame. RFC 6455 §5.3 requires that all client
/// frames be masked with a 4-byte mask the client picks freshly per frame
/// (typically from a CSPRNG). The caller supplies the mask bytes.
///
/// Aborts if `mask` is not exactly 4 bytes — that's a programmer error, not
/// a runtime condition we want to thread through a Result.
pub fn build_client_frame(frame : Frame, mask : Bytes) -> Bytes {
  if mask.length() != 4 {
    abort("build_client_frame: mask must be exactly 4 bytes")
  }
  let mask_arr : FixedArray[Byte] = FixedArray::make(4, b'\x00')
  for i = 0; i < 4; i = i + 1 {
    mask_arr[i] = mask[i]
  }
  let header = build_header(frame, true, mask_arr)
  let n = frame.payload.length()
  let masked_payload : Array[Byte] = Array::make(n, b'\x00')
  for i = 0; i < n; i = i + 1 {
    masked_payload[i] = (frame.payload[i].to_int() ^ mask_arr[i % 4].to_int()).to_byte()
  }
  let total = header.length() + n
  let out : Array[Byte] = Array::make(total, b'\x00')
  for i = 0; i < header.length(); i = i + 1 {
    out[i] = header[i]
  }
  for i = 0; i < n; i = i + 1 {
    out[header.length() + i] = masked_payload[i]
  }
  Bytes::from_array(out[:])
}

///|
/// Build a server→client frame. RFC 6455 §5.3 says servers MUST NOT mask
/// frames they send to a client.
pub fn build_server_frame(frame : Frame) -> Bytes {
  let unused_mask : FixedArray[Byte] = FixedArray::make(4, b'\x00')
  let header = build_header(frame, false, unused_mask)
  let n = frame.payload.length()
  let total = header.length() + n
  let out : Array[Byte] = Array::make(total, b'\x00')
  for i = 0; i < header.length(); i = i + 1 {
    out[i] = header[i]
  }
  for i = 0; i < n; i = i + 1 {
    out[header.length() + i] = frame.payload[i]
  }
  Bytes::from_array(out[:])
}
