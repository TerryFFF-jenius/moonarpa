///|
fn json_object(fields : Array[(String, Json)]) -> Json {
  Json::object(Map(fields))
}

///|
/// JSON has no infinities: finite values are numbers; infinities are strings.
fn json_number(value : Double) -> Json {
  if value == @double.neg_infinity {
    Json::string("-Infinity")
  } else if value == @double.infinity {
    Json::string("Infinity")
  } else {
    Json::number(value)
  }
}

///|
fn json_optional(value : Double?) -> Json {
  match value {
    Some(number) => json_number(number)
    None => Json::null()
  }
}

///|
pub fn TokenScore::to_json(self : TokenScore) -> Json {
  json_object([
    ("token", Json::string(self.token)),
    ("mapped", Json::string(self.mapped)),
    ("log10_probability", json_number(self.log_probability)),
    ("matched_order", Json::number(self.matched_order.to_double())),
    ("backoff_steps", Json::number(self.backoff_steps.to_double())),
    ("backoff_log10", json_number(self.backoff_log)),
    ("oov", Json::boolean(self.oov)),
  ])
}

///|
pub fn SentenceScore::to_json(self : SentenceScore) -> Json {
  json_object([
    ("log10_probability", json_number(self.log_probability)),
    ("predicted", Json::number(self.predicted.to_double())),
    ("oov_count", Json::number(self.oov_count.to_double())),
    ("perplexity", json_optional(self.perplexity())),
    ("cross_entropy_bits", json_optional(self.cross_entropy_bits())),
    ("tokens", Json::array(self.tokens.map(t => t.to_json()))),
  ])
}

///|
pub fn CorpusScore::to_json(self : CorpusScore) -> Json {
  json_object([
    ("sentences", Json::number(self.sentences.to_double())),
    ("predicted", Json::number(self.predicted.to_double())),
    ("oov_count", Json::number(self.oov_count.to_double())),
    ("impossible_sentences", Json::number(self.impossible.to_double())),
    ("log10_probability", json_number(self.log_probability)),
    ("perplexity", json_optional(self.perplexity())),
    ("oov_rate", json_optional(self.oov_rate())),
    ("sentence_scores", Json::array(self.sentence_scores.map(s => s.to_json()))),
  ])
}

///|
pub fn Prediction::to_json(self : Prediction) -> Json {
  json_object([
    ("token", Json::string(self.token)),
    ("log10_probability", json_number(self.log_probability)),
    ("matched_order", Json::number(self.matched_order.to_double())),
  ])
}

///|
pub fn RankedHypothesis::to_json(self : RankedHypothesis) -> Json {
  json_object([
    ("id", Json::string(self.id)),
    ("input_index", Json::number(self.input_index.to_double())),
    ("score", json_number(self.score)),
    ("language", self.language.to_json()),
  ])
}

///|
pub fn MassAudit::to_json(self : MassAudit) -> Json {
  json_object([
    ("history", Json::array(self.history.map(Json::string))),
    ("mass", json_number(self.mass)),
    ("deviation", json_number(self.deviation)),
    ("normalized", Json::boolean(self.normalized)),
    ("zero_events", Json::number(self.zero_events.to_double())),
    ("backed_off_events", Json::number(self.backed_off_events.to_double())),
  ])
}

///|
pub fn ModelSummary::to_json(self : ModelSummary) -> Json {
  json_object([
    ("order", Json::number(self.order.to_double())),
    ("records", Json::number(self.records.to_double())),
    ("vocabulary", Json::number(self.vocabulary.to_double())),
    ("counts", Json::array(self.counts.map(n => Json::number(n.to_double())))),
    ("impossible_records", Json::number(self.impossible_records.to_double())),
    ("positive_backoffs", Json::number(self.positive_backoffs.to_double())),
    ("has_unknown", Json::boolean(self.has_unknown)),
    ("has_bos", Json::boolean(self.has_bos)),
    ("has_eos", Json::boolean(self.has_eos)),
  ])
}

///|
fn decode_object(json : Json) -> Map[String, Json] raise ArpaError {
  match json {
    Object(fields) => fields
    _ => raise Invalid("expected JSON object")
  }
}

///|
fn required(fields : Map[String, Json], key : String) -> Json raise ArpaError {
  match fields.get(key) {
    Some(value) => value
    None => raise Missing("JSON field: " + key)
  }
}

///|
fn decode_string(json : Json) -> String raise ArpaError {
  match json {
    String(s) => s
    _ => raise Invalid("expected JSON string")
  }
}

///|
fn decode_int(json : Json) -> Int32 raise ArpaError {
  match json {
    Number(n, ..) => {
      if !finite_number(n) || n < 0.0 || n > 2147483647.0 || @math.floor(n) != n {
        raise Invalid("expected nonnegative bounded integer")
      }
      n.to_int()
    }
    _ => raise Invalid("expected JSON integer")
  }
}

///|
fn decode_double(json : Json) -> Double raise ArpaError {
  match json {
    Number(n, ..) =>
      if finite_number(n) {
        n
      } else {
        raise Invalid("expected finite number")
      }
    _ => raise Invalid("expected JSON number")
  }
}

///|
fn decode_tokens(json : Json, limits : Limits) -> Array[String] raise ArpaError {
  match json {
    Array(items) => {
      if items.length() > limits.max_tokens {
        raise Budget("JSON token limit")
      }
      let result = []
      for item in items {
        let word = decode_string(item)
        if !token_valid(word) {
          raise Invalid("invalid JSON token")
        }
        result.push(word)
      }
      result
    }
    _ => raise Invalid("expected JSON token array")
  }
}

///|
fn decode_sentences(
  json : Json,
  limits : Limits,
) -> Array[Array[String]] raise ArpaError {
  match json {
    Array(items) => {
      if items.length() > limits.max_tokens {
        raise Budget("JSON sentence limit")
      }
      let rows = []
      let mut total = 0
      for item in items {
        let row = decode_tokens(item, limits)
        if row.length() > limits.max_tokens - total {
          raise Budget("JSON corpus token limit")
        }
        total += row.length()
        rows.push(row)
      }
      rows
    }
    _ => raise Invalid("expected JSON sentence array")
  }
}

///|
fn ensure_fields(
  fields : Map[String, Json],
  allowed : Array[String],
) -> Unit raise ArpaError {
  for key, _ in fields {
    if !allowed.contains(key) {
      raise Invalid("unexpected JSON field: " + key)
    }
  }
}
