///|
fn decode_options(value : Json?) -> ScoreOptions raise ArpaError {
  let mut options = ScoreOptions::default()
  match value {
    None => options
    Some(json) => {
      let fields = decode_object(json)
      ensure_fields(fields, ["bos", "eos", "oov"])
      let boolean = fn(value : Json) -> Bool raise ArpaError {
        match value {
          True => true
          False => false
          _ => raise Invalid("expected boolean option")
        }
      }
      let bos = match fields.get("bos") {
        Some(v) => boolean(v)
        None => options.bos
      }
      let eos = match fields.get("eos") {
        Some(v) => boolean(v)
        None => options.eos
      }
      let oov = match fields.get("oov") {
        None => options.oov
        Some(String("map")) => MapToUnknown
        Some(String("reject")) => Reject
        _ => raise Invalid("oov must be map or reject")
      }
      options = { bos, eos, oov, }
      options
    }
  }
}

///|
fn optional_double(
  fields : Map[String, Json],
  key : String,
  fallback : Double,
) -> Double raise ArpaError {
  match fields.get(key) {
    Some(value) => decode_double(value)
    None => fallback
  }
}

///|
fn decode_hypotheses(
  json : Json,
  limits : Limits,
) -> Array[Hypothesis] raise ArpaError {
  match json {
    Array(items) => {
      if items.length() > limits.max_records {
        raise Budget("JSON hypothesis limit")
      }
      let result = []
      for item in items {
        let fields = decode_object(item)
        ensure_fields(fields, ["id", "tokens", "acoustic_score"])
        result.push({
          id: decode_string(required(fields, "id")),
          tokens: decode_tokens(required(fields, "tokens"), limits),
          acoustic_score: decode_double(required(fields, "acoustic_score")),
        })
      }
      result
    }
    _ => raise Invalid("expected hypotheses array")
  }
}

///|
/// Portable, bounded JSON task engine. There is no filesystem or network access.
/// Unknown fields fail instead of silently changing a user's scoring options.
pub fn execute(
  request : String,
  limits~ : Limits = Limits::default(),
) -> Json raise ArpaError {
  limits.validate()
  if request.length() > limits.max_text {
    raise Budget("request text limit")
  }
  let json = @json.parse(request, max_nesting_depth=16) catch {
    _ => raise Invalid("invalid JSON request")
  }
  let fields = decode_object(json)
  let operation = decode_string(required(fields, "op"))
  if operation == "train" {
    ensure_fields(fields, [
      "op", "sentences", "order", "method", "discount", "unigram_prior",
    ])
    let sentences = decode_sentences(required(fields, "sentences"), limits)
    let order = decode_int(required(fields, "order"))
    let method = match fields.get("method") {
      Some(v) => decode_string(v)
      None => "discount"
    }
    let prior = optional_double(fields, "unigram_prior", 0.5)
    let counts = count_corpus(sentences, order, limits~)
    let model = match method {
      "discount" =>
        counts.train_discount(
          discount=optional_double(fields, "discount", 0.75),
          unigram_prior=prior,
        )
      "mle" => {
        if fields.contains("discount") {
          raise Invalid("discount option requires discount method")
        }
        counts.train_mle(unigram_prior=prior)
      }
      _ => raise Invalid("unknown training method")
    }
    return json_object([
      ("arpa", Json::string(model.to_arpa())),
      ("summary", model.summary().to_json()),
    ])
  }
  let model = parse(decode_string(required(fields, "arpa")), limits~)
  match operation {
    "inspect" => {
      ensure_fields(fields, ["op", "arpa"])
      model.summary().to_json()
    }
    "canonicalize" => {
      ensure_fields(fields, ["op", "arpa"])
      json_object([("arpa", Json::string(model.to_arpa()))])
    }
    "score" => {
      ensure_fields(fields, ["op", "arpa", "tokens", "options"])
      model
      .sentence(
        decode_tokens(required(fields, "tokens"), limits),
        options=decode_options(fields.get("options")),
      )
      .to_json()
    }
    "corpus" => {
      ensure_fields(fields, ["op", "arpa", "sentences", "options"])
      model
      .corpus(
        decode_sentences(required(fields, "sentences"), limits),
        options=decode_options(fields.get("options")),
      )
      .to_json()
    }
    "predict" => {
      ensure_fields(fields, ["op", "arpa", "history", "k"])
      let ranked = model.predict(
        decode_tokens(required(fields, "history"), limits),
        decode_int(required(fields, "k")),
      )
      Json::array(ranked.map(p => p.to_json()))
    }
    "rescore" => {
      ensure_fields(fields, [
        "op", "arpa", "hypotheses", "lm_weight", "acoustic_weight", "length_weight",
        "options",
      ])
      let hypotheses = decode_hypotheses(required(fields, "hypotheses"), limits)
      let options : RescoreOptions = {
        lm_weight: optional_double(fields, "lm_weight", 1.0),
        acoustic_weight: optional_double(fields, "acoustic_weight", 1.0),
        length_weight: optional_double(fields, "length_weight", 0.0),
        scoring: decode_options(fields.get("options")),
      }
      Json::array(model.rescore(hypotheses, options~).map(r => r.to_json()))
    }
    "audit" => {
      ensure_fields(fields, ["op", "arpa", "history", "tolerance"])
      model
      .audit_mass(
        decode_tokens(required(fields, "history"), limits),
        tolerance=optional_double(fields, "tolerance", 1.0e-8),
      )
      .to_json()
    }
    _ => raise Invalid("unknown operation")
  }
}

///|
/// A stable envelope for CLI hosts. Errors contain no partial successful result.
pub fn handle(request : String, limits~ : Limits = Limits::default()) -> String {
  let result = json_object([
    ("ok", Json::boolean(true)),
    ("result", execute(request, limits~)),
  ]) catch {
    Invalid(message) =>
      json_object([
        ("ok", Json::boolean(false)),
        ("error", Json::string("invalid: " + message)),
      ])
    Budget(message) =>
      json_object([
        ("ok", Json::boolean(false)),
        ("error", Json::string("budget: " + message)),
      ])
    Missing(message) =>
      json_object([
        ("ok", Json::boolean(false)),
        ("error", Json::string("missing: " + message)),
      ])
  }
  result.stringify()
}
