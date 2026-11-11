///|
test "prediction is sorted stable bounded and filters BOS" {
  let m = toy()
  let top = m.predict(["<s>"], 2)
  assert_eq(top[0].token, "a")
  assert_eq(top[1].token, "</s>")
  assert_eq(m.predict([], 0), [])
  assert_eq(m.rank_candidates([], ["b", "a", "a"])[0].token, "a")
  assert_eq(m.predict([], 100).length(), 4)
}
