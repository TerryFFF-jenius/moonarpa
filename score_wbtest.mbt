///|
fn near(
  actual : Double,
  expected : Double,
  tolerance~ : Double = 1.0e-10,
) -> Unit raise {
  assert_true(actual == expected || (actual - expected).abs() < tolerance)
}

///|
test "explicit, backed-off, OOV and history truncation" {
  let m = toy()
  near(m.conditional(["<s>"], "a").log_probability, -0.09691001300805639)
  let b = m.conditional(["a"], "b")
  near(b.log_probability, -1.1249387366083)
  assert_eq(b.matched_order, 1)
  assert_eq(b.backoff_steps, 1)
  assert_true(m.conditional(["a"], "not_in_vocab").oov)
  near(m.conditional(["b", "a"], "b").log_probability, b.log_probability)
  assert_true(
    try {
      let _ = m.conditional([], "z", oov=Reject)
      false
    } catch {
      Missing(_) => true
      _ => false
    },
  )
}

///|
test "multi-level backoff includes only missing contexts" {
  let m = Model::new(3, [
    { tokens: ["a"], log_probability: -0.3, log_backoff: Some(-0.2), },
    { tokens: ["b"], log_probability: -0.4, log_backoff: Some(-0.5), },
    { tokens: ["a", "b"], log_probability: -0.1, log_backoff: Some(-0.7), },
  ])
  near(m.conditional(["a", "b"], "a").log_probability, -1.5)
  near(m.conditional(["b", "b"], "a").log_probability, -0.8)
}
