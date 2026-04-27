test "bench keccak256 32B" (it : @bench.T) {
  let input = Bytes::make(32, b'\x42')
  it.bench(fn() { it.keep(@keccak.keccak256(input)) })
}

test "bench keccak256 136B (= 1 block)" (it : @bench.T) {
  let input = Bytes::make(136, b'\x42')
  it.bench(fn() { it.keep(@keccak.keccak256(input)) })
}

test "bench keccak256 1KB" (it : @bench.T) {
  let input = Bytes::make(1024, b'\x42')
  it.bench(fn() { it.keep(@keccak.keccak256(input)) })
}

test "bench keccak256 64KB" (it : @bench.T) {
  let input = Bytes::make(65536, b'\x42')
  it.bench(fn() { it.keep(@keccak.keccak256(input)) })
}
