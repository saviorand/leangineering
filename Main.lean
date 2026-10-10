import Leangineering

/-!
    leangineering [serve]      # http://127.0.0.1:8080 (set PORT, and HOST=0.0.0.0 to listen publicly)
    leangineering build [dir]  # static site in `dir` (default `dist`), searched in the browser
                               # set BASE_PATH=/leangineering/ to host under a subpath

Both read `data/awesome-lean.md`, `static/site.css` and `brand/logo.svg` from the working directory,
and the blog's posts from `posts/` and their images from `static/blog/`. A static build leaves out
draft posts unless `DRAFTS=1`.
Run `scripts/sync-awesome.sh` to pull the latest list.
-/

open Std Async Http Server
open Leangineering

def dataPath : System.FilePath := "data/awesome-lean.md"
def cssPath : System.FilePath := "static/site.css"
def logoPath : System.FilePath := "brand/logo.svg"
def postsDir : System.FilePath := "posts"
def assetsDir : System.FilePath := "static/blog"

/-- Every file in `static/blog/`, by name. -/
def loadAssets : IO (Array (String × ByteArray)) := do
  unless ← assetsDir.pathExists do return #[]
  (← assetsDir.readDir).mapM fun entry => return (entry.fileName, ← IO.FS.readBinFile entry.path)

def writePage (dir : System.FilePath) (path : String) (content : String) : IO Unit := do
  let file := dir / path
  if let some parent := file.parent then IO.FS.createDirAll parent
  IO.FS.writeFile file content

def build (site : Awesome) (posts : Array Post) (assets : Array (String × ByteArray))
    (css favicon : String) (dir : System.FilePath) : IO Unit := do
  let posts := if (← IO.getEnv "DRAFTS") == some "1" then posts else posts.filter (!·.draft)
  let base := (← IO.getEnv "BASE_PATH").getD "/"
  let mode : Views.Mode :=
    { interactive := false, base := if base.endsWith "/" then base else base ++ "/", favicon }
  writePage dir "index.html" (Views.homePage site mode)
  writePage dir "blog/index.html" (Views.blogPage posts mode)
  for post in posts do
    writePage dir s!"blog/{post.slug}/index.html" (Views.postPage post mode)
  IO.FS.createDirAll (dir / "static" / "blog")
  for (file, bytes) in assets do
    IO.FS.writeBinFile (dir / "static" / "blog" / file) bytes
  writePage dir "awesome/index.html" (Views.awesomePage site mode)
  for c in site.categories do
    writePage dir s!"awesome/{c.slug}/index.html" (Views.categoryPage site c mode)
  writePage dir "404.html" (Views.notFoundPage mode)
  writePage dir "static/site.css" css
  writePage dir "static/search.js" (← IO.FS.readFile "static/search.js")
  -- GitHub Pages: serve files as they are, without Jekyll.
  writePage dir ".nojekyll" ""
  IO.println s!"Wrote {site.categories.size + posts.size + 4} pages to {dir} (base {mode.base})"

def serve (site : Awesome) (posts : Array Post) (assets : Array (String × ByteArray))
    (css favicon : String) : IO Unit := Async.block do
  let port := ((← IO.getEnv "PORT").bind String.toNat?).getD 8080
  let public_ := (← IO.getEnv "HOST") == some "0.0.0.0"
  let host := if public_ then Net.IPv4Addr.ofParts 0 0 0 0 else .ofParts 127 0 0 1
  let server ← Server.serve (.v4 ⟨host, port.toUInt16⟩) (app site posts assets css { Views.Mode.server with favicon })
  IO.println s!"Listening on http://{if public_ then "0.0.0.0" else "127.0.0.1"}:{port}"
  server.waitShutdown

def main (args : List String) : IO UInt32 := do
  let site := parse (← IO.FS.readFile dataPath)
  let css ← IO.FS.readFile cssPath
  let favicon := Views.svgDataUri (← IO.FS.readFile logoPath)
  let posts ← loadPosts postsDir
  let assets ← loadAssets
  match args with
  | [] | ["serve"] => serve site posts assets css favicon; return 0
  | ["build"] => build site posts assets css favicon "dist"; return 0
  | ["build", dir] => build site posts assets css favicon dir; return 0
  | _ =>
    IO.eprintln "usage: leangineering [serve | build [dir]]"
    return 1
