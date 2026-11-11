///|
test "sentence boundaries counts and perplexity" {
  let s = toy().sentence(["a"])
  assert_eq(s.predicted, 2)
  near(s.log_probability, -0.25181197299379954)
  near(s.perplexity().unwrap(), @math.pow(1.0 / 0.56, 0.5))
  let empty = toy().sentence([], options={
    bos: false,
    eos: false,
    oov: Reject,
  })
  assert_eq(empty.perplexity(), None)
  assert_eq(toy().score_text("  a\n ").tokens.length(), 2)
  assert_true(
    try {
      let _ = toy().sentence(["<s>"])
      false
    } catch {
      Invalid(_) => true
      _ => false
    },
  )
}
