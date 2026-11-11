///|
/// A probability mixture of models with exactly the same vocabulary.
pub struct Mixture {
  models : Array[Model]
  weights : Array[Double]
  limits : Limits
}

///|
pub fn Mixture::new(
  models : Array[Model],
  weights : Array[Double],
  limits~ : Limits = Limits::default(),
) -> Mixture raise ArpaError {
  limits.validate()
  if models.is_empty() || models.length() != weights.length() {
    raise Invalid("mixture dimensions")
  }
  if models.length() > limits.max_order {
    raise Budget("mixture component limit")
  }
  let vocabulary = models[0].vocabulary()
  let mut total = 0.0
  for i = 0; i < weights.length(); i = i + 1 {
    let w = weights[i]
    if !finite_number(w) || w < 0.0 {
      raise Invalid("mixture weights must be finite nonnegative")
    }
    total += w
    if models[i].vocabulary() != vocabulary {
      raise Invalid("mixture requires identical vocabularies")
    }
  }
  if !finite_number(total) || total <= 0.0 {
    raise Invalid("mixture requires positive finite total weight")
  }
  { models: models.copy(), weights: weights.map(w => w / total), limits, }
}

///|
pub fn Mixture::weights(self : Mixture) -> Array[Double] {
  self.weights.copy()
}

///|
/// Stable log10-sum-exp; mixture is of probabilities, not logarithms.
pub fn Mixture::conditional(
  self : Mixture,
  history : Array[String],
  token : String,
  oov~ : OovPolicy = MapToUnknown,
) -> Double raise ArpaError {
  if history.length() > self.limits.max_tokens {
    raise Budget("mixture history limit")
  }
  let terms = []
  let mut maximum = @double.neg_infinity
  for i = 0; i < self.models.length(); i = i + 1 {
    if self.weights[i] == 0.0 {
      continue
    }
    let score = self.models[i].conditional(history, token, oov~)
    let term = @math.log10(self.weights[i]) + score.log_probability
    terms.push(term)
    if term > maximum {
      maximum = term
    }
  }
  if maximum == @double.neg_infinity {
    return maximum
  }
  let mut sum = 0.0
  for term in terms {
    sum += @math.pow(10.0, term - maximum)
  }
  let result = maximum + @math.log10(sum)
  if !valid_log(result) {
    raise Invalid("mixture arithmetic overflow")
  }
  result
}

///|
pub fn Mixture::sentence(
  self : Mixture,
  tokens : Array[String],
  options~ : ScoreOptions = ScoreOptions::default(),
) -> SentenceScore raise ArpaError {
  checked_token_budget(tokens, self.limits)
  let base = self.models[0]
  if options.bos && !base.contains("<s>") {
    raise Missing("BOS unigram")
  }
  if options.eos && !base.contains("</s>") {
    raise Missing("EOS unigram")
  }
  let history = if options.bos { ["<s>"] } else { [] }
  let mut total = 0.0
  let mut oovs = 0
  let results = []
  let count = tokens.length() + (if options.eos { 1 } else { 0 })
  for i = 0; i < count; i = i + 1 {
    let token = if i < tokens.length() { tokens[i] } else { "</s>" }
    let mapped = base.map_token(token, options.oov)
    let probability = self.conditional(history, token, oov=options.oov)
    total = add_log(total, probability)
    if token != mapped {
      oovs += 1
    }
    results.push({
      token,
      mapped,
      log_probability: probability,
      matched_order: 0,
      backoff_steps: 0,
      backoff_log: 0.0,
      oov: token != mapped,
    })
    history.push(mapped)
    if history.length() > self.limits.max_order - 1 {
      let _ = history.remove(0)
    }
  }
  {
    log_probability: total,
    predicted: count,
    oov_count: oovs,
    tokens: results,
  }
}
