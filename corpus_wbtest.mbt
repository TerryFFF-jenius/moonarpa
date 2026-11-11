///|
test "corpus aggregates likelihood and handles empty lines" {
  let m = toy()
  let score = m.corpus([["a"], ["a", "z"]])
  assert_eq(score.sentences, 2)
  assert_eq(score.predicted, 5)
  assert_eq(score.oov_count, 1)
  near(score.oov_rate().unwrap(), 0.2)
  near(
    score.log_probability,
    score.sentence_scores[0].log_probability +
    score.sentence_scores[1].log_probability,
  )
  assert_eq(m.score_lines("a\n\na\n").sentences, 3)
  assert_eq(m.score_lines("").perplexity(), None)
}
