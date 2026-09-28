import Html
import CommonMark
import Leangineering.Awesome

/-!
# Pages

Every page is a typed `Html.Node` tree, so markup nesting is checked by the compiler and all text
is escaped. Entry descriptions come from the readme's Markdown and are rendered by
`CommonMark.inlineListNodes`, which also produces `Html.Node`s, so no raw HTML is involved.

`interactive` is true when a server is behind the page. Static builds leave out server-driven
features like search.

The design is a maths paper: Computer Modern, black on white, numbered sections, a table of
contents, and a theorem whose proof is Lean's own infoview.
-/

namespace Leangineering.Views

open Html

def sourceUrl : String := "https://github.com/saviorand/leangineering"
def listUrl : String := "https://github.com/saviorand/awesome-lean"
def datastarJs : String :=
  "https://cdn.jsdelivr.net/gh/starfederation/datastar@v1.0.4/bundles/datastar.js"
def cmuSerifCss : String := "https://cdn.jsdelivr.net/npm/computer-modern@0.1.3/cmu-serif.css"
def monoCss : String :=
  "https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;700&display=swap"

/-- A black "∀" on white, inlined so it needs no route or file. -/
def favicon : String :=
  "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'%3E%3Crect width='32' height='32' fill='%23111'/%3E%3Ctext x='16' y='24' font-size='22' text-anchor='middle' fill='%23fff' font-family='Georgia,serif'%3E%E2%88%80%3C/text%3E%3C/svg%3E"

def inlines (content : List CommonMark.Inline) : List (Node .phrasing) :=
  CommonMark.inlineListNodes content

def categoryHref (c : Category) : String := s!"/awesome/{c.slug}"

/-- The category's section number, from 1. Stable under search filtering. -/
def sectionNumber (site : Awesome) (c : Category) : Nat :=
  (site.categories.findIdx? (·.slug == c.slug)).getD 0 + 1

def layout (pageTitle description : String) (content : List (Node .flow))
    (interactive : Bool) : String :=
  document (lang := "en") [
    head ([
      meta_ [("charset", "utf-8")],
      meta_ [("name", "viewport"), ("content", "width=device-width, initial-scale=1")],
      title pageTitle,
      meta_ [("name", "description"), ("content", description)],
      link { rel := "stylesheet", href := cmuSerifCss },
      link { rel := "stylesheet", href := monoCss },
      link { rel := "stylesheet", href := "/static/site.css" },
      link { rel := "icon", href := favicon }
    ] ++ (if interactive then [script { src := datastarJs } [("type", "module")]] else [])),
    body [
      header [
        nav [
          a { href := "/", class_ := "brand" } [ "Leangineering" ],
          span [
            a { href := "/awesome" } [ "Directory" ],
            a { href := sourceUrl } [ "Source" ]
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
          a { href := "https://github.com/saviorand/datastar-lean" } [ "datastar-lean" ], ". Set in Computer Modern. ",
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

def entryItem (e : Entry) : Node .listItem :=
  li [
    a { href := e.url, class_ := "entry-name" } [ (e.name : Node .phrasing) ],
    span (inlines e.description) { class_ := "entry-desc" },
    match e.githubRepo? with
    | some repo => span [ (repo : Node .phrasing) ] { class_ := "entry-repo" }
    | none => span [] { class_ := "entry-repo" }
  ] { class_ := "entry" }

def groupNodes (g : Group) : List (Node .flow) :=
  (match g.label with
   | some label => [h3 [ (label : Node .phrasing) ] { class_ := "group-label" }]
   | none => []) ++
  [ul (g.entries.toList.map entryItem) { class_ := "entries" }]

def categorySection (site : Awesome) (c : Category) : Node .flow :=
  section_ ([
    sectionHeading (sectionNumber site c) [
      a { href := categoryHref c } [ (c.title : Node .phrasing) ],
      span [ (toString c.entryCount : Node .phrasing) ] { class_ := "count" } ]
  ] ++ c.groups.toList.flatMap groupNodes) { id := c.slug, class_ := "category" }

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

def results (site : Awesome) (query : String) : Node .flow :=
  let q := query.trimAscii.toString
  if q.isEmpty then
    div (site.categories.toList.map (categorySection site)) { id := "results" }
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
      ] ++ found.toList.map (categorySection site)) { id := "results" }

def searchBox : Node .flow :=
  div [
    label [
      span [ "#find" ] { class_ := "search-cmd" },
      input { type := "search", placeholder := "postgres, ffi, parser…", class_ := "search" }
        [ ("aria-label", "Search the directory"),
          ("autocomplete", "off"),
          ("data-bind:q", ""),
          ("data-on:input__debounce.150ms", "@get('/awesome/search')") ]
    ] { class_ := "search-field" }
  ] { class_ := "search-box" }

/-! ## Pages -/

def homePage (site : Awesome) (interactive : Bool) : String :=
  layout "Leangineering: Lean 4 for software engineers"
    "A community and learning resource for software engineers using Lean 4." (interactive := interactive) [
    div [
      h1 [ "Lean 4 for Software Engineers" ],
      p [ a { href := "https://valentin.wiki" } [ "Valentin Erokhin" ] ] { class_ := "author" },
      p [ "leangineering.com" ] { class_ := "venue" }
    ] { class_ := "title-block" },
    div [
      h2 [ "Abstract" ] { class_ := "abstract-title" },
      p [ "Lean is not just for mathematicians anymore. You can use it to build real software, today. Lean is a compiled functional language that happens to also be a theorem prover. Most of what's written about it is about the proving part. This site is about the programming part: libraries, tools, and how to actually ship things with them. No category theory required." ]
    ] { class_ := "abstract" },
    section_ [
      sectionHeading 1 [ "The directory" ],
      p [ (s!"Awesome Lean collects {site.entryCount} libraries, tools and projects for building software in Lean, in {site.categories.size} sections: web servers, databases, FFI, parsers, and more. It's searchable, and it's generated from the " : Node .phrasing),
          a { href := listUrl } [ "awesome-lean" ], " list, so a PR there shows up here too." ],
      p [ a { href := "/awesome", class_ := "button" } [ "Browse the directory" ] ]
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
            " inside a ", code [ "<p>" ], ", it doesn't compile. The directory is parsed from the awesome-lean readme with a Markdown parser that is proved to produce well-formed HTML. Search streams results from the server with Datastar, so there's no frontend build step and no client-side state to manage. The routes are in Figure 1; the infoview agrees." ],
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

def awesomePage (site : Awesome) (interactive : Bool) : String :=
  layout "Awesome Lean: libraries and tools for Lean 4"
    s!"A curated directory of {site.entryCount} Lean 4 libraries, tools and projects for programmers."
    (interactive := interactive) ([
    div [
      h1 [ "Awesome Lean" ],
      p (inlines site.tagline) { class_ := "venue" }
    ] { class_ := "title-block" },
    div ([
      h2 [ "Abstract" ] { class_ := "abstract-title" }
    ] ++ site.intro.toList.map (fun para => p (inlines para)) ++ [
      p [ (s!"{site.entryCount} entries, curated in the " : Node .phrasing),
          a { href := listUrl } [ "awesome-lean" ],
          " repo. Missing something? Open a PR there, and it shows up here too." ]
    ]) { class_ := "abstract" }
  ] ++ (if interactive then [searchBox] else []) ++ [
    contents site,
    results site ""
  ])

def categoryPage (site : Awesome) (c : Category) (interactive : Bool) : String :=
  let idx := (site.categories.findIdx? (·.slug == c.slug)).getD 0
  let prev := if idx == 0 then none else site.categories[idx - 1]?
  let next := site.categories[idx + 1]?
  let crumb : List (Node .phrasing) :=
    [a { href := "/awesome" } [ "Awesome Lean" ]] ++
    (match c.parent with
     | some parent => [(s!" / {parent}" : Node .phrasing)]
     | none => [])
  layout s!"{c.title}: Awesome Lean"
    s!"{c.entryCount} Lean 4 projects in {c.title}, from the Awesome Lean directory."
    (interactive := interactive) ([
    p crumb { class_ := "crumb" },
    h1 [ span [ (s!"{sectionNumber site c}" : Node .phrasing) ] { class_ := "sec-num" },
         (c.title : Node .phrasing) ] { class_ := "category-title" },
    p [ (s!"{c.entryCount} entries" : Node .phrasing) ] { class_ := "venue" }
  ] ++ c.intro.toList.map (fun para => p (inlines para)) ++
    c.groups.toList.flatMap groupNodes ++ [
    nav [
      match prev with
      | some p' => a { href := categoryHref p' } [ (s!"← §{idx} {p'.title}" : Node .phrasing) ]
      | none => span [],
      match next with
      | some n' => a { href := categoryHref n' } [ (s!"§{idx + 2} {n'.title} →" : Node .phrasing) ]
      | none => span []
    ] { class_ := "pager" }
  ])

def notFoundPage (interactive : Bool) : String :=
  layout "Not found: Leangineering" "Page not found." (interactive := interactive) [
    div [
      p [ "error: unknown identifier ‘page’" ] { class_ := "error-line" },
      h1 [ "Not found" ],
      p [ "Nothing here. Maybe I haven't written it yet. In the meantime, the ",
          a { href := "/awesome" } [ "directory" ], " has 300+ things to look at." ]
    ] { class_ := "title-block" }
  ]

end Leangineering.Views
