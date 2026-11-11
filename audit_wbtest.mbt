///|
test "mass audit distinguishes valid syntax from normalized probabilities" {
  assert_true(!toy().audit_mass(["<s>"]).normalized)
  let m = count_corpus([["a", "b"], ["a"]], 3).train_discount()
  for report in m.audit_contexts(20) {
    assert_true(report.normalized)
  }
  assert_eq(m.summary().counts, m.counts())
  assert_true(m.summary().has_unknown)
  let s = m.sentence(["a"])
  near(s.cross_entropy_bits().unwrap(), @math.log2(s.perplexity().unwrap()))
}
