///|
#derive(Debug, Eq)
pub(all) struct CorpusScore {
  sentences : Int32
  predicted : Int32
  oov_count : Int32
  impossible : Int32
  log_probability : Double
  sentence_scores : Array[SentenceScore]
}

///|
pub fn CorpusScore::perplexity(self : CorpusScore) -> Double? {
  if self.predicted == 0 {
    return None
  }
  Some(@math.pow(10.0, -self.log_probability / self.predicted.to_double()))
}

///|
pub fn CorpusScore::oov_rate(self : CorpusScore) -> Double? {
  if self.predicted == 0 {
    return None
  }
  Some(self.oov_count.to_double() / self.predicted.to_double())
}

///|
/// Aggregates token likelihoods, never an arithmetic mean of sentence perplexities.
pub fn Model::corpus(
  self : Model,
  sentences : Array[Array[String]],
  options~ : ScoreOptions = ScoreOptions::default(),
) -> CorpusScore raise ArpaError {
  if sentences.length() > self.limits.max_tokens {
    raise Budget("corpus sentence limit")
  }
  let mut work = 0
  let mut predicted = 0
  let mut oov_count = 0
  let mut impossible = 0
  let mut total = 0.0
  let scores = []
  for tokens in sentences {
    let count = tokens.length() + (if options.eos { 1 } else { 0 })
    if count > self.limits.max_work - work {
      raise Budget("corpus work limit")
    }
    work += count
    let score = self.sentence(tokens, options~)
    predicted += score.predicted
    oov_count += score.oov_count
    total = add_log(total, score.log_probability)
    if score.log_probability == @double.neg_infinity {
      impossible += 1
    }
    scores.push(score)
  }
  {
    sentences: sentences.length(),
    predicted,
    oov_count,
    impossible,
    log_probability: total,
    sentence_scores: scores,
  }
}

///|
/// Each physical line is one sentence, including empty lines between newlines.
/// A terminal newline terminates the last line and does not add an empty sentence.
pub fn Model::score_lines(
  self : Model,
  text : String,
  options~ : ScoreOptions = ScoreOptions::default(),
) -> CorpusScore raise ArpaError {
  if text.length() > self.limits.max_text {
    raise Budget("corpus text limit")
  }
  let lines = text.split("\n").map(line => words(line.to_owned())).collect()
  if text.has_suffix("\n") {
    let _ = lines.pop()
  }
  if text.is_empty() {
    lines.clear()
  }
  self.corpus(lines, options~)
}

///|
pub extend CorpusScore with @debug.Debug::{to_repr}

///|
pub extend CorpusScore with Eq::{equal, not_equal}
