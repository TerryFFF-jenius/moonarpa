///|
/// Interpolated absolute discount: seen estimates include lower-order mass;
/// absent events receive lambda times the suffix estimate through ARPA backoff.
pub fn Counts::train_discount(
  self : Counts,
  discount~ : Double = 0.75,
  unigram_prior~ : Double = 0.5,
) -> Model raise ArpaError {
  if !finite_number(discount) || discount <= 0.0 || discount >= 1.0 {
    raise Invalid("discount must lie strictly between zero and one")
  }
  if !finite_number(unigram_prior) || unigram_prior <= 0.0 {
    raise Invalid("unigram prior must be positive finite")
  }
  let (totals, distinct) = self.context_stats()
  let vocabulary = self.vocabulary()
  let denominator = self.observed.to_double() +
    unigram_prior * (vocabulary.length() - 1).to_double()
  if !finite_number(denominator) || denominator <= 0.0 {
    raise Invalid("training denominator overflow")
  }
  let records : Array[Gram] = []
  let lambda = fn(key : String) {
    let total = totals.get(key).unwrap_or(0)
    if total == 0 {
      1.0
    } else {
      discount * distinct.get(key).unwrap_or(0).to_double() / total.to_double()
    }
  }
  for entry in self.entries {
    if entry.tokens.length() != 1 {
      continue
    }
    let p = if entry.tokens[0] == "<s>" {
      0.0
    } else {
      (entry.count.to_double() + unigram_prior) / denominator
    }
    let backoff = if self.order == 1 {
      None
    } else {
      Some(log_probability(lambda(gram_key(entry.tokens))))
    }
    records.push({
      tokens: entry.tokens.copy(),
      log_probability: log_probability(p),
      log_backoff: backoff,
    })
  }
  for n = 2; n <= self.order; n = n + 1 {
    let lower = Model::new(self.order, records, limits=self.limits)
    for entry in self.entries {
      if entry.tokens.length() != n {
        continue
      }
      let history = prefix(entry.tokens)
      let key = gram_key(history)
      let total = totals.get(key).unwrap_or(0)
      if total <= 0 {
        raise Invalid("missing context count")
      }
      let word = entry.tokens[n - 1]
      let lower_log = lower.conditional(
          suffix(history, n - 2),
          word,
          oov=Reject,
        ).log_probability
      let lower_p = @math.pow(10.0, lower_log)
      let p = (entry.count.to_double() - discount) / total.to_double() +
        lambda(key) * lower_p
      if !finite_number(p) || p <= 0.0 || p > 1.0 {
        raise Invalid("invalid discounted probability")
      }
      let backoff = if n == self.order {
        None
      } else {
        Some(log_probability(lambda(gram_key(entry.tokens))))
      }
      records.push({
        tokens: entry.tokens.copy(),
        log_probability: log_probability(p),
        log_backoff: backoff,
      })
    }
  }
  Model::new(self.order, records, limits=self.limits)
}
