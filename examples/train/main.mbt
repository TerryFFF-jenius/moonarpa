///|
fn main raise {
  let left = @arpa.count_corpus([["a", "small", "model"]], 3)
  let right = @arpa.count_corpus([["a", "portable", "model"]], 3)
  let model = left.merge(right).train_discount()
  let restored = @arpa.parse(model.to_arpa())
  for report in restored.audit_contexts(32) {
    assert_true(report.normalized)
  }
  let scorer = restored.scorer()
  let _ = scorer.feed_batch(["a", "small"])
  let branch = scorer.fork()
  let _ = branch.feed("model")
  assert_eq(branch.finish(), restored.sentence(["a", "small", "model"]))
  println(restored.summary().to_json().stringify())
}
