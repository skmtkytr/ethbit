// Integration fixtures captured from the Sepolia public RPC node
// (https://ethereum-sepolia-rpc.publicnode.com). Each test pins a real
// response body and asserts that decode_response + the relevant
// parse_<type> handles it correctly.
//
// To regenerate / refresh: see rpc/INTEGRATION.md.

fn s_unwrap_ok(r : @rpc.Response) -> Json {
  match r {
    Ok(_, v) => v
    Err(_, e) => abort("expected Ok, got Err: " + e.message)
  }
}

// ---- eth_chainId ----

test "sepolia: eth_chainId" {
  let body =
    #|{"jsonrpc":"2.0","result":"0xaa36a7","id":1}
  match @rpc.decode_response(body) {
    Some(resp) => {
      let result = s_unwrap_ok(resp)
      let chain_id = @rpc.parse_hex_quantity(result)
      match chain_id {
        Some(id) =>
          assert_eq(
            id,
            @bigint.BigInt::from_string("aa36a7", radix=16),
          )
        None => abort("chain_id parse failed")
      }
    }
    None => abort("decode_response failed")
  }
}

// ---- eth_blockNumber ----

test "sepolia: eth_blockNumber" {
  let body =
    #|{"jsonrpc":"2.0","result":"0xa409a0","id":1}
  match @rpc.decode_response(body) {
    Some(resp) => {
      let result = s_unwrap_ok(resp)
      match @rpc.parse_hex_quantity(result) {
        Some(n) =>
          assert_true(n > @bigint.BigInt::from_int(10_000_000))
        None => abort("blockNumber parse failed")
      }
    }
    None => abort("decode_response failed")
  }
}

// ---- eth_getBalance ----

test "sepolia: eth_getBalance for vitalik.eth" {
  let body =
    #|{"jsonrpc":"2.0","id":1,"result":"0x31a30435c1af2593c"}
  match @rpc.decode_response(body) {
    Some(resp) => {
      let v = @rpc.parse_hex_quantity(s_unwrap_ok(resp))
      match v {
        Some(wei) =>
          assert_eq(
            wei,
            @bigint.BigInt::from_string("31a30435c1af2593c", radix=16),
          )
        None => abort("balance parse failed")
      }
    }
    None => abort("decode failed")
  }
}

// ---- eth_syncing: false ----

test "sepolia: eth_syncing returns NotSyncing on a healthy node" {
  let body =
    #|{"jsonrpc":"2.0","id":1,"result":false}
  match @rpc.decode_response(body) {
    Some(resp) => {
      let r = s_unwrap_ok(resp)
      match @rpc.parse_syncing_status(r) {
        Some(NotSyncing) => ()
        Some(Syncing(_)) => abort("expected NotSyncing")
        None => abort("syncing parse failed")
      }
    }
    None => abort("decode failed")
  }
}

// ---- eth_feeHistory ----

test "sepolia: eth_feeHistory parses with rewards and blob-gas fields" {
  let body =
    #|{"jsonrpc":"2.0","id":1,"result":{"oldestBlock":"0xa4099d","reward":[["0xf8aa6","0x5f8716f"],["0xf8aa6","0x5f1f724"],["0xf8aa6","0x5ef90f9"],["0xf8aa6","0x49a188f"]],"baseFeePerGas":["0x216f0dc0","0x205b141e","0x20f6c725","0x20ad5138","0x1f733f2e"],"gasUsedRatio":[0.3710254,0.5751891166666667,0.4651794833333333,0.34982256666666667],"baseFeePerBlobGas":["0x1dedfe6","0x1e0ab23","0x1ef4396","0x2022219","0x207eed4"],"blobGasUsedRatio":[0.047619047619047616,0.38095238095238093,0.47619047619047616,0.14285714285714285]}}
  match @rpc.decode_response(body) {
    Some(resp) => {
      let r = s_unwrap_ok(resp)
      match @rpc.parse_fee_history(r) {
        Some(fh) => {
          assert_eq(
            fh.oldest_block,
            @bigint.BigInt::from_string("a4099d", radix=16),
          )
          // 4 blocks → 5 baseFeePerGas (oldest .. newest+1)
          assert_eq(fh.base_fee_per_gas.length(), 5)
          assert_eq(fh.gas_used_ratio.length(), 4)
          // Two reward percentiles requested
          assert_eq(fh.reward.length(), 4)
          assert_eq(fh.reward[0].length(), 2)
          // Cancun blob-gas fields should be present
          match fh.base_fee_per_blob_gas {
            Some(arr) => assert_eq(arr.length(), 5)
            None => abort("expected base_fee_per_blob_gas")
          }
        }
        None => abort("fee_history parse failed")
      }
    }
    None => abort("decode failed")
  }
}

// ---- eth_getTransactionByHash (type-2) ----

test "sepolia: eth_getTransactionByHash parses a type-2 tx" {
  let body =
    #|{"jsonrpc":"2.0","id":1,"result":{"blockHash":"0x368a06a326f9da8721bb14c0cf9b615ab6778112bb1162749bc05e9d0f9ce7fd","blockNumber":"0xa40900","blockTimestamp":"0x69f0e0b8","from":"0x5b9fcd4e4bf5d22f32df5d2f99323c0824bbfe34","gas":"0x7278","gasPrice":"0x8e2a18e6","maxFeePerGas":"0x8e2a18e6","maxPriorityFeePerGas":"0x77359400","hash":"0xf63d7d591f84a07f02805339e48f63d407f7323b3917c3a49b624474b4b290fc","input":"0x095ea7b3000000000000000000000000742d35cc6634c0532925a3b844bc454e4438f450000000000000000000000000000000000000000000000000027e8e986e924458","nonce":"0x37b","to":"0x7b79995e5f793a07bc00c21412e50ecae098e7f9","transactionIndex":"0x0","value":"0x0","type":"0x2","accessList":[],"chainId":"0xaa36a7","v":"0x0","r":"0x112e32821062d683a75f8e1a71bcfcfecc4787d9720332515f59ab260c08978e","s":"0x57ad5b860a5b8f6bd3d0349c33a44a05705c9334fcb78c63ea760826310a111d","yParity":"0x0"}}
  match @rpc.decode_response(body) {
    Some(resp) => {
      let r = s_unwrap_ok(resp)
      match @rpc.parse_transaction_info(r) {
        Some(tx) => {
          assert_eq(tx.type_, 2)
          assert_eq(tx.nonce, @bigint.BigInt::from_string("37b", radix=16))
          // Required fields populated
          assert_eq(tx.hash.length(), 32)
          assert_true(tx.from_.length() == 20)
          // to is Some(address)
          match tx.to {
            Some(a) => assert_eq(a.length(), 20)
            None => abort("expected to address")
          }
          // type-2 has maxFeePerGas / maxPriorityFeePerGas
          assert_true(tx.max_fee_per_gas != None)
          assert_true(tx.max_priority_fee_per_gas != None)
        }
        None => abort("tx parse failed")
      }
    }
    None => abort("decode failed")
  }
}

// ---- eth_getTransactionReceipt (post-byzantium) ----

test "sepolia: eth_getTransactionReceipt parses with one log" {
  let body =
    #|{"jsonrpc":"2.0","id":1,"result":{"blockHash":"0x368a06a326f9da8721bb14c0cf9b615ab6778112bb1162749bc05e9d0f9ce7fd","blockNumber":"0xa40900","contractAddress":null,"cumulativeGasUsed":"0x711c","effectiveGasPrice":"0x8e2a18e6","from":"0x5b9fcd4e4bf5d22f32df5d2f99323c0824bbfe34","gasUsed":"0x711c","logs":[{"address":"0x7b79995e5f793a07bc00c21412e50ecae098e7f9","topics":["0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925","0x0000000000000000000000005b9fcd4e4bf5d22f32df5d2f99323c0824bbfe34","0x000000000000000000000000742d35cc6634c0532925a3b844bc454e4438f450"],"data":"0x000000000000000000000000000000000000000000000000027e8e986e924458","blockNumber":"0xa40900","transactionHash":"0xf63d7d591f84a07f02805339e48f63d407f7323b3917c3a49b624474b4b290fc","transactionIndex":"0x0","blockHash":"0x368a06a326f9da8721bb14c0cf9b615ab6778112bb1162749bc05e9d0f9ce7fd","blockTimestamp":"0x69f0e0b8","logIndex":"0x0","removed":false}],"logsBloom":"0x00000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000080000000000000000000000000000000000000002000000000000000000000000000000000000000000000000008000000010400000000000000000000000000080000000000000400000000000010000","status":"0x1","to":"0x7b79995e5f793a07bc00c21412e50ecae098e7f9","transactionHash":"0xf63d7d591f84a07f02805339e48f63d407f7323b3917c3a49b624474b4b290fc","transactionIndex":"0x0","type":"0x2"}}
  match @rpc.decode_response(body) {
    Some(resp) => {
      let r = s_unwrap_ok(resp)
      match @rpc.parse_transaction_receipt(r) {
        Some(rcpt) => {
          // status = 1 (success)
          match rcpt.status {
            Some(s) => assert_eq(s, @bigint.BigInt::from_int(1))
            None => abort("expected status")
          }
          assert_eq(rcpt.type_, 2)
          assert_eq(rcpt.contract_address, None)
          assert_eq(rcpt.logs.length(), 1)
          let log = rcpt.logs[0]
          assert_eq(log.removed, false)
          assert_eq(log.topics.length(), 3)
          assert_eq(log.address.length(), 20)
          // logsBloom must be 256 bytes
          assert_eq(rcpt.logs_bloom.length(), 256)
        }
        None => abort("receipt parse failed")
      }
    }
    None => abort("decode failed")
  }
}

// ---- error response ----

test "sepolia: error responses decode to Err arm" {
  // Synthetic but spec-shaped; equivalent to what publicnode returns on a
  // non-existent method.
  let body =
    #|{"jsonrpc":"2.0","id":1,"error":{"code":-32601,"message":"the method does_not_exist does not exist/is not available"}}
  match @rpc.decode_response(body) {
    Some(Err(id, err)) => {
      assert_eq(id, Some(1))
      assert_eq(err.code, -32601)
      assert_true(err.message.length() > 0)
    }
    Some(Ok(_, _)) => abort("expected Err")
    None => abort("decode failed")
  }
}
