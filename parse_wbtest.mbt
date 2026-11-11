///|
test "ARPA parse CRLF comments sparse orders and infinity" {
  let m = parse(
    "# model\r\n\\data\\\r\nngram 1=2\r\nngram 2=0\r\n\\1-grams:\r\n-inf <s> 0\r\n-0.1 x\r\n\\2-grams:\r\n\\end\\\r\n",
  )
  assert_eq(m.counts(), [2, 0])
  assert_eq(m.record(["<s>"]).unwrap().log_probability, @double.neg_infinity)
}

///|
test "ARPA malformed section and count matrix" {
  let inputs = [
    "", "\\data\\\nngram 1=1\n\\1-grams:\n-1 a\n", "\\data\\\nngram 1=2\n\\1-grams:\n-1 a\n\\end\\",
    "\\data\\\nngram 2=0\n\\end\\", "\\data\\\nngram 1=1\n\\1-grams:\n-1 a\n\\end\\\nextra",
    "\\data\\\nngram 1=1\n\\1-grams:\n-1 a 0\n\\end\\",
  ]
  for text in inputs {
    assert_true(
      try {
        let _ = parse(text)
        false
      } catch {
        _ => true
      },
    )
  }
}

///|
test "ARPA allocation limits apply before processing" {
  assert_true(
    try {
      let _ = parse("\\data\\\nngram 1=999999999\n")
      false
    } catch {
      Budget(_) => true
      _ => false
    },
  )
  assert_true(
    try {
      let _ = parse("12345", limits={ ..Limits::default(), max_text: 4, })
      false
    } catch {
      Budget(_) => true
      _ => false
    },
  )
}
