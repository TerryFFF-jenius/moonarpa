///|
test "merged shards equal full corpus counts and model" {
  let a = count_corpus([["a", "b"]], 3)
  let b = count_corpus([["b", "a"], []], 3)
  let merged = a.merge(b)
  let full = count_corpus([["a", "b"], ["b", "a"], []], 3)
  assert_eq(merged.train_discount().to_arpa(), full.train_discount().to_arpa())
  assert_eq(merged.sentence_count(), 3)
  assert_eq(merged.continuations(["<s>"]).length(), 3)
  assert_eq(a.count(["b"]), 1)
}
