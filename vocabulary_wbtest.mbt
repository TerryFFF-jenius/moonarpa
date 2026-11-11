///|
test "vocabulary fitting is deterministic and heldout mapping is frozen" {
  let v = fit_vocabulary([["z", "b", "a"], ["a", "b"]], options={
    min_count: 1,
    max_vocabulary: 4,
  })
  assert_true(v.contains("a"))
  assert_true(!v.contains("b"))
  assert_eq(v.training_tokens(), 5)
  assert_eq(v.removed_types(), 2)
  let mapped = v.transform([["a", "b", "new"]])
  assert_eq(mapped.sentences, [["a", "<unk>", "<unk>"]])
  assert_eq(mapped.replaced, 2)
  let m = count_corpus(mapped.sentences, 2).train_discount()
  assert_true(m.audit_mass(["a"]).normalized)
}
