///|
test "stream fork finish reset and atomic failures" {
  let m = toy()
  let s = m.scorer(options={ bos: true, eos: true, oov: Reject, })
  let _ = s.feed("a")
  let fork = s.fork()
  let before = s.snapshot()
  assert_true(
    try {
      let _ = s.feed_batch(["b", "missing"])
      false
    } catch {
      Missing(_) => true
      _ => false
    },
  )
  assert_eq(s.snapshot(), before)
  assert_eq(s.finish(), m.sentence(["a"]))
  assert_eq(s.finish(), s.snapshot())
  let _ = fork.feed("b")
  assert_eq(fork.finish().predicted, 3)
  s.reset()
  assert_true(!s.is_closed())
  assert_eq(s.history(), ["<s>"])
}
