///|
#derive(Debug, Eq)
pub(all) struct Hypothesis {
  id : String
  tokens : Array[String]
  acoustic_score : Double
}

///|
#derive(Debug, Eq)
pub(all) struct RescoreOptions {
  lm_weight : Double
  acoustic_weight : Double
  length_weight : Double
  scoring : ScoreOptions
}

///|
pub fn RescoreOptions::default() -> RescoreOptions {
  {
    lm_weight: 1.0,
    acoustic_weight: 1.0,
    length_weight: 0.0,
    scoring: ScoreOptions::default(),
  }
}

///|
#derive(Debug, Eq)
pub(all) struct RankedHypothesis {
  id : String
  input_index : Int32
  score : Double
  language : SentenceScore
}

///|
fn finite_number(value : Double) -> Bool {
  valid_log(value) && value != @double.neg_infinity
}

///|
/// Acoustic scores must already use compatible units (typically log10).
/// Zero LM weight disables the LM term even for impossible sentences.
pub fn Model::rescore(
  self : Model,
  hypotheses : Array[Hypothesis],
  options~ : RescoreOptions = RescoreOptions::default(),
) -> Array[RankedHypothesis] raise ArpaError {
  if !finite_number(options.lm_weight) ||
    options.lm_weight < 0.0 ||
    !finite_number(options.acoustic_weight) ||
    options.acoustic_weight < 0.0 ||
    !finite_number(options.length_weight) {
    raise Invalid("invalid rescoring weights")
  }
  if hypotheses.length() > self.limits.max_records {
    raise Budget("hypothesis limit")
  }
  let ids : Map[String, Bool] = Map([])
  let ranked = []
  let mut work = 0
  for i = 0; i < hypotheses.length(); i = i + 1 {
    let h = hypotheses[i]
    if h.id.is_empty() || ids.contains(h.id) {
      raise Invalid("hypothesis IDs must be nonempty and unique")
    }
    if !finite_number(h.acoustic_score) {
      raise Invalid("nonfinite acoustic score")
    }
    if h.tokens.length() + 1 > self.limits.max_work - work {
      raise Budget("rescoring work limit")
    }
    work += h.tokens.length() + 1
    ids[h.id] = true
    let language = self.sentence(h.tokens, options=options.scoring)
    let lm_term = if options.lm_weight == 0.0 {
      0.0
    } else {
      options.lm_weight * language.log_probability
    }
    let score = lm_term +
      options.acoustic_weight * h.acoustic_score +
      options.length_weight * h.tokens.length().to_double()
    if !valid_log(score) {
      raise Invalid("rescoring arithmetic overflow")
    }
    ranked.push({ id: h.id, input_index: i, score, language, })
  }
  ranked.sort_by(fn(a, b) {
    if a.score > b.score {
      -1
    } else if a.score < b.score {
      1
    } else {
      a.input_index - b.input_index
    }
  })
  ranked
}

///|
pub extend Hypothesis with @debug.Debug::{to_repr}

///|
pub extend Hypothesis with Eq::{equal, not_equal}

///|
pub extend RescoreOptions with @debug.Debug::{to_repr}

///|
pub extend RescoreOptions with Eq::{equal, not_equal}

///|
pub extend RankedHypothesis with @debug.Debug::{to_repr}

///|
pub extend RankedHypothesis with Eq::{equal, not_equal}
