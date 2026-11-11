///|
test "JSON reports roundtrip and encode impossible numbers explicitly" {
  let score = toy().sentence(["a"])
  let text = score.to_json().stringify()
  assert_eq(@json.parse(text), score.to_json())
  assert_eq(json_number(@double.neg_infinity), Json::string("-Infinity"))
  assert_eq(json_number(@double.infinity), Json::string("Infinity"))
  assert_true(
    try {
      let _ = decode_int(Json::number(1.5))
      false
    } catch {
      Invalid(_) => true
      _ => false
    },
  )
  assert_eq(decode_sentences(@json.parse("[[\"a\"],[]]"), Limits::default()), [
    ["a"],
    [],
  ])
}
