// EIP-712 typed-data: type-string-driven typeHash, structHash, and
// signTypedData_v4 (high-level API).
//
// Spec: https://eips.ethereum.org/EIPS/eip-712
//
// Pre-computed-digest helpers (`typed_data_digest`, `sign_typed_data`)
// remain in msg.mbt; this file adds the description-driven layer that
// matches viem's `signTypedData`.


///|
/// EIP-712 domain. All fields are optional; the domain type string is
/// constructed from only the Some fields, in the canonical order
/// (name, version, chainId, verifyingContract, salt). This matches viem.
pub(all) struct Domain {
  name : String?
  version : String?
  chain_id : @bigint.BigInt?
  verifying_contract : Bytes?
  salt : Bytes?
}

///|
/// One field of a struct type, e.g. {"name": "from", "type_": "Person"}.
pub(all) struct Field {
  name : String
  type_ : String
}

///|
/// A typed value tree used as input to struct_hash / hash_typed_data.
///
/// Primitives:
///   V_uint(N, value)   N in 8..256 (multiple of 8)
///   V_int(N, value)    N in 8..256 (multiple of 8); negatives via two's complement
///   V_bool
///   V_address          exactly 20 bytes
///   V_bytes_n(N, b)    N in 1..32, b length == N
///   V_bytes            dynamic
///   V_string
/// Composites:
///   V_array(elem_type_name, items)          dynamic T[]
///   V_struct(name, named_fields_in_order)   struct (named, ordered fields)
pub(all) enum Value {
  V_uint(Int, @bigint.BigInt)
  V_int(Int, @bigint.BigInt)
  V_bool(Bool)
  V_address(Bytes)
  V_bytes_n(Int, Bytes)
  V_bytes(Bytes)
  V_string(String)
  V_array(String, Array[Value])
  V_struct(String, Array[(String, Value)])
}

///|
/// Errors returned by EIP-712 type-driven encoding.
pub(all) suberror Eip712Error {
  UnknownType(String)
  TypeMismatch(String, String)
  InvalidAddress(Int)
  InvalidBytesN(Int, Int)
  CircularType(String)
}

///|
pub impl Show for Eip712Error with output(self, logger) {
  match self {
    UnknownType(s) => {
      logger.write_string("UnknownType(\"")
      logger.write_string(s)
      logger.write_string("\")")
    }
    TypeMismatch(expected, actual) => {
      logger.write_string("TypeMismatch(\"")
      logger.write_string(expected)
      logger.write_string("\", \"")
      logger.write_string(actual)
      logger.write_string("\")")
    }
    InvalidAddress(n) => {
      logger.write_string("InvalidAddress(")
      logger.write_object(n)
      logger.write_char(')')
    }
    InvalidBytesN(expected, actual) => {
      logger.write_string("InvalidBytesN(")
      logger.write_object(expected)
      logger.write_string(", ")
      logger.write_object(actual)
      logger.write_char(')')
    }
    CircularType(s) => {
      logger.write_string("CircularType(\"")
      logger.write_string(s)
      logger.write_string("\")")
    }
  }
}

///|
/// Map of struct-name → ordered fields. Must include `primary` and every
/// type referenced transitively. Need NOT include "EIP712Domain" — that's
/// constructed internally from the Domain struct.
pub type TypeRegistry = Map[String, Array[Field]]

// ---------------- type-name helpers ----------------

///|
/// Strip a single trailing "[]" suffix; returns (elem_name, true) if present.
fn strip_array_suffix(name : String) -> (String, Bool) {
  match name.strip_suffix("[]") {
    Some(view) => (view.to_string(), true)
    None => (name, false)
  }
}

// ---------------- encodeType: dependency walk ----------------

///|
/// Walk dependencies starting from `name`. Adds every reachable struct
/// (including `name` itself) into `acc`. Detects cycles via `visiting`.
fn collect_deps(
  name : String,
  types : TypeRegistry,
  acc : Map[String, Bool],
  visiting : Map[String, Bool],
) -> Result[Unit, Eip712Error] {
  if acc.contains(name) {
    return Ok(())
  }
  if visiting.contains(name) {
    return Err(CircularType(name))
  }
  let fields = match types.get(name) {
    Some(fs) => fs
    None => return Err(UnknownType(name))
  }
  visiting.set(name, true)
  for f in fields {
    let (base, _) = strip_array_suffix(f.type_)
    if types.contains(base) {
      match collect_deps(base, types, acc, visiting) {
        Err(e) => return Err(e)
        Ok(_) => ()
      }
    }
  }
  visiting.set(name, false)
  acc.set(name, true)
  Ok(())
}

///|
/// Render a single struct as `Name(type1 name1,type2 name2,...)`.
fn render_struct(name : String, fields : Array[Field]) -> String {
  let mut s = name + "("
  for i = 0; i < fields.length(); i = i + 1 {
    if i > 0 {
      s = s + ","
    }
    s = s + fields[i].type_ + " " + fields[i].name
  }
  s + ")"
}

///|
/// Canonical encodeType per EIP-712 §encodeType.
pub fn encode_type(
  primary : String,
  types : TypeRegistry,
) -> Result[String, Eip712Error] {
  let acc : Map[String, Bool] = Map::new()
  let visiting : Map[String, Bool] = Map::new()
  match collect_deps(primary, types, acc, visiting) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  // Sort dependencies (excluding primary) alphabetically.
  // (`Array::sort` requires `Compare`, but the available String comparison
  // here is `lexical_compare`, so we use `sort_by`.)
  let deps : Array[String] = []
  for name, _ in acc {
    if name != primary {
      deps.push(name)
    }
  }
  deps.sort_by(fn(x, y) { x.lexical_compare(y) })
  // primary first, then each dep in sorted order.
  let primary_fields = match types.get(primary) {
    Some(fs) => fs
    None => return Err(UnknownType(primary))
  }
  let mut out = render_struct(primary, primary_fields)
  for d in deps {
    let fs = match types.get(d) {
      Some(fs) => fs
      None => return Err(UnknownType(d))
    }
    out = out + render_struct(d, fs)
  }
  Ok(out)
}

///|
/// typeHash = keccak256(encode_type(primary, types)).
pub fn type_hash(
  primary : String,
  types : TypeRegistry,
) -> Result[Bytes, Eip712Error] {
  match encode_type(primary, types) {
    Err(e) => Err(e)
    Ok(s) => Ok(@keccak.keccak256(@utf8.encode(s.view())))
  }
}

// ---------------- encodeData ----------------

///|
/// Encode a single value as 32 bytes per its declared type.
/// `decl_type` is the EIP-712 type-string form (e.g. "uint256", "Person",
/// "string", "uint256[]"). `types` is the registry for struct lookup.
fn encode_data_word(
  decl_type : String,
  v : Value,
  types : TypeRegistry,
) -> Result[Bytes, Eip712Error] {
  let (base, is_array) = strip_array_suffix(decl_type)
  if is_array {
    // T[] : encode each element's word, concat, then keccak.
    match v {
      V_array(_, items) => {
        let parts : Array[Bytes] = Array::make(items.length(), b"")
        for i = 0; i < items.length(); i = i + 1 {
          match encode_data_word(base, items[i], types) {
            Err(e) => return Err(e)
            Ok(w) => parts[i] = w
          }
        }
        Ok(@keccak.keccak256(@bytesx.concat(parts)))
      }
      _ => Err(TypeMismatch(decl_type, value_type_name(v)))
    }
  } else if types.contains(base) {
    // Nested struct: structHash recursively.
    match v {
      V_struct(struct_name, _) =>
        if struct_name != base {
          return Err(TypeMismatch(base, struct_name))
        } else {
          struct_hash(base, types, v)
        }
      _ => Err(TypeMismatch(base, value_type_name(v)))
    }
  } else {
    encode_primitive_word(base, v)
  }
}

///|
/// Diagnostic: short type-name of a Value (for error messages).
fn value_type_name(v : Value) -> String {
  match v {
    V_uint(n, _) => "uint" + n.to_string()
    V_int(n, _) => "int" + n.to_string()
    V_bool(_) => "bool"
    V_address(_) => "address"
    V_bytes_n(n, _) => "bytes" + n.to_string()
    V_bytes(_) => "bytes"
    V_string(_) => "string"
    V_array(elem, _) => elem + "[]"
    V_struct(name, _) => name
  }
}

///|
/// Encode a primitive (non-struct, non-array) value as a 32-byte word.
fn encode_primitive_word(
  decl_type : String,
  v : Value,
) -> Result[Bytes, Eip712Error] {
  match v {
    V_uint(bits, value) => {
      // Sanity: declared and provided bit-widths should agree, but we
      // don't enforce strictly — caller passes the correct type string.
      let _ = bits
      let _ = decl_type
      // Encode as N/8 bytes BE, then left-zero-pad to 32.
      let n_bytes = bits / 8
      let payload = value.to_octets(length=n_bytes)
      Ok(@bytesx.pad_left(payload, 32, b'\x00'))
    }
    V_int(bits, value) => {
      // Two's complement to fixed N bits, then left-pad with sign byte to 32.
      let n_bytes = bits / 8
      let mod_2n = @bigint.BigInt::from_int(1) << bits
      let normalized = if value.compare_int(0) < 0 {
        // Reduce into [0, 2^N) by adding 2^N (handles negatives).
        let mut x = value
        while x.compare_int(0) < 0 {
          x = x + mod_2n
        }
        x
      } else {
        value
      }
      let payload = normalized.to_octets(length=n_bytes)
      // For negative values, sign-extend with 0xff up to 32 bytes.
      let pad_byte = if value.compare_int(0) < 0 {
        b'\xff'
      } else {
        b'\x00'
      }
      Ok(@bytesx.pad_left(payload, 32, pad_byte))
    }
    V_bool(true) => Ok(@bytesx.pad_left(b"\x01", 32, b'\x00'))
    V_bool(false) => Ok(Bytes::make(32, b'\x00'))
    V_address(b) =>
      if b.length() != 20 {
        Err(InvalidAddress(b.length()))
      } else {
        Ok(@bytesx.pad_left(b, 32, b'\x00'))
      }
    V_bytes_n(n, b) =>
      if b.length() != n {
        Err(InvalidBytesN(n, b.length()))
      } else {
        Ok(@bytesx.pad_right(b, 32, b'\x00'))
      }
    V_bytes(b) => Ok(@keccak.keccak256(b))
    V_string(s) => Ok(@keccak.keccak256(@utf8.encode(s.view())))
    V_array(_, _) | V_struct(_, _) =>
      // Should be handled by encode_data_word's array/struct branches.
      Err(TypeMismatch(decl_type, value_type_name(v)))
  }
}

///|
/// structHash = keccak256(typeHash || encodeData(message)).
pub fn struct_hash(
  primary : String,
  types : TypeRegistry,
  message : Value,
) -> Result[Bytes, Eip712Error] {
  // The message must be V_struct with name == primary.
  let fields_in_msg = match message {
    V_struct(struct_name, fs) =>
      if struct_name != primary {
        return Err(TypeMismatch(primary, struct_name))
      } else {
        fs
      }
    _ => return Err(TypeMismatch(primary, value_type_name(message)))
  }
  let type_decl = match types.get(primary) {
    Some(fs) => fs
    None => return Err(UnknownType(primary))
  }
  let th = match type_hash(primary, types) {
    Err(e) => return Err(e)
    Ok(h) => h
  }
  // For each declared field (in order), encode data word using value
  // looked up by name.
  let parts : Array[Bytes] = Array::make(type_decl.length() + 1, b"")
  parts[0] = th
  for i = 0; i < type_decl.length(); i = i + 1 {
    let fdecl = type_decl[i]
    // Find the value with matching field name in message.
    let mut found : Value? = None
    for j = 0; j < fields_in_msg.length(); j = j + 1 {
      let (n, fv) = fields_in_msg[j]
      if n == fdecl.name {
        found = Some(fv)
        break
      }
    }
    let v = match found {
      Some(v) => v
      None => return Err(TypeMismatch(fdecl.name, "<missing>"))
    }
    match encode_data_word(fdecl.type_, v, types) {
      Err(e) => return Err(e)
      Ok(w) => parts[i + 1] = w
    }
  }
  Ok(@keccak.keccak256(@bytesx.concat(parts)))
}

// ---------------- Domain ----------------

///|
/// Build the EIP712Domain TypeRegistry from a Domain. Only Some-fields are
/// included, in viem's canonical order. This is what determines the domain
/// type string.
fn domain_type_registry(domain : Domain) -> (TypeRegistry, Array[(String, Value)]) {
  let fields : Array[Field] = []
  let values : Array[(String, Value)] = []
  match domain.name {
    Some(s) => {
      fields.push({ name: "name", type_: "string" })
      values.push(("name", V_string(s)))
    }
    None => ()
  }
  match domain.version {
    Some(s) => {
      fields.push({ name: "version", type_: "string" })
      values.push(("version", V_string(s)))
    }
    None => ()
  }
  match domain.chain_id {
    Some(v) => {
      fields.push({ name: "chainId", type_: "uint256" })
      values.push(("chainId", V_uint(256, v)))
    }
    None => ()
  }
  match domain.verifying_contract {
    Some(b) => {
      fields.push({ name: "verifyingContract", type_: "address" })
      values.push(("verifyingContract", V_address(b)))
    }
    None => ()
  }
  match domain.salt {
    Some(b) => {
      fields.push({ name: "salt", type_: "bytes32" })
      values.push(("salt", V_bytes_n(32, b)))
    }
    None => ()
  }
  let reg : TypeRegistry = Map::new()
  reg.set("EIP712Domain", fields)
  (reg, values)
}

///|
/// Domain separator = structHash("EIP712Domain", domain).
/// The EIP712Domain field set is exactly the Some-fields of `domain`.
pub fn domain_separator(domain : Domain) -> Bytes {
  let (reg, values) = domain_type_registry(domain)
  let msg : Value = V_struct("EIP712Domain", values)
  // domain inputs are constructed locally and always well-formed; an
  // error here would indicate a bug in domain_type_registry.
  match struct_hash("EIP712Domain", reg, msg) {
    Ok(h) => h
    Err(_) => abort("domain_separator: internal error")
  }
}

///|
/// hash_typed_data = keccak256(0x19 0x01 || domain_separator || struct_hash).
pub fn hash_typed_data(
  domain : Domain,
  primary : String,
  types : TypeRegistry,
  message : Value,
) -> Result[Bytes, Eip712Error] {
  let ds = domain_separator(domain)
  let sh = match struct_hash(primary, types, message) {
    Err(e) => return Err(e)
    Ok(h) => h
  }
  Ok(typed_data_digest(ds, sh))
}

///|
/// signTypedData_v4 — viem-equivalent.
pub fn sign_typed_data_v4(
  sk : @bigint.BigInt,
  domain : Domain,
  primary : String,
  types : TypeRegistry,
  message : Value,
) -> Result[SignedMessage, Eip712Error] {
  match hash_typed_data(domain, primary, types, message) {
    Err(e) => Err(e)
    Ok(digest) =>
      Ok(eip712_ecdsa_to_signed_message(@secp256k1.sign(sk, digest)))
  }
}

///|
/// Local copy of msg.mbt's `ecdsa_to_signed_message` (kept private to avoid
/// modifying msg.mbt). Same semantics: r/s zero-padded to 32 bytes,
/// v ∈ {0x1B, 0x1C}.
fn eip712_ecdsa_to_signed_message(sig : @secp256k1.EcdsaSig) -> SignedMessage {
  let parity = sig.recid & 1
  let v_byte = if parity == 0 {
    b"\x1b"
  } else {
    b"\x1c"
  }
  {
    r: sig.r.to_octets(length=32),
    s: sig.s.to_octets(length=32),
    v: v_byte,
  }
}
