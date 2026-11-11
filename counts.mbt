///|
pub(all) struct CountGram {
  tokens : Array[String]
  count : Int32
} derive(Debug, Eq)

///|
pub struct Counts {
  order : Int32
  entries : Array[CountGram]
  index : Map[String, Int32]
  sentences : Int32
  observed : Int32
  limits : Limits
}

///|
fn CountGram::owned(self : CountGram) -> CountGram {
  { tokens: self.tokens.copy(), count: self.count, }
}

///|
/// Counts one BOS history and one predicted EOS for every sentence.
/// BOS is not a predicted event and gets a zero-count vocabulary entry.
pub fn count_corpus(
  sentences : Array[Array[String]],
  order : Int32,
  limits~ : Limits = Limits::default(),
) -> Counts raise ArpaError {
  limits.validate()
  if order < 1 || order > limits.max_order {
    raise Invalid("count order")
  }
  if sentences.length() > limits.max_tokens {
    raise Budget("sentence count limit")
  }
  let entries : Array[CountGram] = [
    { tokens: ["<s>"], count: 0, },
    { tokens: ["<unk>"], count: 0, },
    { tokens: ["</s>"], count: 0, },
  ]
  let index : Map[String, Int32] = Map([])
  for i = 0; i < entries.length(); i = i + 1 {
    index[gram_key(entries[i].tokens)] = i
  }
  let mut observed = 0
  let mut work = 0
  let mut text_units = 0
  for sentence in sentences {
    checked_token_budget(sentence, limits)
    if sentence.length() + 1 > limits.max_tokens - observed {
      raise Budget("corpus token limit")
    }
    let history = ["<s>"]
    for i = 0; i <= sentence.length(); i = i + 1 {
      let token = if i < sentence.length() { sentence[i] } else { "</s>" }
      observed += 1
      for n = 1; n <= order && n <= history.length() + 1; n = n + 1 {
        if work >= limits.max_work {
          raise Budget("counting work limit")
        }
        work += 1
        let tokens = suffix(history, n - 1)
        tokens.push(token)
        let key = gram_key(tokens)
        match index.get(key) {
          Some(j) => {
            let previous = entries[j]
            entries[j] = { tokens: previous.tokens, count: previous.count + 1, }
          }
          None => {
            if entries.length() >= limits.max_records {
              raise Budget("count record limit")
            }
            if key.length() > limits.max_text - text_units {
              raise Budget("count text limit")
            }
            text_units += key.length()
            index[key] = entries.length()
            entries.push({ tokens, count: 1, })
          }
        }
      }
      history.push(token)
      if history.length() > order - 1 {
        let _ = history.remove(0)
      }
    }
  }
  if entries.length() > limits.max_records {
    raise Budget("count record limit")
  }
  { order, entries, index, sentences: sentences.length(), observed, limits, }
}

///|
pub fn Counts::order(self : Counts) -> Int32 {
  self.order
}

///|
pub fn Counts::sentence_count(self : Counts) -> Int32 {
  self.sentences
}

///|
pub fn Counts::token_count(self : Counts) -> Int32 {
  self.observed
}

///|
pub fn Counts::records(self : Counts) -> Array[CountGram] {
  self.entries.map(entry => entry.owned())
}

///|
pub fn Counts::count(self : Counts, tokens : Array[String]) -> Int32 {
  match self.index.get(gram_key(tokens)) {
    Some(i) => self.entries[i].count
    None => 0
  }
}

///|
pub fn Counts::vocabulary(self : Counts) -> Array[String] {
  let tokens = []
  for entry in self.entries {
    if entry.tokens.length() == 1 {
      tokens.push(entry.tokens[0])
    }
  }
  tokens.sort()
  tokens
}

///|
pub extend CountGram with @debug.Debug::{to_repr}

///|
pub extend CountGram with Eq::{equal, not_equal}
