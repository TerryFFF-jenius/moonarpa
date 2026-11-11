///|
/// A single ARPA record; probability and optional backoff use base-10 logarithms.
pub(all) struct Gram {
  tokens : Array[String]
  log_probability : Double
  log_backoff : Double?
} derive(Debug, Eq)

///|
fn Gram::owned(self : Gram) -> Gram {
  {
    tokens: self.tokens.copy(),
    log_probability: self.log_probability,
    log_backoff: self.log_backoff,
  }
}

///|
/// Owned validated records; callers cannot mutate the internal indices.
pub struct Model {
  order : Int32
  grams : Array[Gram]
  index : Map[String, Int32]
  vocabulary : Array[String]
  vocabulary_set : Map[String, Bool]
  limits : Limits
}

///|
pub fn Model::new(
  order : Int32,
  records : Array[Gram],
  limits~ : Limits = Limits::default(),
) -> Model raise ArpaError {
  limits.validate()
  if order < 1 || order > limits.max_order {
    raise Invalid("unsupported order")
  }
  if records.length() > limits.max_records {
    raise Budget("record limit")
  }
  let grams = []
  let index : Map[String, Int32] = {}
  let vocabulary = []
  let vocabulary_set : Map[String, Bool] = {}
  let mut units = 0
  for record in records {
    let size = record.tokens.length()
    if size < 1 || size > order {
      raise Invalid("record order outside model")
    }
    if !valid_log(record.log_probability) || record.log_probability > 0.0 {
      raise Invalid("probability must be nonpositive log10 or -inf")
    }
    match record.log_backoff {
      Some(b) => {
        if !valid_log(b) {
          raise Invalid("invalid backoff weight")
        }
        if size == order {
          raise Invalid("highest order cannot have backoff")
        }
      }
      None => ()
    }
    for token in record.tokens {
      if !token_valid(token) {
        raise Invalid("invalid vocabulary token")
      }
      if token.length() > limits.max_text - units {
        raise Budget("token text limit")
      }
      units += token.length()
    }
    let key = gram_key(record.tokens)
    if index.contains(key) {
      raise Invalid("duplicate n-gram")
    }
    index[key] = grams.length()
    grams.push(record.owned())
    if size == 1 {
      vocabulary.push(record.tokens[0])
      vocabulary_set[record.tokens[0]] = true
    }
  }
  if vocabulary.is_empty() {
    raise Invalid("unigrams are required")
  }
  if vocabulary.length() > limits.max_tokens {
    raise Budget("vocabulary limit")
  }
  for record in grams {
    for token in record.tokens {
      if !vocabulary_set.contains(token) {
        raise Invalid("ngram token has no unigram")
      }
    }
  }
  vocabulary.sort()
  { order, grams, index, vocabulary, vocabulary_set, limits, }
}

///|
pub fn Model::order(self : Model) -> Int32 {
  self.order
}

///|
pub fn Model::size(self : Model) -> Int32 {
  self.grams.length()
}

///|
pub fn Model::vocabulary(self : Model) -> Array[String] {
  self.vocabulary.copy()
}

///|
pub fn Model::contains(self : Model, token : String) -> Bool {
  self.vocabulary_set.contains(token)
}

///|
pub fn Model::records(self : Model) -> Array[Gram] {
  self.grams.map(record => record.owned())
}

///|
pub fn Model::record(self : Model, tokens : Array[String]) -> Gram? {
  match self.index.get(gram_key(tokens)) {
    Some(i) => Some(self.grams[i].owned())
    None => None
  }
}

///|
pub fn Model::counts(self : Model) -> Array[Int32] {
  let counts = Array::make(self.order, 0)
  for record in self.grams {
    counts[record.tokens.length() - 1] += 1
  }
  counts
}
