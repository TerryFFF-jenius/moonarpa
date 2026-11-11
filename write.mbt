///|
fn log_text(value : Double) -> String {
  if value == @double.neg_infinity {
    "-inf"
  } else {
    value.to_string()
  }
}

///|
/// Deterministic section/lexicographic order; numeric precision is not truncated.
pub fn Model::to_arpa(self : Model) -> String raise ArpaError {
  let records = self.records()
  records.sort_by((a, b) => {
    let size = a.tokens.length().compare(b.tokens.length())
    if size == 0 {
      gram_key(a.tokens).compare(gram_key(b.tokens))
    } else {
      size
    }
  })
  let lines = ["\\data\\"]
  let counts = self.counts()
  for i = 0; i < counts.length(); i = i + 1 {
    lines.push("ngram \{i + 1}=\{counts[i]}")
  }
  let mut cursor = 0
  let mut size = lines.join("\n").length()
  for order = 1; order <= self.order; order = order + 1 {
    let marker = "\n\\\{order}-grams:"
    lines.push(marker)
    size += marker.length() + 1
    while cursor < records.length() && records[cursor].tokens.length() == order {
      let record = records[cursor]
      let row = log_text(record.log_probability) +
        "\t" +
        record.tokens.join(" ") +
        (match record.log_backoff {
          Some(b) => "\t" + log_text(b)
          None => ""
        })
      if row.length() > self.limits.max_text - size {
        raise Budget("ARPA output limit")
      }
      size += row.length() + 1
      lines.push(row)
      cursor += 1
    }
  }
  lines.push("\n\\end\\\n")
  let output = lines.join("\n")
  if output.length() > self.limits.max_text {
    raise Budget("ARPA output limit")
  }
  output
}
