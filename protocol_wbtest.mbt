///|
test "protocol trains scores and rejects unknown fields and nesting" {
  let trained = decode_object(
    execute("{\"op\":\"train\",\"sentences\":[[\"a\"]],\"order\":2}"),
  )
  let request = json_object([
    ("op", Json::string("score")),
    ("arpa", required(trained, "arpa")),
    ("tokens", Json::array([Json::string("a")])),
  ])
  let score = decode_object(execute(request.stringify()))
  assert_eq(decode_int(required(score, "predicted")), 2)
  let failed = decode_object(
    @json.parse(
      handle("{\"op\":\"train\",\"sentences\":[],\"order\":2,\"typo\":1}"),
    ),
  )
  assert_eq(required(failed, "ok"), Json::boolean(false))
  assert_eq(
    required(decode_object(@json.parse(handle("{}"))), "ok"),
    Json::boolean(false),
  )
}
