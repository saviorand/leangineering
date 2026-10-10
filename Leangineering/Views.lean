import Html
import CommonMark
import GFMarkdown
import Leangineering.Awesome
import Leangineering.Blog

/-!
# Pages

Every page is a typed `Html.Node` tree, so markup nesting is checked by the compiler and all text
is escaped. Entry descriptions come from the readme's Markdown and are rendered by
`CommonMark.inlineListNodes`, which also produces `Html.Node`s, so no raw HTML is involved apart
from `themeScript`, a constant.

`Mode` says whether a server is behind the page and where the site is mounted. With a server,
search streams results over SSE. In a static build, every entry carries its search text and
Datastar filters in the browser, with the matching in `static/search.js`. Internal links are
relative and resolved by a `<base>` tag, so a static build also works under a subpath like
`/leangineering/` on GitHub Pages.

The design is a maths paper: Computer Modern, black on white, numbered sections, a table of
contents, and a theorem whose proof is Lean's own infoview.
-/

namespace Leangineering.Views

open Html

def sourceUrl : String := "https://github.com/saviorand/leangineering"
def listUrl : String := "https://github.com/saviorand/awesome-lean-programming"
def discordUrl : String := "https://discord.gg/ACKNs7ZJPj"
def datastarJs : String :=
  "https://cdn.jsdelivr.net/gh/starfederation/datastar@v1.0.4/bundles/datastar.js"
def cmuSerifCss : String := "https://cdn.jsdelivr.net/npm/computer-modern@0.1.3/cmu-serif.css"
def monoCss : String :=
  "https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;700&display=swap"

/-- Applies the theme the reader picked, if any, before the page is first drawn, so a reader who
picked the other theme from their system's never sees a flash of it. Without a pick, the
stylesheet follows the system. A constant, so it goes in with `Node.unsafeRaw`. -/
def themeScript : String :=
  "<script>try { var t = localStorage.getItem('theme'); " ++
  "if (t === 'light' || t === 'dark') document.documentElement.dataset.theme = t } catch (e) {}</script>"

/-- The theme button's click: system, then light, then dark, then the system's again. The pick is
remembered; going back to the system's forgets it. The stylesheet draws the button for each. -/
def themeToggle : String :=
  "var d = document.documentElement, t = d.dataset.theme, " ++
  "n = t === 'light' ? 'dark' : t === 'dark' ? '' : 'light'; " ++
  "try { if (n) { d.dataset.theme = n; localStorage.setItem('theme', n) } " ++
  "else { delete d.dataset.theme; localStorage.removeItem('theme') } } catch (e) {}"

/-- An SVG as a `data:` URI, escaping only what a URI or a quoted attribute can't hold. -/
def svgDataUri (svg : String) : String :=
  "data:image/svg+xml," ++ String.join (svg.toList.map fun
    | '%' => "%25" | '#' => "%23" | '<' => "%3C" | '>' => "%3E"
    | '"' => "'" | ' ' => "%20" | '\n' => "" | c => c.toString)

def inlines (content : List CommonMark.Inline) : List (Node .phrasing) :=
  CommonMark.inlineListNodes content

structure Mode where
  /-- A server is behind the page, so search goes over SSE. -/
  interactive : Bool
  /-- Where the site is mounted, with a trailing slash. -/
  base : String := "/"
  /-- The logo as a `data:` URI (see `svgDataUri`), so the favicon needs no route or file. -/
  favicon : String := ""

def Mode.server : Mode := { interactive := true }

def categoryHref (c : Category) : String := s!"awesome/{c.slug}"

/-- The category's section number, from 1. Stable under search filtering. -/
def sectionNumber (site : Awesome) (c : Category) : Nat :=
  (site.categories.findIdx? (·.slug == c.slug)).getD 0 + 1

def layout (pageTitle description : String) (content : List (Node .flow))
    (mode : Mode) : String :=
  document (lang := "en") [
    head ([
      meta_ [("charset", "utf-8")],
      Node.unsafeRaw themeScript,
      base { href := mode.base },
      meta_ [("name", "viewport"), ("content", "width=device-width, initial-scale=1")],
      title pageTitle,
      meta_ [("name", "description"), ("content", description)],
      link { rel := "stylesheet", href := cmuSerifCss },
      link { rel := "stylesheet", href := monoCss },
      link { rel := "stylesheet", href := "static/site.css" }
    ] ++ (if mode.favicon.isEmpty then [] else [link { rel := "icon", href := mode.favicon }])
      ++ (if mode.interactive then [] else [script { src := "static/search.js" }])
      ++ [script { src := datastarJs } [("type", "module")]]),
    body [
      header [
        nav [
          a { href := "./", class_ := "brand" } [ "Leangineering" ],
          span [
            a { href := "blog" } [ "Blog" ],
            a { href := "awesome" } [ "Directory" ],
            a { href := discordUrl } [ "Discord" ],
            a { href := sourceUrl } [ "Source" ],
            button [] { type := "button", class_ := "theme-toggle" }
              [("aria-label", "Theme: system, light or dark"), ("title", "Theme: system, light or dark"),
               ("onclick", themeToggle)]
          ] { class_ := "nav-links" }
        ]
      ] { class_ := "site-header" },
      main content,
      footer [
        p [
          "Built in Lean with ",
          a { href := "https://github.com/paulbutcher/lean-html" } [ "lean-html" ], ", ",
          a { href := "https://github.com/paulbutcher/lean-routing" } [ "lean-routing" ], ", ",
          a { href := "https://github.com/paulbutcher/lean-markdown" } [ "lean-markdown" ], " and ",
          a { href := "https://github.com/starfederation/datastar-lean" } [ "datastar-lean" ], ". Set in Computer Modern. ",
          a { href := sourceUrl } [ "Source on GitHub" ], "."
        ]
      ] { class_ := "site-footer" }
    ]
  ]

/-! ## Paper furniture -/

def sectionHeading (n : Nat) (content : List (Node .phrasing)) (id : Option String := none) : Node .flow :=
  h2 ([ span [ (s!"{n}" : Node .phrasing) ] { class_ := "sec-num" } ] ++ content) { id := id }

def qed : Node .flow := p [ "∎" ] { class_ := "qed" }

/-! ## The listing and the infoview -/

def tk (cls : String) (s : String) : Node .phrasing := span [ (s : Node .phrasing) ] { class_ := cls }
def kw := tk "tk-kw"
def str := tk "tk-str"
def cm := tk "tk-cm"

/-- Real code from this site, lightly abridged. -/
def editorPane : Node .flow :=
  div [
    div [ span [ "Main.lean" ] ] { class_ := "pane-bar" },
    pre [
      cm "-- the routes this page was served from", "\n",
      kw "route_table", " Site", "\n",
      "  [ home     := ", str "\"/\"", ",\n",
      "    awesome  := ", str "\"/awesome\"", ",\n",
      "    category := ", str "\"/awesome/:slug:String\"", " ]", "\n\n",
      kw "def", " hero : Node .flow :=", "\n",
      "  h1 [ ", str "\"Lean 4 for Software Engineers\"", " ]", "\n\n",
      kw "theorem", " site_is_written_in_lean : True := ", kw "by", "\n",
      "  ", kw "trivial", span [] { class_ := "caret" }
    ] { class_ := "pane-code" }
  ] { class_ := "pane" }

def infoview : Node .flow :=
  div [
    div [ span [ "Lean Infoview" ] ] { class_ := "pane-bar" },
    div [
      p [ "▼ Main.lean:10:2" ] { class_ := "iv-loc" },
      p [ "No goals" ] { class_ := "iv-done" },
      p [ span [ "✓" ] { class_ := "iv-tick" }, " Goals accomplished" ] { class_ := "iv-win" }
    ] { class_ := "pane-body" }
  ] { class_ := "pane" }

/-! ## Directory -/

/-- Attributes that let Datastar hide an element whose search text doesn't match `$q`. -/
def filterAttrs (texts : List String) : List (String × String) :=
  [("data-s", "\n".intercalate texts), ("data-show", "window.lgMatchAny($q, el.dataset.s)")]

def entryItem (c : Category) (filter : Bool) (e : Entry) : Node .listItem :=
  li [
    a { href := e.url, class_ := "entry-name" } [ (e.name : Node .phrasing) ],
    span (inlines e.description) { class_ := "entry-desc" },
    match e.githubRepo? with
    | some repo => span [ (repo : Node .phrasing) ] { class_ := "entry-repo" }
    | none => span [] { class_ := "entry-repo" }
  ] { class_ := "entry" } (if filter then filterAttrs [e.searchText c] else [])

def groupNodes (c : Category) (filter : Bool) (g : Group) : List (Node .flow) :=
  [div ((match g.label with
         | some label => [h3 [ (label : Node .phrasing) ] { class_ := "group-label" }]
         | none => []) ++
        [ul (g.entries.toList.map (entryItem c filter)) { class_ := "entries" }])
    { class_ := "group" }
    (if filter then filterAttrs (g.entries.toList.map (·.searchText c)) else [])]

def categorySection (site : Awesome) (filter : Bool) (c : Category) : Node .flow :=
  section_ ([
    sectionHeading (sectionNumber site c) [
      a { href := categoryHref c } [ (c.title : Node .phrasing) ],
      span [ (toString c.entryCount : Node .phrasing) ] { class_ := "count" } ]
  ] ++ c.groups.toList.flatMap (groupNodes c filter)) { id := c.slug, class_ := "category" }
    (if filter then filterAttrs (c.entries.toList.map (·.searchText c)) else [])

/-- A table of contents with dot leaders; entry counts stand in for page numbers.
Hidden while a search is active, so results sit right under the search box. -/
def contents (site : Awesome) : Node .flow :=
  nav [
    h2 [ "Contents" ] { class_ := "toc-title" },
    ol (site.categories.toList.map fun c =>
      li [ a { href := categoryHref c } [
             span [ (s!"{sectionNumber site c}" : Node .phrasing) ] { class_ := "toc-num" },
             span [ (c.title : Node .phrasing) ] { class_ := "toc-label" },
             span [] { class_ := "toc-dots" },
             span [ (toString c.entryCount : Node .phrasing) ] { class_ := "toc-count" } ] ])
      { class_ := "toc-list" }
  ] { class_ := "toc" } [("data-show", "!$q")]

/-- The directory body. `query` is the server-side search; `filter` adds client-side filtering. -/
def results (site : Awesome) (query : String) (filter : Bool := false) : Node .flow :=
  let q := query.trimAscii.toString
  if q.isEmpty then
    div (site.categories.toList.map (categorySection site filter)) { id := "results" }
  else
    let found := site.search q
    let n := found.foldl (· + ·.entryCount) 0
    if n == 0 then
      div [
        p [ span [ "⊢ False" ] { class_ := "turnstile" },
            (s!" Nothing matches “{q}”. Maybe nobody has built it yet? Sounds like your next project." : Node .phrasing) ]
          { class_ := "result-summary" }
      ] { id := "results" }
    else
      div ([
        p [ span [ "⊢" ] { class_ := "turnstile" },
            (s!" {n} {if n == 1 then "match" else "matches"} for “{q}”" : Node .phrasing) ]
          { class_ := "result-summary" }
      ] ++ found.toList.map (categorySection site false)) { id := "results" }

def searchBox (mode : Mode) : Node .flow :=
  let serverSearch := [("data-on:input__debounce.150ms", "@get('/search')")]
  let field : Node .flow := label [
      span [ "#find" ] { class_ := "search-cmd" },
      input { type := "search", placeholder := "postgres, ffi, parser…", class_ := "search" }
        ([ ("aria-label", "Search the directory"),
           ("autocomplete", "off"),
           ("data-bind:q", "") ] ++ (if mode.interactive then serverSearch else []))
    ] { class_ := "search-field" }
  div ([field] ++ (if mode.interactive then [] else
    -- The static build's stand-in for the server's `⊢ N matches` line.
    [p [] { class_ := "result-summary" }
       [("data-show", "$q.trim() != ''"), ("data-text", "window.lgSummary($q)")]]))
    { class_ := "search-box" }

/-! ## Pages -/

def homePage (site : Awesome) (mode : Mode) : String :=
  layout "Leangineering: Lean 4 for software engineers"
    "A community and learning resource for software engineers using Lean 4." (mode := mode) [
    div [
      h1 [ "Lean 4 for Software Engineers" ],
      p [ "leangineer.com · ", a { href := discordUrl } [ "Join the Discord" ] ] { class_ := "venue" }
    ] { class_ := "title-block" },
    div [
      h2 [ "Abstract" ] { class_ := "abstract-title" },
      p [ "Lean is not just for mathematicians anymore. You can use it to build real software, today. Lean is a compiled functional language that happens to also be a theorem prover. Most of what's written about it is about the proving part. This site is about the programming part: libraries, tools, and how to actually ship things with them. No category theory required." ]
    ] { class_ := "abstract" },
    section_ [
      sectionHeading 1 [ "The directory" ],
      p [ (s!"Awesome Lean Programming collects {site.entryCount} libraries, tools and projects for building software in Lean, in {site.categories.size} sections: web servers, databases, FFI, parsers, and more. It's searchable, and it's generated from the " : Node .phrasing),
          a { href := listUrl } [ "awesome-lean-programming" ], " list, so a PR there shows up here too." ],
      p [ a { href := "awesome", class_ := "button" } [ "Browse the directory" ] ]
    ],
    section_ [
      sectionHeading 2 [ "Guides" ],
      p [ "Hands-on guides: web apps, FFI, and Lean for people coming from Rust, Haskell or TypeScript. Every code sample here gets compiled, so if it's on the site, it works." ],
      p [ span [ "sorry" ] { class_ := "sorry" }, " These aren't written yet." ] { class_ := "note" }
    ],
    section_ [
      sectionHeading 3 [ "How this site is built" ],
      div [
        p [ span [ "Theorem 1" ] { class_ := "thm-label" }, " (Written in Lean). ",
            em [ "Every page on this site is a typed HTML value produced by a Lean program." ] ]
      ] { class_ := "theorem" },
      div [
        p [ em [ "Proof." ], " Yes, really. Pages are built with lean-html, so if I put a ", code [ "<div>" ],
            " inside a ", code [ "<p>" ], ", it doesn't compile. The directory is parsed from the awesome-lean-programming readme with a Markdown parser that is proved to produce well-formed HTML. Search streams results from the server with Datastar, so there's no frontend build step and no client-side state to manage. The routes are in Figure 1; the infoview agrees." ],
        figure [
          div [ editorPane, infoview ] { class_ := "panes" },
          figcaption [ p [ span [ "Figure 1." ] { class_ := "fig-label" },
                           " The route table this page was served from, and Lean's verdict." ] ]
        ],
        qed
      ] { class_ := "proof" },
      p [ "I think that's a pretty good demo of what Lean can do outside of math. ",
          a { href := sourceUrl } [ "The code is open source" ], ", if you want to see how it's done." ]
    ],
    section_ [
      sectionHeading 4 [ "About the author" ],
      p [ "Hi, I'm ", a { href := "https://valentin.wiki" } [ "Valentin" ],
          ". I made ", a { href := "https://github.com/saviorand/lightbug_http" } [ "Lightbug" ],
          ", the first HTTP framework for Mojo, and ", a { href := "https://github.com/saviorand/datastar-lean" } [ "datastar-lean" ],
          ". I'm collecting what I learn about writing real software in Lean here. Hit me up on ",
          a { href := "https://bsky.app/profile/a2svior.bsky.social" } [ "Bluesky" ], " or on the ",
          a { href := "https://leanprover.zulipchat.com/" } [ "Lean Zulip" ], " if you have questions or ideas." ]
    ]
  ]

def awesomePage (site : Awesome) (mode : Mode) : String :=
  layout "Awesome Lean Programming: libraries and tools for Lean 4"
    s!"A curated directory of {site.entryCount} Lean 4 libraries, tools and projects for programmers."
    (mode := mode) ([
    div [
      h1 [ "Awesome Lean Programming" ],
      p (inlines site.tagline) { class_ := "venue" }
    ] { class_ := "title-block" },
    div ([
      h2 [ "Abstract" ] { class_ := "abstract-title" }
    ] ++ site.intro.toList.map (fun para => p (inlines para)) ++ [
      p [ (s!"{site.entryCount} entries, curated in the " : Node .phrasing),
          a { href := listUrl } [ "awesome-lean-programming" ],
          " repo. Missing something? Open a PR there, and it shows up here too." ]
    ]) { class_ := "abstract" }
  ] ++ [
    searchBox mode,
    contents site,
    results site "" (filter := !mode.interactive)
  ])

def categoryPage (site : Awesome) (c : Category) (mode : Mode) : String :=
  let idx := (site.categories.findIdx? (·.slug == c.slug)).getD 0
  let prev := if idx == 0 then none else site.categories[idx - 1]?
  let next := site.categories[idx + 1]?
  let crumb : List (Node .phrasing) :=
    [a { href := "awesome" } [ "Awesome Lean Programming" ]] ++
    (match c.parent with
     | some parent => [(s!" / {parent}" : Node .phrasing)]
     | none => [])
  layout s!"{c.title}: Awesome Lean Programming"
    s!"{c.entryCount} Lean 4 projects in {c.title}, from the Awesome Lean Programming directory."
    (mode := mode) ([
    p crumb { class_ := "crumb" },
    h1 [ span [ (s!"{sectionNumber site c}" : Node .phrasing) ] { class_ := "sec-num" },
         (c.title : Node .phrasing) ] { class_ := "category-title" },
    p [ (s!"{c.entryCount} entries" : Node .phrasing) ] { class_ := "venue" }
  ] ++ c.intro.toList.map (fun para => p (inlines para)) ++
    c.groups.toList.flatMap (groupNodes c false) ++ [
    nav [
      match prev with
      | some p' => a { href := categoryHref p' } [ (s!"← §{idx} {p'.title}" : Node .phrasing) ]
      | none => span [],
      match next with
      | some n' => a { href := categoryHref n' } [ (s!"§{idx + 2} {n'.title} →" : Node .phrasing) ]
      | none => span []
    ] { class_ := "pager" }
  ])

def notFoundPage (mode : Mode) : String :=
  layout "Not found: Leangineering" "Page not found." (mode := mode) [
    div [
      p [ "error: unknown identifier ‘page’" ] { class_ := "error-line" },
      h1 [ "Not found" ],
      p [ "Nothing here. Maybe I haven't written it yet. In the meantime, the ",
          a { href := "awesome" } [ "directory" ], " has 300+ things to look at." ]
    ] { class_ := "title-block" }
  ]

/-! ## Blog

A post renders as a paper. `##` headings are numbered sections. A paragraph that opens in bold with
a theorem-like label (`**Lemma 1 (Routing).**`) is set as a theorem, its statement in italics. One
that opens with `*Proof.*` starts a proof, which runs to the block ending in `∎`. As in a paper,
the ∎ ends the proof's last line, or stands on a line of its own after a code block. A paragraph holding only an image is a numbered figure, captioned with
the image's alt text. Lean code blocks get the same keyword, string and comment styles as the home
page's listing.
-/

open CommonMark.Parser (RawInline)

def postHref (post : Post) : String := s!"blog/{post.slug}"

def leanKeywords : List String :=
  ["def", "theorem", "lemma", "inductive", "structure", "class", "instance", "where", "match",
   "with", "fun", "by", "do", "let", "if", "then", "else", "return", "namespace", "end", "open",
   "import", "deriving", "abbrev", "route_table"]

def isIdentChar (c : Char) : Bool := c.isAlphanum || c == '_' || c == '.' || c == '?' || c == '!'

/-- Consecutive characters of the same kind, by `p`. -/
def runs (p : Char → Bool) (cs : List Char) : List (List Char) :=
  cs.foldr (init := []) fun c acc =>
    match acc with
    | (d :: ds) :: rest => if p c == p d then (c :: d :: ds) :: rest else [c] :: acc
    | _ => [c] :: acc

/-- One line of Lean, with keywords, string literals and a trailing comment marked. -/
def highlightLine (line : String) : List (Node .phrasing) :=
  let (source, comment) := match line.splitOn "--" with
    | first :: rest@(_ :: _) => (first, some ("--" ++ "--".intercalate rest))
    | _ => (line, none)
  let segments := source.splitOn "\""
  let code := segments.zipIdx.flatMap fun (segment, i) =>
    if i % 2 == 1 then
      [str ("\"" ++ segment ++ (if i + 1 < segments.length then "\"" else ""))]
    else (runs isIdentChar segment.toList).map fun run =>
      let word := String.ofList run
      if leanKeywords.contains word then kw word else (word : Node .phrasing)
  code ++ (match comment with | some c => [cm c] | none => [])

def codeBlock (info : Option String) (literal : String) : Node .flow :=
  let text := (literal.dropEndWhile (· == '\n')).toString
  let body : List (Node .phrasing) :=
    if info == some "lean" then ((text.splitOn "\n").map highlightLine).intersperse [("\n" : Node .phrasing)] |>.flatten
    else [(text : Node .phrasing)]
  div [ pre body { class_ := "pane-code" } ] { class_ := "pane code-block" }

/-- Straight quotes as curly ones: a quote after a space, a bracket or nothing opens, any other
closes, so an apostrophe comes out right. Code is left alone, since it never reaches here. -/
def curlQuotes (s : String) : String :=
  let opensAfter (prev : Option Char) : Bool := match prev with
    | none => true
    | some c => c.isWhitespace || c == '(' || c == '['
  String.ofList <| (s.toList.foldl (init := ([], none)) fun (out, prev) c =>
    let c' := match c with
      | '"' => if opensAfter prev then '“' else '”'
      | '\'' => if opensAfter prev then '‘' else '’'
      | c => c
    (c' :: out, some c)).1.reverse

/-- Inline content, with a link to `#fn-name` set as a superscript note number. -/
def postInline (post : Post) : RawInline → List (Node .phrasing)
  | i@(.link dest _ content) =>
    if dest.startsWith "#fn-" then
      let name := (dest.drop 4).toString
      [sup [ a { href := s!"{postHref post}#fn-{name}", id := s!"fnref-{name}" }
               (GFMarkdown.inlineListNodes content) ] { class_ := "fn-ref" }]
    else GFMarkdown.inlineNodes i
  | .text s => [(curlQuotes s : Node .phrasing)]
  | i => GFMarkdown.inlineNodes i

def postInlines (post : Post) (content : List RawInline) : List (Node .phrasing) :=
  content.flatMap (postInline post)

def theoremKinds : List String :=
  ["Theorem", "Lemma", "Definition", "Corollary", "Proposition", "Problem", "Remark"]

/-- `Lemma 1 (Routing).` as `("Lemma 1", some "Routing")`, if it names a theorem-like kind. -/
def theoremLabel? (bold : String) : Option (String × Option String) :=
  let s := bold.trimAscii.toString
  if !s.endsWith "." then none else
    let s := (s.dropEnd 1).toString
    let (label, name) := match s.splitOn " (" with
      | [label, rest] => if rest.endsWith ")" then (label, some (rest.dropEnd 1).toString) else (s, none)
      | _ => (s, none)
    if theoremKinds.any (label.startsWith ·) then some (label, name) else none

def trimStart : List RawInline → List RawInline
  | .text s :: rest => .text s.trimAsciiStart.toString :: rest
  | content => content

/-- A theorem-like paragraph. Problems and remarks are discussion, so only statements are italic. -/
def theoremBlock (post : Post) (label : String) (name : Option String)
    (statement : List RawInline) : Node .flow :=
  let body := postInlines post (trimStart statement)
  let italic := !(label.startsWith "Problem" || label.startsWith "Remark")
  div [
    p ([ span [ (label : Node .phrasing) ] { class_ := "thm-label" },
         ((match name with | some n => s!" ({n}). " | none => ". ") : Node .phrasing) ] ++
       (if italic then [em body] else body))
  ] { class_ := "theorem" }

/-- The paragraph without a closing `∎`, and whether it had one. -/
def stripQed (content : List RawInline) : List RawInline × Bool :=
  match content.getLast? with
  | some (.text s) =>
    let t := s.trimAsciiEnd.toString
    if t.endsWith "∎" then
      let rest := (t.dropEnd 1).trimAsciiEnd.toString
      (content.dropLast ++ (if rest.isEmpty then [] else [.text rest]), true)
    else (content, false)
  | _ => (content, false)

structure PaperState where
  sections : Array (Node .flow) := #[]
  number : Nat := 0
  heading : Option (List (Node .phrasing)) := none
  current : Array (Node .flow) := #[]
  /-- The blocks of an open proof. -/
  proof : Option (Array (Node .flow)) := none
  figures : Nat := 0

namespace PaperState

def emit (st : PaperState) (n : Node .flow) : PaperState :=
  match st.proof with
  | some blocks => { st with proof := some (blocks.push n) }
  | none => { st with current := st.current.push n }

/-- Closes the open proof, with a ∎ of its own unless its last paragraph already ends in one. -/
def closeProof (st : PaperState) (marked := false) : PaperState :=
  match st.proof with
  | some blocks =>
    let blocks := if marked then blocks else blocks.push (p [ "∎" ] { class_ := "qed post-qed" })
    { st with proof := none, current := st.current.push (div blocks.toList { class_ := "proof" }) }
  | none => st

def closeSection (st : PaperState) : PaperState :=
  let st := st.closeProof
  if st.current.isEmpty && st.heading.isNone then st else
    let heading := match st.heading with
      | some h => [sectionHeading st.number h]
      | none => []
    { st with sections := st.sections.push (section_ (heading ++ st.current.toList)), current := #[] }

end PaperState

def qedMark : Node .phrasing := span [ "∎" ] { class_ := "qed-mark" }

/-- A proof's paragraph, ending in ∎ if it closes the proof. -/
def proofParagraph (post : Post) (lead : List (Node .phrasing)) (content : List RawInline)
    (done : Bool) : Node .flow :=
  p (lead ++ postInlines post content ++ (if done then [qedMark] else []))

def paperStep (post : Post) (st : PaperState) : GFMarkdown.Block → PaperState
  | .heading level content =>
    if level.val ≤ 1 then
      let st := st.closeSection
      { st with number := st.number + 1, heading := some (postInlines post content) }
    else st.emit (GFMarkdown.headingNode level (postInlines post content))
  | .paragraph content =>
    if st.proof.isSome then
      let (content, done) := stripQed content
      if content.isEmpty then (if done then st.closeProof else st)
      else
        let st := st.emit (proofParagraph post [] content done)
        if done then st.closeProof (marked := true) else st
    else match content with
      | .emph [.text t] :: rest =>
        if t.startsWith "Proof" then
          let (rest, done) := stripQed rest
          let st := { st with proof := some #[proofParagraph post [em [(t : Node .phrasing)]] rest done] }
          if done then st.closeProof (marked := true) else st
        else st.emit (p (postInlines post content))
      | .strong [.text bold] :: rest =>
        match theoremLabel? bold with
        | some (label, name) => st.emit (theoremBlock post label name rest)
        | none => st.emit (p (postInlines post content))
      | [.image dest _ alt] =>
        let n := st.figures + 1
        { st.emit (figure [
            (img { src := CommonMark.percentEncodeUri dest, alt := GFMarkdown.plainTextOfList alt } : Node .flow),
            figcaption [ p ([ span [ (s!"Figure {n}." : Node .phrasing) ] { class_ := "fig-label" },
                              (" " : Node .phrasing) ] ++ postInlines post alt) ] ])
          with figures := n }
      | _ => st.emit (p (postInlines post content))
  | .codeBlock info literal => st.emit (codeBlock info literal)
  | .table header alignments rows =>
    st.emit (div [GFMarkdown.tableNode header alignments rows] { class_ := "table-wrap" })
  | .thematicBreak => st
  | b => (GFMarkdown.renderBlockNodesF false 1000 b).foldl PaperState.emit st

def paperBody (post : Post) : List (Node .flow) :=
  (post.body.foldl (paperStep post) {}).closeSection.sections.toList

def notesSection (post : Post) : List (Node .flow) :=
  if post.notes.isEmpty then [] else
    [section_ [
      h2 [ "Notes" ] { class_ := "notes-title" },
      ol (post.notes.toList.map fun note =>
        li ((postInlines post note.content ++
              [(" " : Node .phrasing), a { href := s!"{postHref post}#fnref-{note.name}", class_ := "fn-back" } [ "↩" ]]).map
              Node.toFlow) { id := s!"fn-{note.name}" })
    ] { class_ := "notes" }]

def blogPage (posts : Array Post) (mode : Mode) : String :=
  layout "Blog: Leangineering" "Writing about building software in Lean 4." (mode := mode) [
    div [
      h1 [ "Blog" ],
      p [ "Writing about building software in Lean" ] { class_ := "venue" }
    ] { class_ := "title-block" },
    if posts.isEmpty then p [ "Nothing here yet." ] { class_ := "note" }
    else ul (posts.toList.map fun post =>
      li [
        a { href := postHref post, class_ := "post-title" } [ (post.title : Node .phrasing) ],
        span [ (Post.formatDate post.date ++ (if post.draft then " · draft" else "") : Node .phrasing) ]
          { class_ := "post-meta" },
        p [ (post.excerpt : Node .phrasing) ] { class_ := "post-excerpt" }
      ] { class_ := "post-item" }) { class_ := "post-list" }
  ]

def postPage (post : Post) (mode : Mode) : String :=
  layout s!"{post.title}: Leangineering" post.excerpt (mode := mode) ([
    div [
      h1 [ (post.title : Node .phrasing) ],
      p [ (Post.formatDate post.date ++ (if post.draft then " · draft" else "") : Node .phrasing), " · ",
          a { href := "blog" } [ "Blog" ] ] { class_ := "venue" }
    ] { class_ := "title-block" },
    div [
      h2 [ "Abstract" ] { class_ := "abstract-title" },
      p [ (post.excerpt : Node .phrasing) ]
    ] { class_ := "abstract" },
    article (paperBody post) { class_ := "post" }
  ] ++ notesSection post)

end Leangineering.Views
