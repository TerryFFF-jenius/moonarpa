///|
test "nbest stable ties weights and duplicate rejection" {
  let m = toy()
  let hypotheses = [
    { id: "first", tokens: ["a"], acoustic_score: -1.0, },
    { id: "second", tokens: ["b"], acoustic_score: -1.0, },
  ]
  assert_eq(m.rescore(hypotheses)[0].id, "first")
  let ties = m.rescore(hypotheses, options={
    lm_weight: 0.0,
    acoustic_weight: 1.0,
    length_weight: 0.0,
    scoring: ScoreOptions::default(),
  })
  assert_eq(ties[0].input_index, 0)
  assert_true(
    try {
      let _ = m.rescore([hypotheses[0], hypotheses[0]])
      false
    } catch {
      Invalid(_) => true
      _ => false
    },
  )
}
