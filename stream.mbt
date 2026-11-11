///|
/// A sentence-scoped incremental scorer. Failed batches leave the state unchanged.
pub struct Scorer {
  model : Model
  options : ScoreOptions
  history : Array[String]
  results : Array[TokenScore]
  mut total : Double
  mut oovs : Int32
  mut closed : Bool
}

///|
pub fn Model::scorer(
  self : Model,
  options~ : ScoreOptions = ScoreOptions::default(),
) -> Scorer raise ArpaError {
  if options.bos && !self.contains("<s>") {
    raise Missing("BOS unigram")
  }
  if options.eos && !self.contains("</s>") {
    raise Missing("EOS unigram")
  }
  {
    model: self,
    options,
    history: if options.bos {
      ["<s>"]
    } else {
      []
    },
    results: [],
    total: 0.0,
    oovs: 0,
    closed: false,
  }
}

///|
pub fn Scorer::fork(self : Scorer) -> Scorer {
  {
    model: self.model,
    options: self.options,
    history: self.history.copy(),
    results: self.results.copy(),
    total: self.total,
    oovs: self.oovs,
    closed: self.closed,
  }
}

///|
pub fn Scorer::history(self : Scorer) -> Array[String] {
  self.history.copy()
}

///|
pub fn Scorer::is_closed(self : Scorer) -> Bool {
  self.closed
}

///|
pub fn Scorer::snapshot(self : Scorer) -> SentenceScore {
  {
    log_probability: self.total,
    predicted: self.results.length(),
    oov_count: self.oovs,
    tokens: self.results.copy(),
  }
}

///|
fn Scorer::accept(self : Scorer, token : String) -> TokenScore raise ArpaError {
  let score = self.model.conditional(self.history, token, oov=self.options.oov)
  let total = add_log(self.total, score.log_probability)
  self.results.push(score)
  self.total = total
  if score.oov {
    self.oovs += 1
  }
  self.history.push(score.mapped)
  if self.history.length() > self.model.order - 1 {
    let _ = self.history.remove(0)
  }
  score
}

///|
pub fn Scorer::feed(
  self : Scorer,
  token : String,
) -> TokenScore raise ArpaError {
  if self.closed {
    raise Invalid("scorer already finished")
  }
  checked_token_budget([token], self.model.limits)
  if self.results.length() >= self.model.limits.max_tokens {
    raise Budget("stream token limit")
  }
  self.accept(token)
}

///|
pub fn Scorer::feed_batch(
  self : Scorer,
  tokens : Array[String],
) -> SentenceScore raise ArpaError {
  if self.closed {
    raise Invalid("scorer already finished")
  }
  checked_token_budget(tokens, self.model.limits)
  if tokens.length() > self.model.limits.max_tokens - self.results.length() {
    raise Budget("stream token limit")
  }
  let trial = self.fork()
  for token in tokens {
    let _ = trial.accept(token)
  }
  self.history.clear()
  for token in trial.history {
    self.history.push(token)
  }
  self.results.clear()
  for result in trial.results {
    self.results.push(result)
  }
  self.total = trial.total
  self.oovs = trial.oovs
  self.snapshot()
}

///|
pub fn Scorer::finish(self : Scorer) -> SentenceScore raise ArpaError {
  if !self.closed {
    if self.options.eos {
      let _ = self.accept("</s>")
    }
    self.closed = true
  }
  self.snapshot()
}

///|
pub fn Scorer::reset(self : Scorer) -> Unit {
  self.history.clear()
  if self.options.bos {
    self.history.push("<s>")
  }
  self.results.clear()
  self.total = 0.0
  self.oovs = 0
  self.closed = false
}
