import GFMarkdown

/-!
# Blog posts as data

Posts are Markdown files in `posts/`, named after their slug, each opening with a frontmatter
block:

    ---
    title: A general-purpose application in Lean, by construction
    excerpt: "One or two sentences, for the blog's index and the page's description."
    date: 2026-10-08
    draft: true
    ---

The body is GitHub-flavored Markdown, sanitized like the directory's readme, so raw HTML never
reaches a page. lean-markdown has no footnotes, so they are handled here: each `[^name]` becomes a
link to `#fn-name`, numbered in the order the notes are first cited, and each `[^name]: text` line
becomes one of the post's notes.

A draft is served by `leangineering serve` but left out of a static build unless `DRAFTS=1`.
-/

namespace Leangineering

open CommonMark.Parser (RawInline)

structure Note where
  name : String
  content : List RawInline

structure Post where
  slug : String
  title : String
  excerpt : String
  /-- `YYYY-MM-DD`. -/
  date : String
  draft : Bool
  body : GFMarkdown.Document
  notes : Array Note

namespace Post

def months : Array String :=
  #["January", "February", "March", "April", "May", "June", "July", "August", "September",
    "October", "November", "December"]

/-- `2026-10-08` as `October 8, 2026`. -/
def formatDate (date : String) : String :=
  match date.splitOn "-" |>.map String.toNat? with
  | [some y, some m, some d] => s!"{months.getD (m - 1) date} {d}, {y}"
  | _ => date

def unquote (s : String) : String :=
  if s.length ≥ 2 && s.startsWith "\"" && s.endsWith "\"" then ((s.drop 1).dropEnd 1).toString
  else s

/-- The `key: value` lines between an opening `---` and the next, and the text after them. -/
def splitFrontmatter (src : String) : List (String × String) × String :=
  match src.splitOn "\n" with
  | "---" :: rest =>
    let (front, body) := rest.span (· ≠ "---")
    let fields := front.filterMap fun line =>
      match line.splitOn ": " with
      | key :: value@(_ :: _) => some (key.trimAscii.toString, unquote (": ".intercalate value).trimAscii.toString)
      | _ => none
    (fields, "\n".intercalate (body.drop 1))
  | _ => ([], src)

def isNoteNameChar (c : Char) : Bool := c.isAlphanum || c == '-' || c == '_'

def validNoteName (name : String) : Bool := !name.isEmpty && name.all isNoteNameChar

/-- The note a `[^name]: text` line defines. -/
def noteDef? (line : String) : Option (String × String) :=
  if line.startsWith "[^" then
    match (line.drop 2).toString.splitOn "]: " with
    | name :: text@(_ :: _) => if validNoteName name then some (name, "]: ".intercalate text) else none
    | _ => none
  else none

/-- Replaces each `[^name]` with a link to the note, numbered in order of first citation.
Returns the rewritten text and the names in that order. -/
def citeNotes (text : String) : String × Array String :=
  match text.splitOn "[^" with
  | [] => (text, #[])
  | first :: parts =>
    parts.foldl (init := (first, #[])) fun (out, order) part =>
      match part.splitOn "]" with
      | name :: rest@(_ :: _) =>
        if validNoteName name then
          let order := if order.contains name then order else order.push name
          let n := (order.idxOf? name).getD 0 + 1
          (out ++ s!"[{n}](#fn-{name})" ++ "]".intercalate rest, order)
        else (out ++ "[^" ++ part, order)
      | _ => (out ++ "[^" ++ part, order)

def parseMarkdown (text : String) : GFMarkdown.Document :=
  (GFMarkdown.parseDocument text).sanitize

/-- A note's text as inline content. -/
def noteContent (text : String) : List RawInline :=
  match parseMarkdown text with
  | [.paragraph content] => content
  | _ => [.text text]

def parse (slug src : String) : Post :=
  let (fields, rest) := splitFrontmatter src
  let field (key : String) : String := (fields.lookup key).getD ""
  let lines := rest.splitOn "\n"
  let defs := lines.filterMap noteDef?
  let (body, cited) := citeNotes ("\n".intercalate (lines.filter (noteDef? · |>.isNone)))
  let named (name : String) : Option Note :=
    (defs.lookup name).map fun text => { name, content := noteContent text }
  let uncited := defs.filter (!cited.contains ·.1) |>.map (·.1)
  { slug
    title := field "title"
    excerpt := field "excerpt"
    date := field "date"
    draft := field "draft" == "true"
    body := parseMarkdown body
    notes := (cited ++ uncited.toArray).filterMap named }

end Post

/-- Every `*.md` file in `dir`, newest first. -/
def loadPosts (dir : System.FilePath) : IO (Array Post) := do
  unless ← dir.pathExists do return #[]
  let posts ← (← dir.readDir).filterMapM fun entry => do
    if entry.fileName.endsWith ".md" then
      let slug := (entry.fileName.dropEnd 3).toString
      return some (Post.parse slug (← IO.FS.readFile entry.path))
    else return none
  return posts.qsort (·.date > ·.date)

end Leangineering
