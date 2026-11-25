///|
#derive(Debug, Eq)
pub(all) struct Prediction {
  token : String
  log_probability : Double
  matched_order : Int32
}

///|
fn prediction_before(a : Prediction, b : Prediction) -> Bool {
  a.log_probability > b.log_probability ||
  (a.log_probability == b.log_probability && a.token < b.token)
}

///|
/// Sorted top-k vocabulary continuations; probabilities are not renormalized.
pub fn Model::predict(
  self : Model,
  history : Array[String],
  k : Int32,
  include_unknown~ : Bool = true,
) -> Array[Prediction] raise ArpaError {
  if k < 0 || k > self.limits.max_tokens {
    raise Invalid("invalid prediction count")
  }
  if k == 0 {
    return []
  }
  if self.vocabulary.length() > self.limits.max_work / self.order {
    raise Budget("prediction work limit")
  }
  let candidates = []
  for token in self.vocabulary {
    if token == "<s>" || (!include_unknown && token == "<unk>") {
      continue
    }
    let score = self.conditional(history, token)
    candidates.push({
      token,
      log_probability: score.log_probability,
      matched_order: score.matched_order,
    })
  }
  candidates.sort_by(fn(a, b) {
    if prediction_before(a, b) {
      -1
    } else if prediction_before(b, a) {
      1
    } else {
      0
    }
  })
  while candidates.length() > k {
    let _ = candidates.pop()
  }
  candidates
}

///|
/// Scores only a caller-supplied candidate set, deduplicating exact token strings.
pub fn Model::rank_candidates(
  self : Model,
  history : Array[String],
  tokens : Array[String],
  oov~ : OovPolicy = MapToUnknown,
) -> Array[Prediction] raise ArpaError {
  if tokens.length() > self.limits.max_work / self.order {
    raise Budget("candidate work limit")
  }
  let seen : Map[String, Bool] = Map([])
  let results = []
  for token in tokens {
    if seen.contains(token) {
      continue
    }
    seen[token] = true
    let s = self.conditional(history, token, oov~)
    results.push({
      token,
      log_probability: s.log_probability,
      matched_order: s.matched_order,
    })
  }
  results.sort_by(fn(a, b) {
    if prediction_before(a, b) {
      -1
    } else if prediction_before(b, a) {
      1
    } else {
      0
    }
  })
  results
}

///|
pub extend Prediction with @debug.Debug::{to_repr}

///|
pub extend Prediction with Eq::{equal, not_equal}
