///|
test "discount probabilities conserve mass at seen and unseen histories" {
  let m = count_corpus([["a", "b"], ["a"], ["b", "a"]], 3).train_discount()
  for
    history in [[], ["<s>"], ["a"], ["b"], ["<s>", "a"], ["b", "b"], ["a", "b"]] {
    let mut mass = 0.0
    for word in m.vocabulary() {
      mass += @math.pow(
        10.0,
        m.conditional(history, word, oov=Reject).log_probability,
      )
    }
    near(mass, 1.0)
  }
  assert_true(
    m.conditional(["<s>", "a"], "new_word").log_probability >
    @double.neg_infinity,
  )
  let empty = count_corpus([], 3).train_discount()
  near(@math.pow(10.0, empty.conditional([], "</s>").log_probability), 0.5)
}
