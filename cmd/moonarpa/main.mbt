///|
#cfg(target="js")
fn request_offset() -> Int32 {
  2
}

///|
#cfg(not(target="js"))
fn request_offset() -> Int32 {
  1
}

///|
fn main {
  let args = @env.args()
  let offset = request_offset()
  if args.length() != offset + 1 {
    println("MoonARPA: pass one JSON request argument; see docs/protocol.md")
  } else {
    println(@arpa.handle(args[offset]))
  }
}
