///|
#derive(Debug, Eq)
pub(all) struct ScoreOptions {
  bos : Bool
  eos : Bool
  oov : OovPolicy
}

///|
pub fn ScoreOptions::default() -> ScoreOptions {
  { bos: true, eos: true, oov: MapToUnknown, }
}

///|
#derive(Debug, Eq)
pub(all) struct SentenceScore {
  log_probability : Double
  predicted : Int32
  oov_count : Int32
  tokens : Array[TokenScore]
}

///|
pub fn SentenceScore::perplexity(self : SentenceScore) -> Double? {
  if self.predicted == 0 {
    return None
  }
  Some(@math.pow(10.0, -self.log_probability / self.predicted.to_double()))
}

///|
fn add_log(a : Double, b : Double) -> Double raise ArpaError {
  let total = a + b
  if !valid_log(total) || (finite(a) && finite(b) && !finite(total)) {
    raise Invalid("log probability sum overflow")
  }
  total
}

///|
fn checked_token_budget(
  tokens : Array[String],
  limits : Limits,
) -> Unit raise ArpaError {
  if tokens.length() > limits.max_tokens {
    raise Budget("sentence token limit")
  }
  let mut units = 0
  for token in tokens {
    if token.length() > limits.max_text - units {
      raise Budget("sentence text limit")
    }
    units += token.length()
    if !token_valid(token) {
      raise Invalid("invalid sentence token")
    }
    if token == "<s>" || token == "</s>" {
      raise Invalid("boundary tokens must be supplied through options")
    }
  }
}

///|
/// Inputs are already tokenized. BOS seeds history but is never predicted.
pub fn Model::sentence(
  self : Model,
  tokens : Array[String],
  options~ : ScoreOptions = ScoreOptions::default(),
) -> SentenceScore raise ArpaError {
  checked_token_budget(tokens, self.limits)
  if options.bos && !self.contains("<s>") {
    raise Missing("BOS unigram")
  }
  if options.eos && !self.contains("</s>") {
    raise Missing("EOS unigram")
  }
  let history = if options.bos { ["<s>"] } else { [] }
  let results = []
  let mut total = 0.0
  let mut oovs = 0
  let count = tokens.length() + (if options.eos { 1 } else { 0 })
  for i = 0; i < count; i = i + 1 {
    let token = if i < tokens.length() { tokens[i] } else { "</s>" }
    let score = self.conditional(history, token, oov=options.oov)
    total = add_log(total, score.log_probability)
    if score.oov {
      oovs += 1
    }
    results.push(score)
    history.push(score.mapped)
    while history.length() > self.order - 1 {
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

///|
pub fn Model::score_text(
  self : Model,
  text : String,
  options~ : ScoreOptions = ScoreOptions::default(),
) -> SentenceScore raise ArpaError {
  if text.length() > self.limits.max_text {
    raise Budget("text limit")
  }
  self.sentence(words(text), options~)
}

///|
pub extend ScoreOptions with @debug.Debug::{to_repr}

///|
pub extend ScoreOptions with Eq::{equal, not_equal}

///|
pub extend SentenceScore with @debug.Debug::{to_repr}

///|
pub extend SentenceScore with Eq::{equal, not_equal}
