///|
/// Strict ARPA text reader with declared count and section-order verification.
pub fn parse(
  text : String,
  limits~ : Limits = Limits::default(),
) -> Model raise ArpaError {
  limits.validate()
  if text.length() > limits.max_text {
    raise Budget("ARPA text limit")
  }
  let declared : Array[Int32] = []
  let observed : Array[Int32] = []
  let records : Array[Gram] = []
  let mut data = false
  let mut ended = false
  let mut section = 0
  let mut line_number = 0
  let mut declared_total = 0
  for raw in text.split("\n") {
    line_number += 1
    let line = raw.trim().to_owned()
    if line.is_empty() || line.has_prefix("#") {
      continue
    }
    if ended {
      raise Invalid("line \{line_number}: trailing data")
    }
    if !data {
      if line != "\\data\\" {
        raise Invalid("line \{line_number}: expected data marker")
      }
      data = true
      continue
    }
    if line == "\\end\\" {
      if section == 0 || section != declared.length() {
        raise Invalid("line \{line_number}: missing sections")
      }
      ended = true
      continue
    }
    if line.has_prefix("\\") {
      if !line.has_suffix("-grams:") {
        raise Invalid("line \{line_number}: invalid section marker")
      }
      let number = line[1:line.length() - 7].to_owned()
      let next = positive_count(number, line_number)
      if next != section + 1 || next > declared.length() {
        raise Invalid(
          "line \{line_number}: section order or undeclared section",
        )
      }
      if section > 0 && observed[section - 1] != declared[section - 1] {
        raise Invalid("line \{line_number}: previous section count mismatch")
      }
      section = next
      continue
    }
    if section == 0 {
      let (left, right) = match line.split_once("=") {
        Some(parts) => parts
        None => raise Invalid("line \{line_number}: expected ngram count")
      }
      let prefix = words(left.to_owned())
      if prefix.length() != 2 || prefix[0] != "ngram" {
        raise Invalid("line \{line_number}: invalid count declaration")
      }
      let n = positive_count(prefix[1], line_number)
      if n != declared.length() + 1 || n > limits.max_order {
        raise Invalid("line \{line_number}: noncontiguous or excessive order")
      }
      let count = positive_count(right.trim().to_owned(), line_number)
      if count > limits.max_records - declared_total {
        raise Budget("declared record limit")
      }
      declared_total += count
      declared.push(count)
      observed.push(0)
      continue
    }
    if observed[section - 1] >= declared[section - 1] {
      raise Invalid("line \{line_number}: too many records")
    }
    let fields = words(line)
    let has_backoff = fields.length() == section + 2
    if fields.length() != section + 1 && !has_backoff {
      raise Invalid("line \{line_number}: ngram field count mismatch")
    }
    let probability = parse_number(fields[0], line_number)
    let tokens = []
    for i = 1; i <= section; i = i + 1 {
      tokens.push(fields[i])
    }
    let backoff = if has_backoff {
      Some(parse_number(fields[section + 1], line_number))
    } else {
      None
    }
    records.push({ tokens, log_probability: probability, log_backoff: backoff, })
    observed[section - 1] += 1
  }
  if !ended {
    raise Invalid("missing end marker")
  }
  if observed != declared {
    raise Invalid("record count mismatch")
  }
  Model::new(declared.length(), records, limits~)
}
