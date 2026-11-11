///|
test "canonical ARPA roundtrip preserves records and counts" {
  let m = toy()
  let text = m.to_arpa()
  let restored = parse(text)
  assert_eq(restored.counts(), m.counts())
  for record in m.records() {
    assert_eq(restored.record(record.tokens), Some(record))
  }
  assert_eq(restored.to_arpa(), text)
}

///|
test "writer preserves positive and minus-infinite backoff" {
  let m = Model::new(2, [
    { tokens: ["x"], log_probability: -0.1, log_backoff: Some(2.0), },
    {
      tokens: ["y"],
      log_probability: @double.neg_infinity,
      log_backoff: Some(@double.neg_infinity),
    },
  ])
  let restored = parse(m.to_arpa())
  assert_eq(restored.record(["x"]), m.record(["x"]))
  assert_eq(restored.record(["y"]), m.record(["y"]))
}
