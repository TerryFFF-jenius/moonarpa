///|
test "MLE preserves empirical conditionals and normalizes unigrams" {
  let c = count_corpus([["a", "b"], ["a"]], 2)
  let m = c.train_mle()
  near(m.conditional(["<s>"], "a").log_probability, 0.0)
  near(m.conditional(["a"], "b").log_probability, @math.log10(0.5))
  assert_eq(m.conditional(["a"], "<unk>").log_probability, @double.neg_infinity)
  let mut mass = 0.0
  for word in m.vocabulary() {
    mass += @math.pow(10.0, m.conditional([], word).log_probability)
  }
  near(mass, 1.0)
  assert_eq(
    parse(m.to_arpa()).records(),
    parse(parse(m.to_arpa()).to_arpa()).records(),
  )
}
