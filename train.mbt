///|
fn log_probability(p : Double) -> Double {
  if p == 0.0 {
    @double.neg_infinity
  } else {
    @math.log10(p)
  }
}

///|
fn prefix(tokens : Array[String]) -> Array[String] {
  let result = []
  for i = 0; i < tokens.length() - 1; i = i + 1 {
    result.push(tokens[i])
  }
  result
}

///|
fn Counts::context_stats(
  self : Counts,
) -> (Map[String, Int32], Map[String, Int32]) {
  let totals : Map[String, Int32] = Map([])
  let distinct : Map[String, Int32] = Map([])
  for entry in self.entries {
    if entry.tokens.length() < 2 || entry.count == 0 {
      continue
    }
    let key = gram_key(prefix(entry.tokens))
    totals[key] = totals.get(key).unwrap_or(0) + entry.count
    distinct[key] = distinct.get(key).unwrap_or(0) + 1
  }
  (totals, distinct)
}

///|
/// Maximum likelihood above the unigram level. Observed histories have zero
/// unseen mass; unseen histories fall back. Additive prior applies to unigrams.
pub fn Counts::train_mle(
  self : Counts,
  unigram_prior~ : Double = 0.5,
) -> Model raise ArpaError {
  if !finite_number(unigram_prior) || unigram_prior <= 0.0 {
    raise Invalid("unigram prior must be positive finite")
  }
  let (totals, _) = self.context_stats()
  let vocabulary = self.vocabulary()
  let denominator = self.observed.to_double() +
    unigram_prior * (vocabulary.length() - 1).to_double()
  if !finite_number(denominator) || denominator <= 0.0 {
    raise Invalid("training denominator overflow")
  }
  let records = []
  for entry in self.entries {
    let n = entry.tokens.length()
    let probability = if n == 1 {
      if entry.tokens[0] == "<s>" {
        0.0
      } else {
        (entry.count.to_double() + unigram_prior) / denominator
      }
    } else {
      let count = totals.get(gram_key(prefix(entry.tokens))).unwrap_or(0)
      if count <= 0 {
        raise Invalid("missing context count")
      }
      entry.count.to_double() / count.to_double()
    }
    let backoff = if n == self.order {
      None
    } else if totals.contains(gram_key(entry.tokens)) {
      Some(@double.neg_infinity)
    } else {
      Some(0.0)
    }
    records.push({
      tokens: entry.tokens.copy(),
      log_probability: log_probability(probability),
      log_backoff: backoff,
    })
  }
  Model::new(self.order, records, limits=self.limits)
}
