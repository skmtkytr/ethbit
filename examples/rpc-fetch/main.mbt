// JS-target demo: live calls to the Sepolia public RPC node.
//
// Build & run:
//   moon run --target js examples/rpc-fetch
//
// Requires Node 18+ (for global fetch) or any host that exposes a
// fetch-compatible global (Bun, Deno, browser, undici-equipped Node).

let endpoint : String = "https://ethereum-sepolia-rpc.publicnode.com"

fn run_chain_id() -> Unit {
  let req : @rpc.Request = { id: 1, method: "eth_chainId", params: [] }
  @rpc.fetch_request(
    endpoint,
    req,
    fn(resp) {
      match resp {
        Ok(_, result) =>
          match @rpc.parse_hex_quantity(result) {
            Some(id) => {
              println("eth_chainId           = " + id.to_string())
              run_block_number()
            }
            None => println("chain_id parse failed")
          }
        Err(_, e) => println("rpc error: " + e.message)
      }
    },
    fn(err) { println("fetch error: " + err.to_string()) },
  )
}

fn run_block_number() -> Unit {
  let req : @rpc.Request = { id: 2, method: "eth_blockNumber", params: [] }
  @rpc.fetch_request(
    endpoint,
    req,
    fn(resp) {
      match resp {
        Ok(_, result) =>
          match @rpc.parse_hex_quantity(result) {
            Some(n) => {
              println("eth_blockNumber       = " + n.to_string())
              run_balance()
            }
            None => println("blockNumber parse failed")
          }
        Err(_, e) => println("rpc error: " + e.message)
      }
    },
    fn(err) { println("fetch error: " + err.to_string()) },
  )
}

fn run_balance() -> Unit {
  // vitalik.eth
  let addr = b"\xd8\xda\x6b\xf2\x69\x64\xaf\x9d\x7e\xed\x9e\x03\xe5\x34\x15\xd3\x7a\xa9\x60\x45"
  let req = @rpc.eth_get_balance(addr, "latest")
  let req2 : @rpc.Request = { id: 3, method: req.method, params: req.params }
  @rpc.fetch_request(
    endpoint,
    req2,
    fn(resp) {
      match resp {
        Ok(_, result) =>
          match @rpc.parse_hex_quantity(result) {
            Some(wei) =>
              println("balance(vitalik) wei  = " + wei.to_string())
            None => println("balance parse failed")
          }
        Err(_, e) => println("rpc error: " + e.message)
      }
    },
    fn(err) { println("fetch error: " + err.to_string()) },
  )
}

fn main {
  println("ethbit rpc demo against Sepolia (publicnode.com)")
  println("------------------------------------------------")
  run_chain_id()
}
