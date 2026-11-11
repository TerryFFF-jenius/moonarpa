///|
test "lexical numbers and collision-safe tokens" {
  assert_eq(words(" a\t你好\r\nb "), ["a", "你好", "b"])
  assert_true(token_valid("<unk>"))
  assert_false(token_valid("a\u{001f}b"))
  assert_false(token_valid("a b"))
  assert_eq(parse_number("-inf", 1), @double.neg_infinity)
  assert_eq(parse_number("-0.25", 1), -0.25)
  assert_eq(positive_count("0", 1), 0)
  Limits::default().validate()
}

///|
test "malformed lexical values rejected" {
  assert_true(
    try {
      let _ = parse_number("nan", 2)
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      let _ = positive_count("-1", 2)
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      { ..Limits::default(), max_order: 9, }.validate()
      false
    } catch {
      _ => true
    },
  )
}
