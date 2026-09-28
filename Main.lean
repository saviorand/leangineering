import Leangineering

/-!
    leangineering [serve]      # http://127.0.0.1:8080 (set PORT, and HOST=0.0.0.0 to listen publicly)
    leangineering build [dir]  # static site in `dir` (default `dist`), searched in the browser
                               # set BASE_PATH=/leangineering/ to host under a subpath

Both read `data/awesome-lean.md` and `static/site.css` from the working directory.
Run `scripts/sync-awesome.sh` to pull the latest list.
-/

open Std Async Http Server
open Leangineering

def dataPath : System.FilePath := "data/awesome-lean.md"
def cssPath : System.FilePath := "static/site.css"

def writePage (dir : System.FilePath) (path : String) (content : String) : IO Unit := do
  let file := dir / path
  if let some parent := file.parent then IO.FS.createDirAll parent
  IO.FS.writeFile file content

def build (site : Awesome) (css : String) (dir : System.FilePath) : IO Unit := do
  let base := (← IO.getEnv "BASE_PATH").getD "/"
  let mode : Views.Mode := { interactive := false, base := if base.endsWith "/" then base else base ++ "/" }
  writePage dir "index.html" (Views.homePage site mode)
  writePage dir "awesome/index.html" (Views.awesomePage site mode)
  for c in site.categories do
    writePage dir s!"awesome/{c.slug}/index.html" (Views.categoryPage site c mode)
  writePage dir "404.html" (Views.notFoundPage mode)
  writePage dir "static/site.css" css
  writePage dir "static/search.js" (← IO.FS.readFile "static/search.js")
  -- GitHub Pages: serve files as they are, without Jekyll.
  writePage dir ".nojekyll" ""
  IO.println s!"Wrote {site.categories.size + 3} pages to {dir} (base {mode.base})"

def serve (site : Awesome) (css : String) : IO Unit := Async.block do
  let port := ((← IO.getEnv "PORT").bind String.toNat?).getD 8080
  let public_ := (← IO.getEnv "HOST") == some "0.0.0.0"
  let host := if public_ then Net.IPv4Addr.ofParts 0 0 0 0 else .ofParts 127 0 0 1
  let server ← Server.serve (.v4 ⟨host, port.toUInt16⟩) (app site css)
  IO.println s!"Listening on http://{if public_ then "0.0.0.0" else "127.0.0.1"}:{port}"
  server.waitShutdown

def main (args : List String) : IO UInt32 := do
  let site := parse (← IO.FS.readFile dataPath)
  let css ← IO.FS.readFile cssPath
  match args with
  | [] | ["serve"] => serve site css; return 0
  | ["build"] => build site css "dist"; return 0
  | ["build", dir] => build site css dir; return 0
  | _ =>
    IO.eprintln "usage: leangineering [serve | build [dir]]"
    return 1
