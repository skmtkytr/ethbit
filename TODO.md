# TODO

機能・改善のメモ。優先度や着手予定は付けない（その時必要な物から拾う）。

## 既存パッケージの未完成箇所

### bip32
- 派生 path の hardened-only 制約検証ヘルパ（priv-only path / pub-only path の事前判定）

### bip39
- 他言語 wordlist（Japanese / Chinese / Korean / Spanish 等。必要になれば）
- Unicode 入力時の NFKD 正規化（現状は呼び出し側責任。`String` レベルで対応するならパッケージ追加）

### msg（EIP-712）
- 固定サイズ配列 `T[K]` 対応（現状は dynamic `T[]` のみ）
- viem の `signTypedData` / `verifyTypedData` 出力との byte-equivalence テスト（最終ハッシュは spec 例で一致確認済み、追加ベクトルが欲しい）

### rpc
- HTTP transport：JS は `fetch_post` / `fetch_request` 実装済（`examples/rpc-fetch` で動作確認）。native は libcurl FFI、wasm-gc は host import まだ
- WebSocket transport：フレーム / handshake のプロトコル層は `ws` パッケージに実装済。残るは TCP + TLS の per-target 接続層
- erigon 固有 namespace（`erigon_getHeaderByNumber`, `erigon_blockNumber`, `erigon_forks`, `erigon_getBlockByTimestamp`, etc.）
- engine_API（コンセンサスクライアント連携。通常 wallet 不要だが完全性のため）
- admin_API / personal_API（後者はセキュリティ的に非推奨。実装するか判断）
- `TraceResult` / debug_* 系の型付きデコーダ（その他の標準レスポンス：`Block`, `TransactionReceipt`, `TransactionInfo`, `Log`, `Withdrawal`, `FeeHistoryResult`, `SyncingStatus`, `AccessListResult` は実装済）
- `eth_subscribe` 用の subscription manager（id ↔ callback 管理）

### secp256k1
- Montgomery ladder の branchless swap（best-effort CT 強化、wall-clock では効果が見えづらいが LLVM IR レベルで分岐除去を狙う）
- 圧縮鍵 decode 内の `y² = α` チェックと `on_curve` の重複整理
- limb-based field 演算（4×UInt64 や 5×UInt52）への切り替え検討（perf）
- bench 整備（sign / verify / recover の throughput を target 別に記録）

### tx
- デコーダ：署名済 tx bytes → `TxLegacy` / `Tx1559` / `Tx4844` の構造体復元
- type バイトを見て自動判別する `decode_signed(b : Bytes) -> SignedTx` 的な統一エントリ
- access list を持つ EIP-2930 (type-1) の正式サポート（現状 1559 のみ）

### address
- EIP-1191（chain-id を含むチェックサム）対応
- ICAP（Inter-exchange Client Address Protocol、IBAN 風）— 実用度低いが標準

## 新規パッケージ候補

### ens
- namehash（EIP-137）
- resolver lookup：`Resolver` registry に `eth_call` して resolver address 取得 → resolver に `addr(bytes32)` 呼び
- name → address、address → name（reverse resolver）
- UTS46 / IDNA 正規化（複雑。ASCII-only から段階的に）

### keystore
- web3 keystore v3 JSON（Geth / ethers 互換）の encrypt / decrypt
- KDF：scrypt と PBKDF2-HMAC-SHA-256 両対応（v3 仕様）
- 対称暗号：AES-128-CTR
- MAC：keccak256（Ethereum 仕様）
- 依存：scrypt 実装（自前 or 外部）、AES 実装（自前）

### contract
- ABI + RPC を組み合わせた型付きコントラクト呼び出し
- `Contract { address, abi }` から `contract.call("name", args) -> Result[Decoded, _]`
- view / pure / nonpayable / payable の区別

### multicall
- Multicall3 経由のバッチ呼び出し（一般的なユースケース）

## ハッシュ系ユーティリティ

- `hash160(bytes) = ripemd160(sha256(bytes))` を独立ヘルパとして公開（現状 bip32 内部）
- SHA-1 を独立パッケージに切り出すか（現状 ws の private、handshake 専用）
- Base64 を独立パッケージに切り出すか（現状 ws の private）
- BLAKE2b（KDF や Ethereum L2 で使われる箇所がある）
- SHA-3-256 / SHA-3-512（Keccak とは別物。NIST 標準。需要次第）

## 横断品質

### viem 互換性テスト
- 現状は tx と secp256k1 のみ byte-equivalence 確認済
- 残：msg / units / bip32 / bip39 / rpc encodings の cross-check
- `tools/viem-vectors/gen.mjs` を再導入する形で合意済

### Constant-time
- LLVM IR / wasm bytecode を読んで秘密依存分岐の不在確認
- `cttest` の dudect 拡張：closure-twin ノイズ床を引いた効果サイズで判定
- ctgrind を native target に試す（理論上は LLVM 出力に対して可能）

### Bench
- 各パッケージに `*_bench_test.mbt`：keccak / sha256 / sha512 / secp256k1 sign / verify
- target 比較表を REPORT として出力

### CI
- GitHub Actions：3 target × `moon check` + `moon test`
- 各 target で test 件数の regression check

## ドキュメント

- `cttest/REPORT.md` を参照する SECURITY 系の集約

## 検討事項

- パッケージ命名：`msg` は曖昧か（ethereum-message-signing が主目的）。後で `ethsign` / `eipmsg` 等に変える余地
- `secp256k1` を pure-MoonBit のまま維持するか、native target だけ libsecp256k1 への FFI を許すか
- 1MB-of-'a' を使う bench / 大入力テストは CI で時間がかかるので分離 tag を付ける
- `cttest/` を library から外して `tools/` 配下に移すか（出荷物ではないので）
