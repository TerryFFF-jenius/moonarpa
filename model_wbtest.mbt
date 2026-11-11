///|
fn toy() -> Model raise ArpaError {
  Model::new(2, [
    {
      tokens: ["<s>"],
      log_probability: -99.0,
      log_backoff: Some(-0.3010299956639812),
    },
    {
      tokens: ["</s>"],
      log_probability: -0.6020599913279624,
      log_backoff: None,
    },
    { tokens: ["<unk>"], log_probability: -1.0, log_backoff: None, },
    {
      tokens: ["a"],
      log_probability: -0.3010299956639812,
      log_backoff: Some(-0.3010299956639812),
    },
    { tokens: ["b"], log_probability: -0.8239087409443188, log_backoff: None, },
    {
      tokens: ["<s>", "a"],
      log_probability: -0.09691001300805639,
      log_backoff: None,
    },
    {
      tokens: ["a", "</s>"],
      log_probability: -0.1549019599857432,
      log_backoff: None,
    },
  ])
}

///|
test "model takes ownership and exposes defensive copies" {
  let m = toy()
  assert_eq(m.order(), 2)
  assert_eq(m.counts(), [5, 2])
  let records = m.records()
  records[0].tokens[0] = "changed"
  assert_true(m.contains("<s>"))
  assert_true(m.record(["<s>"]) is Some(_))
  let vocab = m.vocabulary()
  vocab.clear()
  assert_eq(m.vocabulary().length(), 5)
}

///|
test "model structural failures and positive backoff" {
  assert_true(
    try {
      let _ = Model::new(1, [])
      false
    } catch {
      _ => true
    },
  )
  let r : Gram = { tokens: ["x"], log_probability: -1.0, log_backoff: None, }
  assert_true(
    try {
      let _ = Model::new(1, [r, r])
      false
    } catch {
      _ => true
    },
  )
  let _ = Model::new(2, [{ ..r, log_backoff: Some(3.0), }])
  assert_true(
    try {
      let _ = Model::new(1, [{ ..r, log_probability: 0.1, }])
      false
    } catch {
      _ => true
    },
  )
}
