///|
test "mixture normalizes weights and combines probabilities" {
  let a = Model::new(1, [
    { tokens: ["x"], log_probability: -0.3010299956639812, log_backoff: None, },
  ])
  let b = Model::new(1, [
    { tokens: ["x"], log_probability: -1.0, log_backoff: None, },
  ])
  let mix = Mixture::new([a, b], [1.0, 3.0])
  near(mix.conditional([], "x"), @math.log10(0.2))
  assert_eq(mix.weights(), [0.25, 0.75])
  let same = Mixture::new([toy(), toy()], [1.0, 0.0])
  near(
    same.sentence(["a"]).log_probability,
    toy().sentence(["a"]).log_probability,
  )
  assert_true(
    try {
      let _ = Mixture::new([a, b], [0.0, 0.0])
      false
    } catch {
      Invalid(_) => true
      _ => false
    },
  )
}
