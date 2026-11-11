///|
fn main {
  let args = @env.args()
  if args.length() != 2 {
    println("MoonARPA: pass one JSON request argument; see docs/protocol.md")
  } else {
    println(@arpa.handle(args[1]))
  }
}
