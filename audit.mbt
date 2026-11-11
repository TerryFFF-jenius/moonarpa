///|
pub(all) struct MassAudit {
  history : Array[String]
  mass : Double
  deviation : Double
  normalized : Bool
  zero_events : Int32
  backed_off_events : Int32
} derive(Debug, Eq)

///|
pub(all) struct ModelSummary {
  order : Int32
  records : Int32
  vocabulary : Int32
  counts : Array[Int32]
  impossible_records : Int32
  positive_backoffs : Int32
  has_unknown : Bool
  has_bos : Bool
  has_eos : Bool
} derive(Debug, Eq)

///|
pub fn Model::summary(self : Model) -> ModelSummary {
  let mut impossible_records = 0
  let mut positive_backoffs = 0
  for gram in self.grams {
    if gram.log_probability == @double.neg_infinity {
      impossible_records += 1
    }
    match gram.log_backoff {
      Some(b) => if b > 0.0 { positive_backoffs += 1 }
      None => ()
    }
  }
  {
    order: self.order,
    records: self.grams.length(),
    vocabulary: self.vocabulary.length(),
    counts: self.counts(),
    impossible_records,
    positive_backoffs,
    has_unknown: self.contains("<unk>"),
    has_bos: self.contains("<s>"),
    has_eos: self.contains("</s>"),
  }
}

///|
/// Sum the complete vocabulary with compensated summation. ARPA syntax alone
/// does not guarantee normalized conditional distributions.
pub fn Model::audit_mass(
  self : Model,
  history : Array[String],
  tolerance~ : Double = 1.0e-8,
) -> MassAudit raise ArpaError {
  if !finite_number(tolerance) || tolerance < 0.0 {
    raise Invalid("invalid audit tolerance")
  }
  if self.vocabulary.length() > self.limits.max_work / self.order {
    raise Budget("mass audit work limit")
  }
  let mut sum = 0.0
  let mut correction = 0.0
  let mut zeros = 0
  let mut backed_off = 0
  for token in self.vocabulary {
    let score = self.conditional(history, token, oov=Reject)
    if score.log_probability == @double.neg_infinity {
      zeros += 1
    }
    if score.backoff_steps > 0 {
      backed_off += 1
    }
    let p = @math.pow(10.0, score.log_probability)
    if !finite_number(p) {
      raise Invalid("conditional probability overflow")
    }
    let adjusted = p - correction
    let next = sum + adjusted
    correction = next - sum - adjusted
    sum = next
  }
  if !finite_number(sum) {
    raise Invalid("probability mass overflow")
  }
  let deviation = (sum - 1.0).abs()
  {
    history: history.copy(),
    mass: sum,
    deviation,
    normalized: deviation <= tolerance,
    zero_events: zeros,
    backed_off_events: backed_off,
  }
}

///|
/// Audits a deterministic bounded set of observed histories and the empty one.
/// The caller chooses a cap because exhaustive V^order enumeration is unbounded.
pub fn Model::audit_contexts(
  self : Model,
  maximum : Int32,
  tolerance~ : Double = 1.0e-8,
) -> Array[MassAudit] raise ArpaError {
  if maximum < 1 || maximum > self.limits.max_records {
    raise Invalid("invalid context audit cap")
  }
  let per_context = self.vocabulary.length() * self.order
  if per_context > 0 && maximum > self.limits.max_work / per_context {
    raise Budget("context audit work limit")
  }
  let histories : Array[Array[String]] = [[]]
  let seen : Map[String, Bool] = Map([])
  seen[""] = true
  let grams = self.records()
  grams.sort_by(fn(a, b) { gram_key(a.tokens).compare(gram_key(b.tokens)) })
  for gram in grams {
    if gram.tokens.length() >= self.order || histories.length() >= maximum {
      continue
    }
    let key = gram_key(gram.tokens)
    if !seen.contains(key) {
      seen[key] = true
      histories.push(gram.tokens.copy())
    }
  }
  let reports = []
  for history in histories {
    reports.push(self.audit_mass(history, tolerance~))
  }
  reports
}

///|
/// Cross-entropy in bits per predicted event; None means no predicted events.
pub fn SentenceScore::cross_entropy_bits(self : SentenceScore) -> Double? {
  if self.predicted == 0 {
    return None
  }
  Some(-self.log_probability / self.predicted.to_double() * @math.log2(10.0))
}

///|
pub fn CorpusScore::cross_entropy_bits(self : CorpusScore) -> Double? {
  if self.predicted == 0 {
    return None
  }
  Some(-self.log_probability / self.predicted.to_double() * @math.log2(10.0))
}

///|
pub extend MassAudit with @debug.Debug::{to_repr}

///|
pub extend MassAudit with Eq::{equal, not_equal}

///|
pub extend ModelSummary with @debug.Debug::{to_repr}

///|
pub extend ModelSummary with Eq::{equal, not_equal}
