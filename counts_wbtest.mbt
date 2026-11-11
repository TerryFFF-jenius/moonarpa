///|
test "count windows include BOS history and EOS events only" {
  let c = count_corpus([["a", "b"], ["a"]], 3)
  assert_eq(c.count(["a"]), 2)
  assert_eq(c.count(["<s>"]), 0)
  assert_eq(c.count(["</s>"]), 2)
  assert_eq(c.count(["<s>", "a", "b"]), 1)
  assert_eq(c.count(["a", "</s>"]), 1)
  assert_eq(c.token_count(), 5)
  let rows = c.records()
  rows[0].tokens[0] = "mutated"
  assert_eq(c.count(["<s>"]), 0)
  assert_true(c.vocabulary().contains("<s>"))
}
