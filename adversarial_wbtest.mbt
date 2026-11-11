///|
test "positive backoff is legal and finite overflow is rejected" {
  let m = Model::new(2, [
    { tokens: ["a"], log_probability: -5.0, log_backoff: Some(3.0), },
    { tokens: ["b"], log_probability: -4.0, log_backoff: None, },
  ])
  near(m.conditional(["a"], "b").log_probability, -1.0)
  let huge = Model::new(2, [
    { tokens: ["a"], log_probability: -1.0e308, log_backoff: Some(-1.0e308), },
  ])
  assert_true(
    try {
      let _ = huge.conditional(["a"], "a")
      false
    } catch {
      Invalid(_) => true
      _ => false
    },
  )
  assert_true(
    try {
      let _ = add_log(-1.0e308, -1.0e308)
      false
    } catch {
      Invalid(_) => true
      _ => false
    },
  )
}

///|
test "tight resource boundaries reject oversized data before work" {
  let limits = {
    max_order: 2,
    max_records: 10,
    max_text: 100,
    max_tokens: 5,
    max_work: 10,
  }
  let m = Model::new(
    1,
    [{ tokens: ["a"], log_probability: 0.0, log_backoff: None, }],
    limits~,
  )
  assert_true(
    try {
      let _ = m.conditional(["a", "a", "a", "a", "a", "a"], "a")
      false
    } catch {
      Budget(_) => true
      _ => false
    },
  )
  assert_true(
    try {
      let _ = count_corpus([["a", "b", "c"]], 2, limits={
        ..limits,
        max_work: 2,
      })
      false
    } catch {
      Budget(_) => true
      _ => false
    },
  )
  assert_true(
    try {
      let _ = Model::new(1, [
        { tokens: ["a\u{001f}b"], log_probability: 0.0, log_backoff: None, },
      ])
      false
    } catch {
      Invalid(_) => true
      _ => false
    },
  )
  assert_true(
    try {
      let _ = execute("[]")
      false
    } catch {
      Invalid(_) => true
      _ => false
    },
  )
}

///|
test "canonical parser is stable over generated order and corpus variations" {
  for order = 1; order <= 8; order = order + 1 {
    for size = 0; size <= 10; size = size + 1 {
      let tokens = []
      for i = 0; i < size; i = i + 1 {
        tokens.push(if i % 2 == 0 { "a" } else { "b" })
      }
      let m = count_corpus([tokens, []], order).train_discount()
      let text = m.to_arpa()
      assert_eq(parse(text).to_arpa(), text)
      assert_true(m.audit_mass(["<unk>", "<unk>"]).normalized)
      near(
        m.sentence(tokens).log_probability,
        parse(text).sentence(tokens).log_probability,
      )
    }
  }
}

///|
test "impossible sequences and zero LM weights avoid NaN" {
  let m = count_corpus([["a"]], 2).train_mle()
  let score = m.sentence(["a", "a"])
  assert_eq(score.perplexity(), Some(@double.infinity))
  let ranking = m.rescore(
    [{ id: "x", tokens: ["a", "a"], acoustic_score: -1.0, }],
    options={
      lm_weight: 0.0,
      acoustic_weight: 1.0,
      length_weight: 0.0,
      scoring: ScoreOptions::default(),
    },
  )
  near(ranking[0].score, -1.0)
  let s = count_corpus([["a"]], 1).train_discount().scorer()
  let _ = s.feed("a")
  assert_eq(s.history(), [])
}
