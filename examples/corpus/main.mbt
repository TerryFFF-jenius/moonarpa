///|
fn main raise {
  let training = [["red", "bird"], ["red", "bird"], ["blue", "bird"]]
  let vocab = @arpa.fit_vocabulary(training, options={
    min_count: 2,
    max_vocabulary: 100,
  })
  let mapped = vocab.transform(training)
  let model = @arpa.count_corpus(mapped.sentences, 3).train_discount()
  let heldout = vocab.transform([["red", "bird"], ["green", "bird"]])
  assert_eq(heldout.replaced, 1)
  let score = model.corpus(heldout.sentences)
  assert_eq(score.predicted, 6)
  println(score.to_json().stringify())
}
