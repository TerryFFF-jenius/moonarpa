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

///|
test "stream cumulative retained text budget is atomic across forks and reset" {
  let m = Model::new(
    1,
    [{ tokens: ["<unk>"], log_probability: 0.0, log_backoff: None, }],
    limits={ ..Limits::default(), max_text: 10, },
  )
  let s = m.scorer(options={ bos: false, eos: false, oov: MapToUnknown, })
  let _ = s.feed("aaaaaa")
  let before = s.snapshot()
  assert_true(
    try {
      let _ = s.feed("bbbbb")
      false
    } catch {
      Budget(_) => true
      _ => false
    },
  )
  assert_eq(s.snapshot(), before)
  assert_true(
    try {
      let _ = s.feed_batch(["bb", "ccc"])
      false
    } catch {
      Budget(_) => true
      _ => false
    },
  )
  assert_eq(s.snapshot(), before)
  let fork = s.fork()
  let _ = fork.feed("bbbb")
  assert_true(
    try {
      let _ = fork.feed("c")
      false
    } catch {
      Budget(_) => true
      _ => false
    },
  )
  assert_eq(s.snapshot(), before)
  s.reset()
  let _ = s.feed("abcdefghij")
  assert_eq(s.finish().predicted, 1)
}
