# MoonBit における constant-time 性の経験的測定

## 目的

`secp256k1` を MoonBit で実装するにあたり、言語/コンパイラの上で
constant-time (CT) 性をどこまで担保できるかを経験的に把握する。

## 対象実装

`cttest/cttest.mbt` に 4 関数を定義:

| 関数 | 内容 |
|---|---|
| `bytes_eq_naive` | 先頭から比較し、最初の不一致で `return false` |
| `bytes_eq_xorfold` | 全バイトを XOR-fold し最後に 0 か判定 (源コード上は branchless) |
| `select_branch` | `if cond { a } else { b }` |
| `select_mask` | バイト毎に `(a & m) \| (b & ~m)`、長さ分のループ＋新規 `Bytes` を返す |

## 計測方法

### 環境

| 項目 | 値 |
|---|---|
| OS | Linux 7.0.2-1-cachyos x86_64 |
| CPU | AMD Ryzen 7 7800X3D (max 5053 MHz) |
| moon | 0.1.20260417 (8650a31 2026-04-17) |
| flag | `--release` |
| target | `native`, `wasm-gc`, `js` の 3 種 |

### コマンド

```fish
moon bench --target native  -p skmtkytr/ethbit/cttest --release
moon bench --target wasm-gc -p skmtkytr/ethbit/cttest --release
moon bench --target js      -p skmtkytr/ethbit/cttest --release
```

### 入力

`bytes_eq_*` は 32B / 1KB の 2 サイズ × 以下 2 ケースを各 10 × 100000 runs:

- `early_diff`: `a[0]=0xFF`, `b` 全 0 (1 バイト目で不一致)
- `all_eq`: `a == b` 全 0 (ループ最後まで実行)

`select_*` は `cond ∈ {true,false} / {0xFF,0x00}` の 2 ケース × 32B 入力。

## 結果 (観察事実)

### bytes_eq_naive (early-return)

| target | size | early_diff | all_eq | 比 |
|---|---|---|---|---|
| native | 32B | 28.40 ns ± 0.06 | 100.82 ns ± 1.37 | 3.55× |
| native | 1KB | 28.45 ns ± 0.08 | 2280 ns ± 16.51 | 80.1× |
| wasm-gc | 32B | 6.62 ns ± 0.14 | 22.79 ns ± 0.21 | 3.44× |
| wasm-gc | 1KB | 8.94 ns ± 0.23 | 472.39 ns ± 0.58 | 52.8× |
| js | 32B | 7.99 ns ± 0.16 | 34.61 ns ± 4.02 | 4.33× |
| js | 1KB | 9.67 ns ± 0.28 | 390.90 ns ± 15.37 | 40.4× |

3 ターゲットすべてで mean 差が σ の桁を遥かに超えている。

### bytes_eq_xorfold (XOR-fold)

| target | size | early_diff | all_eq | 差 |
|---|---|---|---|---|
| native | 32B | 121.36 ns ± 0.64 | 120.91 ns ± 0.36 | -0.45 ns (σ 内) |
| native | 1KB | 3000 ns ± 2.35 | 3000 ns ± 7.39 | σ 内 |
| wasm-gc | 32B | 21.18 ns ± 0.06 | 21.06 ns ± 0.08 | -0.12 ns (σ 内) |
| wasm-gc | 1KB | 432.29 ns ± 1.62 | 433.13 ns ± 2.70 | +0.84 ns (σ 内) |
| js | 32B | 35.92 ns ± 1.35 | 35.84 ns ± 1.38 | -0.08 ns (σ 内) |
| js | 1KB | 400.32 ns ± 6.03 | 393.75 ns ± 9.53 | -6.6 ns (σ 内) |

3 ターゲットすべてで mean 差が σ 以内に収まる。

### select_branch / select_mask (32B)

| target | impl | cond=true/0xFF | cond=false/0x00 | 差 |
|---|---|---|---|---|
| native | branch | 23.99 ns ± 0.11 | 24.99 ns ± 0.08 | +1.00 ns (σ 外) |
| native | mask | 675.05 ns ± 1.81 | 678.05 ns ± 2.29 | +3.00 ns (σ 内) |
| wasm-gc | branch | 7.95 ns ± 0.10 | 8.28 ns ± 0.08 | +0.33 ns (σ 外) |
| wasm-gc | mask | 181.33 ns ± 0.38 | 181.08 ns ± 1.14 | -0.25 ns (σ 内) |
| js | branch | 10.03 ns ± 0.66 | 10.32 ns ± 1.01 | +0.29 ns (σ 内) |
| js | mask | 829.77 ns ± 22.20 | 813.85 ns ± 17.79 | -15.92 ns (σ 内) |

`select_branch` は native / wasm-gc で僅差が σ 外、js では σ 内。
`select_mask` は全ターゲットで σ 内。

## 解釈 (推論として明記)

以下は観察と整合的な解釈であり、断定ではない。

1. **`bytes_eq_naive` は使用不可**。秘密に依存する `if` で early-return
   する素朴実装は、3 ターゲットすべてで wall-clock に明白な leak を生む。
   サイズが大きいほど比率も大きい (1KB で最大 80×)。

2. **`bytes_eq_xorfold` は今回の解像度では leak が検出されなかった**。
   これは「現在の moon 0.1.20260417 / 各バックエンドで XOR-fold が
   秘密非依存にコード生成されている可能性が高い」と整合する。
   ただし以下は未検証:
   - 生成された native asm / wasm bytecode を読んで branch 不在を確認していない
   - cache-timing 系 (秘密 index による table lookup 等) は wall-clock では出にくい
   - 将来の compiler / V8 / LLVM 更新で regress する可能性は塞げない

3. **言語仕様レベルの保証はない**。MoonBit の公式仕様 / リファレンスに
   constant-time 意味論の規定があるかは確認した範囲では見つからなかった。
   仮に今のコード生成が CT であっても、それは実装事実であって契約ではない。

## 限界

- wall-clock ベンチ (`@bench.T`) のみ。cache-timing / branch predictor 状態
  などのマイクロアーキ的 leak は検出範囲外。
- 統計手法は mean ± σ 比較のみ。dudect 的な Welch t 検定や fixed-vs-random
  の枠組みは未適用。
- 1 ホスト 1 構成での測定。turbo boost / SMT / governor の影響は除外していない。
- 対象は `bytes_eq` と単純 select の 2 種のみ。secp256k1 で本当に問題になる
  modular inverse / scalar multiplication ladder は未測定。

## 追加実験: dudect 風 Welch t 検定

### 動機

前節の bench (10 batches × 100000 runs, mean ± σ 比較) では `xorfold` が
σ 内に収まり「leak 検出なし」と判定されたが、サンプル数を増やせば微小差を
拾える可能性がある。dudect (Reparaz et al., 2017) の手法に従い、
固定入力を 2 クラス (early_diff vs all_eq) で多数バッチ計測し、Welch t 検定を行う。

### 実装

`cttest/dudect.mbt`. デフォルト設定:
- batch_size = 5000 calls / 1 batch
- n_batches  = 200
- warmup_batches = 20
- crop_top_pct = 5.0 (preemption / GC outlier 除去)
- threshold = |t| > 4.5 で leak 認定

`@bench.monotonic_clock_*` を直接呼び、batch 毎の per-call mean を 1 サンプルとし、
2 クラス間で Welch t を計算。

### 結果 (native --release)

| ケース | mean_a | mean_b | t |
|---|---|---|---|
| sanity-same-closure (同一 fn 参照) | 19.51 ns | 19.46 ns | 0.37 |
| sanity-twin-closures (別オブジェクト同一中身) | 18.81 ns | 18.64 ns | **6.78** |
| naive 1KB | 18.89 ns | 2278.7 ns | **-2415** |
| naive 32B | 18.67 ns | 92.04 ns | **-799** |
| xorfold 1KB | 3047.5 ns | 3028.9 ns | 5.82 |
| xorfold 32B | 116.32 ns | 115.83 ns | 2.77 |
| select_branch 32B | 14.12 ns | 14.71 ns | **-12.99** |
| select_mask 32B | 659.41 ns | 658.89 ns | 1.22 |

### クロスターゲット (sanity)

| target | sanity-same-closure | sanity-twin-closures |
|---|---|---|
| native | t=0.37 | **t=6.78** |
| wasm-gc | t=0.26 | **t=-5.56** |
| js | t=1.16 | t=0.61 |

### 観察

1. **同一クロージャ参照の sanity は 3 ターゲットすべてで |t| < 4.5**。
   フレームワーク自体は健全。
2. **異なるクロージャオブジェクト同士で同一中身を比較すると、native と
   wasm-gc で |t| > 4.5 が再現する**。js では出ない。
3. naive のリーク信号 (|t| ≈ 800–2400) はノイズ床 (≈ 6.8) の 100× 以上で、
   ノイズと識別可能。
4. xorfold 1KB の |t|=5.82 は twin-closure ノイズ床 (6.78) とほぼ同等。
5. select_branch 32B の |t|=12.99 はノイズ床の約 2 倍。

### 解釈 (推論)

異なるクロージャ間の系統的タイミング差は、(i) JIT/AOT が個別クロージャ毎に
異なるコード経路を生成する、(ii) 命令キャッシュの配置差、(iii) 分岐予測器の状態差、
などが整合的な仮説。実測は wall-clock のみのため断定はできない。

実用上の含意:
- **naive のような明白なリークは確実に検出できる** (S/N が大きい)
- **微小リーク (|t| ≲ 10) は本フレームワーク (異なるクロージャ間比較) では
  signal と setup-noise を分離できない**
- すなわち xorfold 1KB の結果は「leak が無いことを証明したわけでも、
  leak があることを証明したわけでもない」
- secp256k1 で問題になる timing 差はしばしば数 ns オーダー。
  本フレームワークの解像度ではそうした微小リークの検出は不可能

### 限界 (追記)

- フレームワークのノイズ床はターゲット依存 (native/wasm-gc で大、js で小)。
- C 系の dudect は同一関数に異なるデータを流せるが、MoonBit では
  入力毎にクロージャを生成する必要があり、クロージャ識別子に起因する
  余剰タイミング差を排除できない。
- 真に微小なリークの検証には、生成コード (LLVM IR / wasm bytecode) を
  読むか、ctgrind / TIMECOP 等の動的 taint 検査を併用する必要がある。

## 再現方法

```fish
cd ~/.ghq/github.com/skmtkytr/ethbit
# 単純 bench (mean ± σ)
moon bench --target native  -p skmtkytr/ethbit/cttest --release
moon bench --target wasm-gc -p skmtkytr/ethbit/cttest --release
moon bench --target js      -p skmtkytr/ethbit/cttest --release

# dudect 風 Welch t 検定
moon test --target native  --release -p skmtkytr/ethbit/cttest -F 'dudect*'
moon test --target wasm-gc --release -p skmtkytr/ethbit/cttest -F 'dudect*'
moon test --target js      --release -p skmtkytr/ethbit/cttest -F 'dudect*'
```

ソース:
- `cttest/cttest.mbt` (対象実装)
- `cttest/cttest_test.mbt` (整合性テスト)
- `cttest/cttest_bench_test.mbt` (mean ± σ ベンチ)
- `cttest/dudect.mbt` (Welch t 検定フレームワーク)
- `cttest/cttest_dudect_test.mbt` (dudect テスト)
