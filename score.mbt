///|
#derive(Debug, Eq)
pub(all) enum OovPolicy {
  MapToUnknown
  Reject
}

///|
#derive(Debug, Eq)
pub(all) struct TokenScore {
  token : String
  mapped : String
  log_probability : Double
  matched_order : Int32
  backoff_steps : Int32
  backoff_log : Double
  oov : Bool
}

///|
fn Model::map_token(
  self : Model,
  token : String,
  policy : OovPolicy,
) -> String raise ArpaError {
  if token.length() > self.limits.max_text {
    raise Budget("scoring token text limit")
  }
  if !token_valid(token) {
    raise Invalid("invalid scoring token")
  }
  if self.contains(token) {
    return token
  }
  match policy {
    Reject => raise Missing("token is outside vocabulary")
    MapToUnknown => {
      if !self.contains("<unk>") {
        raise Missing("model has no <unk> unigram")
      }
      "<unk>"
    }
  }
}

///|
fn suffix(tokens : Array[String], length : Int32) -> Array[String] {
  let output = []
  let start = (tokens.length() - length).max(0)
  for i = start; i < tokens.length(); i = i + 1 {
    output.push(tokens[i])
  }
  output
}

///|
/// Longest matching suffix; each missing ngram contributes its history backoff.
pub fn Model::conditional(
  self : Model,
  history : Array[String],
  token : String,
  oov~ : OovPolicy = MapToUnknown,
) -> TokenScore raise ArpaError {
  if history.length() > self.limits.max_tokens {
    raise Budget("history token limit")
  }
  let mut units = token.length()
  if units > self.limits.max_text {
    raise Budget("scoring text limit")
  }
  for h in history {
    if h.length() > self.limits.max_text - units {
      raise Budget("history text limit")
    }
    units += h.length()
  }
  let mapped = self.map_token(token, oov)
  let context = []
  for h in suffix(history, self.order - 1) {
    context.push(self.map_token(h, oov))
  }
  let mut total_backoff = 0.0
  let mut backoff_steps = 0
  for attempt = 0; attempt <= self.order; attempt = attempt + 1 {
    let query = context.copy()
    query.push(mapped)
    match self.index.get(gram_key(query)) {
      Some(i) => {
        let probability = total_backoff + self.grams[i].log_probability
        if !valid_log(probability) ||
          (
            finite(total_backoff) &&
            finite(self.grams[i].log_probability) &&
            !finite(probability)
          ) {
          raise Invalid("backoff arithmetic overflow")
        }
        return {
          token,
          mapped,
          log_probability: probability,
          matched_order: query.length(),
          backoff_steps,
          backoff_log: total_backoff,
          oov: mapped != token,
        }
      }
      None => {
        if context.is_empty() {
          raise Missing("missing unigram")
        }
        match self.index.get(gram_key(context)) {
          Some(i) => {
            let previous = total_backoff
            let weight = self.grams[i].log_backoff.unwrap_or(0.0)
            total_backoff += weight
            if !valid_log(total_backoff) ||
              (finite(previous) && finite(weight) && !finite(total_backoff)) {
              raise Invalid("backoff sum overflow")
            }
          }
          None => ()
        }
        let _ = context.remove(0)
        backoff_steps += 1
      }
    }
  }
  raise Missing("exhausted backoff search")
}

///|
pub extend OovPolicy with @debug.Debug::{to_repr}

///|
pub extend OovPolicy with Eq::{equal, not_equal}

///|
pub extend TokenScore with @debug.Debug::{to_repr}

///|
pub extend TokenScore with Eq::{equal, not_equal}
