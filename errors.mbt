///|
pub(all) suberror ArpaError {
  Invalid(String)
  Budget(String)
  Missing(String)
} derive(Debug)

///|
/// Limits apply before allocations or bounded inner loops.
pub(all) struct Limits {
  max_order : Int32
  max_records : Int32
  max_text : Int32
  max_tokens : Int32
  max_work : Int32
} derive(Debug, Eq)

///|
pub fn Limits::default() -> Limits {
  {
    max_order: 8,
    max_records: 200000,
    max_text: 16000000,
    max_tokens: 1000000,
    max_work: 2000000,
  }
}

///|
fn Limits::validate(self : Limits) -> Unit raise ArpaError {
  if self.max_order < 1 ||
    self.max_order > 8 ||
    self.max_records < 1 ||
    self.max_records > 1000000 ||
    self.max_text < 1 ||
    self.max_text > 256000000 ||
    self.max_tokens < 1 ||
    self.max_tokens > 10000000 ||
    self.max_work < 1 ||
    self.max_work > 100000000 {
    raise Invalid("limits outside supported integer-safe bounds")
  }
}

///|
fn finite(value : Double) -> Bool {
  value == value && value != @double.infinity && value != @double.neg_infinity
}

///|
fn valid_log(value : Double) -> Bool {
  finite(value) || value == @double.neg_infinity
}

///|
fn token_valid(token : String) -> Bool {
  if token.is_empty() {
    return false
  }
  for ch in token {
    if ch.is_whitespace() || ch.to_int() < 32 || ch.to_int() == 127 {
      return false
    }
  }
  true
}

///|
/// Splits on Unicode whitespace without linguistic tokenization or normalization.
pub fn words(text : String) -> Array[String] {
  let output = []
  let mut current : Array[Char] = []
  for ch in text {
    if ch.is_whitespace() {
      if !current.is_empty() {
        output.push(String::from_array(current))
        current = []
      }
    } else {
      current.push(ch)
    }
  }
  if !current.is_empty() {
    output.push(String::from_array(current))
  }
  output
}

///|
fn gram_key(tokens : Array[String]) -> String {
  tokens.join("\u{001f}")
}

///|
fn parse_number(text : String, line : Int32) -> Double raise ArpaError {
  let value = if text == "-inf" || text == "-Infinity" {
    @double.neg_infinity
  } else {
    @string.parse_double(text) catch {
      _ => raise Invalid("line \{line}: invalid number")
    }
  }
  if !valid_log(value) {
    raise Invalid("line \{line}: non-finite number")
  }
  value
}

///|
fn positive_count(text : String, line : Int32) -> Int32 raise ArpaError {
  let value = @string.parse_int(text) catch {
    _ => raise Invalid("line \{line}: invalid count")
  }
  if value < 0 {
    raise Invalid("line \{line}: negative count")
  }
  value
}

///|
pub extend ArpaError with @debug.Debug::{to_repr}

///|
pub extend Limits with @debug.Debug::{to_repr}

///|
pub extend Limits with Eq::{equal, not_equal}
