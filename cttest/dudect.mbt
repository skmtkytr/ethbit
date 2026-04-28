// dudect-style timing leak detection.
//
// Methodology (Reparaz et al., 2017):
//   - Two input classes A and B (e.g. all-zero vs all-FF).
//   - Many batches of `batch_size` calls per class, interleaved.
//   - Crop top percentile of each (preemption / GC outliers).
//   - Welch's t-test on batch-mean timings.
//   - |t| > threshold => the function leaks input-class info via timing.
//
// We measure per-batch (not per-call) because reading the clock itself costs
// tens of ns, which would dominate per-call cost for our targets. With
// batch_size = k, the batch-mean σ shrinks by √k, giving us power to detect
// small per-call differences.
//
// This is NOT a constant-time proof. A null result means "no leak detected
// at this resolution, this run, this target". A positive result is conclusive.

///|
pub(all) struct CtResult {
  name : String
  n_batches : Int
  batch_size : Int
  mean_a_us : Double // microseconds per call
  mean_b_us : Double
  std_a_us : Double
  std_b_us : Double
  t : Double
  threshold : Double
  leak_detected : Bool
}

///|
pub impl Show for CtResult with output(self, logger) {
  logger.write_string("CtResult{")
  logger.write_string(self.name)
  logger.write_string(": t=")
  logger.write_object(self.t)
  logger.write_string(" thr=")
  logger.write_object(self.threshold)
  logger.write_string(" leak=")
  logger.write_object(self.leak_detected)
  logger.write_string(" mean_a=")
  logger.write_object(self.mean_a_us)
  logger.write_string("us mean_b=")
  logger.write_object(self.mean_b_us)
  logger.write_string("us}")
}

///|
/// Run f exactly k times and return the elapsed wall-clock in microseconds.
fn time_batch(f : () -> Unit, k : Int) -> Double {
  let ts = @bench.monotonic_clock_start()
  for _ in 0..<k {
    f()
  }
  @bench.monotonic_clock_end(ts)
}

///|
/// Welch's two-sample t-statistic on summary stats.
fn welch_t(
  mean_a : Double, std_a : Double, n_a : Int,
  mean_b : Double, std_b : Double, n_b : Int,
) -> Double {
  let va = std_a * std_a / n_a.to_double()
  let vb = std_b * std_b / n_b.to_double()
  let denom = (va + vb).sqrt()
  if denom == 0.0 {
    0.0
  } else {
    (mean_a - mean_b) / denom
  }
}

///|
fn mean_stddev(data : Array[Double]) -> (Double, Double) {
  let n = data.length()
  if n == 0 {
    return (0.0, 0.0)
  }
  let mut s = 0.0
  for v in data {
    s = s + v
  }
  let mean = s / n.to_double()
  if n < 2 {
    return (mean, 0.0)
  }
  let mut sq = 0.0
  for v in data {
    let d = v - mean
    sq = sq + d * d
  }
  let variance = sq / (n - 1).to_double()
  (mean, variance.sqrt())
}

///|
/// Drop the top `pct`% of values (ascending sort, keep low (100-pct)%).
/// Removes preemption / page-fault / GC outliers.
fn crop_top(data : Array[Double], pct : Double) -> Array[Double] {
  let n = data.length()
  let sorted : Array[Double] = Array::make(n, 0.0)
  for i = 0; i < n; i = i + 1 {
    sorted[i] = data[i]
  }
  sorted.sort()
  let drop = (n.to_double() * pct / 100.0).to_int()
  let kept = n - drop
  let out : Array[Double] = Array::make(kept, 0.0)
  for i = 0; i < kept; i = i + 1 {
    out[i] = sorted[i]
  }
  out
}

///|
/// Compare timings of `fa` and `fb` (two closures bound to distinct inputs).
/// Returns Welch's t and a leak verdict.
///
/// Defaults are tuned for fast functions (~tens of ns):
///   - batch_size = 5000 (calls per timed batch)
///   - n_batches = 200   (sample count per class, post-crop)
///   - warmup_batches = 20
///   - crop_top_pct = 5.0
///   - threshold = 4.5 (≈ p < 1e-5 at this df; dudect convention)
pub fn dudect_compare(
  name : String,
  fa : () -> Unit,
  fb : () -> Unit,
  batch_size~ : Int = 5000,
  n_batches~ : Int = 200,
  warmup_batches~ : Int = 20,
  threshold~ : Double = 4.5,
  crop_top_pct~ : Double = 5.0,
) -> CtResult {
  for _ in 0..<warmup_batches {
    let _ = time_batch(fa, batch_size)
    let _ = time_batch(fb, batch_size)

  }
  let sa : Array[Double] = Array::make(n_batches, 0.0)
  let sb : Array[Double] = Array::make(n_batches, 0.0)
  let bs_d = batch_size.to_double()
  for i = 0; i < n_batches; i = i + 1 {
    if i % 2 == 0 {
      sa[i] = time_batch(fa, batch_size) / bs_d
      sb[i] = time_batch(fb, batch_size) / bs_d
    } else {
      sb[i] = time_batch(fb, batch_size) / bs_d
      sa[i] = time_batch(fa, batch_size) / bs_d
    }
  }
  let sa_c = crop_top(sa, crop_top_pct)
  let sb_c = crop_top(sb, crop_top_pct)
  let (ma, da) = mean_stddev(sa_c)
  let (mb, db) = mean_stddev(sb_c)
  let t = welch_t(ma, da, sa_c.length(), mb, db, sb_c.length())
  {
    name,
    n_batches: sa_c.length(),
    batch_size,
    mean_a_us: ma,
    mean_b_us: mb,
    std_a_us: da,
    std_b_us: db,
    t,
    threshold,
    leak_detected: t.abs() > threshold,
  }
}
