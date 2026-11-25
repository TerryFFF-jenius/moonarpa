///|
#derive(Debug, Eq)
pub(all) struct VocabularyOptions {
  min_count : Int32
  max_vocabulary : Int32
}

///|
pub fn VocabularyOptions::default() -> VocabularyOptions {
  { min_count: 1, max_vocabulary: 50000, }
}

///|
pub struct FittedVocabulary {
  words : Array[String]
  membership : Map[String, Bool]
  training_tokens : Int32
  removed_types : Int32
  limits : Limits
}

///|
#derive(Debug, Eq)
pub(all) struct MappedCorpus {
  sentences : Array[Array[String]]
  tokens : Int32
  replaced : Int32
}

///|
/// Fit on training data only; reuse the resulting mapping for held-out data.
/// Count ties are resolved lexically and the three reserved symbols always exist.
pub fn fit_vocabulary(
  sentences : Array[Array[String]],
  options~ : VocabularyOptions = VocabularyOptions::default(),
  limits~ : Limits = Limits::default(),
) -> FittedVocabulary raise ArpaError {
  limits.validate()
  if options.min_count < 1 ||
    options.max_vocabulary < 3 ||
    options.max_vocabulary > limits.max_tokens {
    raise Invalid("invalid vocabulary options")
  }
  let counts = count_corpus(sentences, 1, limits~)
  let candidates = []
  let mut types = 0
  for entry in counts.entries {
    let token = entry.tokens[0]
    if token == "<s>" || token == "</s>" || token == "<unk>" {
      continue
    }
    types += 1
    if entry.count >= options.min_count {
      candidates.push(entry)
    }
  }
  candidates.sort_by(fn(a, b) {
    if a.count > b.count {
      -1
    } else if a.count < b.count {
      1
    } else {
      a.tokens[0].compare(b.tokens[0])
    }
  })
  let words = ["<s>", "</s>", "<unk>"]
  let membership : Map[String, Bool] = Map([])
  for token in words {
    membership[token] = true
  }
  let keep = (options.max_vocabulary - 3).min(candidates.length())
  for i = 0; i < keep; i = i + 1 {
    let word = candidates[i].tokens[0]
    words.push(word)
    membership[word] = true
  }
  words.sort()
  {
    words,
    membership,
    training_tokens: counts.observed - counts.sentences,
    removed_types: types - keep,
    limits,
  }
}

///|
pub fn FittedVocabulary::words(self : FittedVocabulary) -> Array[String] {
  self.words.copy()
}

///|
pub fn FittedVocabulary::training_tokens(self : FittedVocabulary) -> Int32 {
  self.training_tokens
}

///|
pub fn FittedVocabulary::removed_types(self : FittedVocabulary) -> Int32 {
  self.removed_types
}

///|
pub fn FittedVocabulary::contains(
  self : FittedVocabulary,
  word : String,
) -> Bool {
  self.membership.contains(word)
}

///|
pub fn FittedVocabulary::map_token(
  self : FittedVocabulary,
  word : String,
) -> String raise ArpaError {
  if !token_valid(word) {
    raise Invalid("invalid mapping token")
  }
  if word == "<s>" || word == "</s>" {
    raise Invalid("unexpected boundary token")
  }
  if self.membership.contains(word) {
    word
  } else {
    "<unk>"
  }
}

///|
pub fn FittedVocabulary::transform(
  self : FittedVocabulary,
  sentences : Array[Array[String]],
) -> MappedCorpus raise ArpaError {
  if sentences.length() > self.limits.max_tokens {
    raise Budget("mapping sentence limit")
  }
  let output = []
  let mut tokens = 0
  let mut replaced = 0
  let mut text = 0
  for sentence in sentences {
    if sentence.length() > self.limits.max_tokens - tokens {
      raise Budget("mapping token limit")
    }
    let row = []
    for word in sentence {
      if word.length() > self.limits.max_text - text {
        raise Budget("mapping text limit")
      }
      text += word.length()
      let mapped = self.map_token(word)
      if word != mapped {
        replaced += 1
      }
      row.push(mapped)
      tokens += 1
    }
    output.push(row)
  }
  { sentences: output, tokens, replaced, }
}

///|
pub extend VocabularyOptions with @debug.Debug::{to_repr}

///|
pub extend VocabularyOptions with Eq::{equal, not_equal}

///|
pub extend MappedCorpus with @debug.Debug::{to_repr}

///|
pub extend MappedCorpus with Eq::{equal, not_equal}
