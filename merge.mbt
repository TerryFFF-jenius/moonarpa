///|
/// Merge independent corpus shards without retaining raw training sentences.
/// Counts use identical boundary rules; each shard's sentence boundaries remain.
pub fn Counts::merge(self : Counts, other : Counts) -> Counts raise ArpaError {
  if self.order != other.order {
    raise Invalid("cannot merge different count orders")
  }
  let limits = self.limits
  if other.observed > limits.max_tokens - self.observed {
    raise Budget("merged token limit")
  }
  if other.sentences > limits.max_tokens - self.sentences {
    raise Budget("merged sentence limit")
  }
  if other.entries.length() > limits.max_work - self.entries.length() {
    raise Budget("merge work limit")
  }
  let entries = self.records()
  let index : Map[String, Int32] = Map([])
  let mut text = 0
  for i = 0; i < entries.length(); i = i + 1 {
    let key = gram_key(entries[i].tokens)
    if key.length() > limits.max_text - text {
      raise Budget("merged text limit")
    }
    text += key.length()
    index[key] = i
  }
  for entry in other.entries {
    let key = gram_key(entry.tokens)
    match index.get(key) {
      Some(i) => {
        let previous = entries[i]
        if entry.count > limits.max_tokens - previous.count {
          raise Budget("merged count overflow")
        }
        entries[i] = {
          tokens: previous.tokens,
          count: previous.count + entry.count,
        }
      }
      None => {
        if entries.length() >= limits.max_records {
          raise Budget("merged record limit")
        }
        if key.length() > limits.max_text - text {
          raise Budget("merged text limit")
        }
        text += key.length()
        index[key] = entries.length()
        entries.push(entry.owned())
      }
    }
  }
  {
    order: self.order,
    entries,
    index,
    sentences: self.sentences + other.sentences,
    observed: self.observed + other.observed,
    limits,
  }
}

///|
/// Sorted continuation counts for inspecting an observed history.
pub fn Counts::continuations(
  self : Counts,
  history : Array[String],
) -> Array[CountGram] raise ArpaError {
  if history.length() >= self.order {
    raise Invalid("history must be shorter than count order")
  }
  if self.entries.length() > self.limits.max_work {
    raise Budget("continuation scan limit")
  }
  for word in history {
    if !token_valid(word) {
      raise Invalid("invalid history token")
    }
  }
  let result = []
  for entry in self.entries {
    if entry.tokens.length() == history.length() + 1 &&
      prefix(entry.tokens) == history &&
      entry.count > 0 {
      result.push(entry.owned())
    }
  }
  result.sort_by(fn(a, b) {
    if a.count > b.count {
      -1
    } else if a.count < b.count {
      1
    } else {
      gram_key(a.tokens).compare(gram_key(b.tokens))
    }
  })
  result
}
