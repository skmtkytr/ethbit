// Frame parser/builder tests.

fn make_payload(n : Int, byte : Byte) -> Bytes {
  let arr : Array[Byte] = Array::make(n, byte)
  Bytes::from_array(arr[:])
}

let test_mask : Bytes = b"\x37\xfa\x21\x3d"

// ---------- round-trip: client → server (masked) ----------

test "round-trip: build_client_frame then parse_frame for short text" {
  let frame : @ws.Frame = { fin: true, opcode: Text, payload: b"Hello" }
  let bytes = @ws.build_client_frame(frame, test_mask)
  match @ws.parse_frame(bytes) {
    Ok((parsed, n)) => {
      assert_eq(parsed, frame)
      assert_eq(n, bytes.length())
    }
    Err(e) => {
      let _ = e
      abort("expected Ok")
    }
  }
}

test "round-trip: build_server_frame then parse_frame for short binary" {
  let frame : @ws.Frame = {
    fin: true,
    opcode: Binary,
    payload: b"\x00\x01\x02\x03",
  }
  let bytes = @ws.build_server_frame(frame)
  match @ws.parse_frame(bytes) {
    Ok((parsed, n)) => {
      assert_eq(parsed, frame)
      assert_eq(n, bytes.length())
    }
    Err(_) => abort("expected Ok")
  }
}

// ---------- payload length boundaries ----------

test "round-trip: 7-bit boundary - 125 bytes" {
  let frame : @ws.Frame = {
    fin: true,
    opcode: Binary,
    payload: make_payload(125, b'\xAB'),
  }
  let bytes = @ws.build_server_frame(frame)
  // 2 header + 125 payload, no extended length, no mask.
  assert_eq(bytes.length(), 127)
  match @ws.parse_frame(bytes) {
    Ok((parsed, _)) => assert_eq(parsed, frame)
    Err(_) => abort("expected Ok")
  }
}

test "round-trip: 16-bit length - 126 bytes (low boundary)" {
  let frame : @ws.Frame = {
    fin: true,
    opcode: Binary,
    payload: make_payload(126, b'\xCD'),
  }
  let bytes = @ws.build_server_frame(frame)
  // 2 header + 2 ext_len + 126 payload.
  assert_eq(bytes.length(), 130)
  // bytes[1] low 7 bits == 126
  assert_eq(bytes[1].to_int() & 0x7F, 126)
  match @ws.parse_frame(bytes) {
    Ok((parsed, _)) => assert_eq(parsed, frame)
    Err(_) => abort("expected Ok")
  }
}

test "round-trip: 16-bit length - 65535 bytes (high boundary)" {
  let frame : @ws.Frame = {
    fin: true,
    opcode: Binary,
    payload: make_payload(65535, b'\xEF'),
  }
  let bytes = @ws.build_server_frame(frame)
  assert_eq(bytes.length(), 2 + 2 + 65535)
  match @ws.parse_frame(bytes) {
    Ok((parsed, _)) => assert_eq(parsed.payload.length(), 65535)
    Err(_) => abort("expected Ok")
  }
}

test "round-trip: 64-bit length - 66000 bytes" {
  let frame : @ws.Frame = {
    fin: true,
    opcode: Binary,
    payload: make_payload(66000, b'\x30'),
  }
  let bytes = @ws.build_server_frame(frame)
  assert_eq(bytes.length(), 2 + 8 + 66000)
  // bytes[1] low 7 bits == 127
  assert_eq(bytes[1].to_int() & 0x7F, 127)
  match @ws.parse_frame(bytes) {
    Ok((parsed, n)) => {
      assert_eq(parsed.payload.length(), 66000)
      assert_eq(n, bytes.length())
      assert_eq(parsed.payload[0], b'\x30')
      assert_eq(parsed.payload[65999], b'\x30')
    }
    Err(_) => abort("expected Ok")
  }
}

// ---------- all 6 opcodes ----------

test "opcode Continuation round-trips" {
  let f : @ws.Frame = { fin: true, opcode: Continuation, payload: b"" }
  match @ws.parse_frame(@ws.build_server_frame(f)) {
    Ok((p, _)) => assert_eq(p.opcode, Continuation)
    Err(_) => abort("expected Ok")
  }
}

test "opcode Text round-trips" {
  let f : @ws.Frame = { fin: true, opcode: Text, payload: b"hi" }
  match @ws.parse_frame(@ws.build_server_frame(f)) {
    Ok((p, _)) => assert_eq(p.opcode, Text)
    Err(_) => abort("expected Ok")
  }
}

test "opcode Binary round-trips" {
  let f : @ws.Frame = { fin: true, opcode: Binary, payload: b"\xff" }
  match @ws.parse_frame(@ws.build_server_frame(f)) {
    Ok((p, _)) => assert_eq(p.opcode, Binary)
    Err(_) => abort("expected Ok")
  }
}

test "opcode Close round-trips" {
  let f : @ws.Frame = {
    fin: true,
    opcode: Close,
    payload: b"\x03\xe8",
  } // 1000
  match @ws.parse_frame(@ws.build_server_frame(f)) {
    Ok((p, _)) => assert_eq(p.opcode, Close)
    Err(_) => abort("expected Ok")
  }
}

test "opcode Ping round-trips" {
  let f : @ws.Frame = { fin: true, opcode: Ping, payload: b"ping" }
  match @ws.parse_frame(@ws.build_server_frame(f)) {
    Ok((p, _)) => assert_eq(p.opcode, Ping)
    Err(_) => abort("expected Ok")
  }
}

test "opcode Pong round-trips" {
  let f : @ws.Frame = { fin: true, opcode: Pong, payload: b"pong" }
  match @ws.parse_frame(@ws.build_server_frame(f)) {
    Ok((p, _)) => assert_eq(p.opcode, Pong)
    Err(_) => abort("expected Ok")
  }
}

// ---------- fragmentation ----------

test "FIN=0 fragmentation start round-trips" {
  let f : @ws.Frame = { fin: false, opcode: Text, payload: b"part1" }
  let bytes = @ws.build_server_frame(f)
  // FIN bit cleared.
  assert_eq(bytes[0].to_int() & 0x80, 0)
  match @ws.parse_frame(bytes) {
    Ok((p, _)) => {
      assert_eq(p.fin, false)
      assert_eq(p.opcode, Text)
    }
    Err(_) => abort("expected Ok")
  }
}

// ---------- error paths ----------

test "ReservedBitsSet rejection" {
  // Hand-craft: FIN=1, RSV1=1, opcode=Text, len=0.
  // First byte = 0xC1 (FIN=1, RSV1=1, opcode=1).
  let bytes = b"\xc1\x00"
  match @ws.parse_frame(bytes) {
    Err(ReservedBitsSet) => ()
    Err(e) => {
      let _ = e
      abort("expected ReservedBitsSet")
    }
    Ok(_) => abort("expected error")
  }
}

test "UnknownOpcode rejection (0x3)" {
  // FIN=1, opcode=3.
  let bytes = b"\x83\x00"
  match @ws.parse_frame(bytes) {
    Err(UnknownOpcode(3)) => ()
    Err(e) => {
      let _ = e
      abort("expected UnknownOpcode(3)")
    }
    Ok(_) => abort("expected error")
  }
}

test "UnknownOpcode rejection (0xB control)" {
  // FIN=1, opcode=0xB.
  let bytes = b"\x8b\x00"
  match @ws.parse_frame(bytes) {
    Err(UnknownOpcode(11)) => ()
    Err(e) => {
      let _ = e
      abort("expected UnknownOpcode(11)")
    }
    Ok(_) => abort("expected error")
  }
}

test "ControlFrameTooLarge rejection" {
  // Hand-craft Ping with payload length 126 (uses extended 16-bit field).
  // FIN=1, opcode=9, MASK=0, len7=126, ext_len=126.
  let bytes = b"\x89\x7e\x00\x7e"
  match @ws.parse_frame(bytes) {
    Err(ControlFrameTooLarge(126)) => ()
    Err(e) => {
      let _ = e
      abort("expected ControlFrameTooLarge(126)")
    }
    Ok(_) => abort("expected error")
  }
}

test "ControlFrameNotFin rejection" {
  // Ping with FIN=0. First byte = 0x09 (FIN=0, opcode=9), len=0.
  let bytes = b"\x09\x00"
  match @ws.parse_frame(bytes) {
    Err(ControlFrameNotFin) => ()
    Err(e) => {
      let _ = e
      abort("expected ControlFrameNotFin")
    }
    Ok(_) => abort("expected error")
  }
}

test "Truncated: 0 bytes" {
  match @ws.parse_frame(b"") {
    Err(Truncated(2)) => ()
    Err(e) => {
      let _ = e
      abort("expected Truncated(2)")
    }
    Ok(_) => abort("expected error")
  }
}

test "Truncated: 1 byte (need 2 for header)" {
  match @ws.parse_frame(b"\x81") {
    Err(Truncated(1)) => ()
    Err(e) => {
      let _ = e
      abort("expected Truncated(1)")
    }
    Ok(_) => abort("expected error")
  }
}

test "Truncated: header says 16-bit ext_len but only 2 bytes given" {
  // FIN=1, opcode=Text, MASK=0, len7=126 → need 2 more bytes for ext_len.
  match @ws.parse_frame(b"\x81\x7e") {
    Err(Truncated(_)) => ()
    Err(e) => {
      let _ = e
      abort("expected Truncated")
    }
    Ok(_) => abort("expected error")
  }
}

test "Truncated: payload length declared but not delivered" {
  // FIN=1, opcode=Text, MASK=0, len=5, payload only 2 bytes.
  match @ws.parse_frame(b"\x81\x05ab") {
    Err(Truncated(3)) => ()
    Err(e) => {
      let _ = e
      abort("expected Truncated(3)")
    }
    Ok(_) => abort("expected error")
  }
}

test "Truncated: masked frame missing mask bytes" {
  // FIN=1, opcode=Text, MASK=1, len=0. Need 4 mask bytes.
  match @ws.parse_frame(b"\x81\x80") {
    Err(Truncated(4)) => ()
    Err(e) => {
      let _ = e
      abort("expected Truncated(4)")
    }
    Ok(_) => abort("expected error")
  }
}

test "client mask is correctly stripped on parse" {
  let frame : @ws.Frame = {
    fin: true,
    opcode: Text,
    payload: b"masking-test",
  }
  let bytes = @ws.build_client_frame(frame, test_mask)
  // Verify mask bit is set on the wire.
  assert_eq(bytes[1].to_int() & 0x80, 0x80)
  // Verify masked bytes on the wire don't equal the plaintext payload (with
  // overwhelming probability for a non-zero mask).
  assert_eq(bytes[6].to_int() != b'm'.to_int(), true)
  // After parsing, the payload comes back unmasked.
  match @ws.parse_frame(bytes) {
    Ok((parsed, _)) => assert_eq(parsed.payload, b"masking-test")
    Err(_) => abort("expected Ok")
  }
}
