///|
fn main raise {
  let model = @arpa.count_corpus(
    [
      ["open", "the", "door"],
      ["open", "the", "door"],
      ["close", "the", "window"],
    ],
    3,
  ).train_discount()
  let ranked = model.rescore([
    {
      id: "decoder-1",
      tokens: ["open", "the", "window"],
      acoustic_score: -0.1,
    },
    { id: "decoder-2", tokens: ["open", "the", "door"], acoustic_score: -0.2, },
  ])
  assert_eq(ranked[0].id, "decoder-2")
  println(ranked[0].to_json().stringify())
}
