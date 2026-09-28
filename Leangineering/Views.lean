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
-/

namespace Leangineering.Views

open Html

def sourceUrl : String := "https://github.com/saviorand/leangineering"
def listUrl : String := "https://github.com/saviorand/awesome-lean"
def datastarJs : String :=
  "https://cdn.jsdelivr.net/gh/starfederation/datastar@v1.0.4/bundles/datastar.js"

/-- A "∀" on the site's green, inlined so it needs no route or file. -/
def favicon : String :=
  "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'%3E%3Crect width='32' height='32' rx='6' fill='%232d5a3f'/%3E%3Ctext x='16' y='23' font-size='20' text-anchor='middle' fill='%23f3efe6' font-family='Georgia,serif'%3E%E2%88%80%3C/text%3E%3C/svg%3E"

def inlines (content : List CommonMark.Inline) : List (Node .phrasing) :=
  CommonMark.inlineListNodes content

def categoryHref (c : Category) : String := s!"/awesome/{c.slug}"

def layout (pageTitle description : String) (content : List (Node .flow))
    (interactive : Bool) : String :=
  document (lang := "en") [
    head ([
      meta_ [("charset", "utf-8")],
      meta_ [("name", "viewport"), ("content", "width=device-width, initial-scale=1")],
      title pageTitle,
      meta_ [("name", "description"), ("content", description)],
      link { rel := "preconnect", href := "https://fonts.googleapis.com" },
      link { rel := "stylesheet",
             href := "https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&family=Newsreader:ital,opsz,wght@0,6..72,500;1,6..72,400&display=swap" },
      link { rel := "stylesheet", href := "/static/site.css" },
      link { rel := "icon", href := favicon }
    ] ++ (if interactive then [script { src := datastarJs } [("type", "module")]] else [])),
    body [
      header [
        nav [
          a { href := "/", class_ := "brand" } [ "leangineering" ],
          span [
            a { href := "/awesome" } [ "Awesome Lean" ],
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
          a { href := "https://github.com/saviorand/datastar-lean" } [ "datastar-lean" ], ". ",
          a { href := sourceUrl } [ "Read the source" ], "."
        ]
      ] { class_ := "site-footer" }
    ]
  ]

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

/-- A category's entries, headed by a link to its own page. -/
def categorySection (c : Category) : Node .flow :=
  section_ ([
    h2 [ a { href := categoryHref c } [ (c.title : Node .phrasing) ],
         span [ (toString c.entryCount : Node .phrasing) ] { class_ := "count" } ]
  ] ++ c.groups.toList.flatMap groupNodes) { id := c.slug, class_ := "category" }

def categoryNav (site : Awesome) : Node .flow :=
  nav [
    ul (site.categories.toList.map fun c =>
      li [ a { href := categoryHref c } [
             (c.title : Node .phrasing),
             span [ (toString c.entryCount : Node .phrasing) ] { class_ := "count" } ] ])
  ] { class_ := "category-nav" }

def results (site : Awesome) (query : String) : Node .flow :=
  let q := query.trimAscii.toString
  if q.isEmpty then
    div (site.categories.toList.map categorySection) { id := "results" }
  else
    let found := site.search q
    let n := found.foldl (· + ·.entryCount) 0
    div ([
      p [ (s!"{n} {if n == 1 then "match" else "matches"} for “{q}”" : Node .phrasing) ]
        { class_ := "result-summary" }
    ] ++ found.toList.map categorySection) { id := "results" }

def searchBox : Node .flow :=
  div [
    input { type := "search", placeholder := "Search libraries and tools…", class_ := "search" }
      [ ("aria-label", "Search the list"),
        ("data-bind:q", ""),
        ("data-on:input__debounce.150ms", "@get('/awesome/search')") ]
  ] { class_ := "search-box" }

def homePage (site : Awesome) (interactive : Bool) : String :=
  layout "Leangineering: Lean 4 for software engineers"
    "A community and learning resource for software engineers using Lean 4." (interactive := interactive) [
    section_ [
      h1 [ "Lean 4 for software engineers" ],
      p [ "Lean is a programming language you can prove things about. Leangineering is about the programming part: libraries, tools, and how to build real software with them." ]
        { class_ := "lede" }
    ] { class_ := "hero" },
    div [
      a { href := "/awesome", class_ := "card" } [
        span [ "Awesome Lean" ] { class_ := "card-title" },
        span [ (s!"{site.entryCount} libraries, tools and projects in {site.categories.size} categories" : Node .phrasing) ]
          { class_ := "card-body" }
      ],
      div [
        p [ span [ "Guides" ] { class_ := "card-title" } ],
        p [ "Building web apps, FFI, and Lean for Rust and Haskell developers. Every code sample on this site will be compiled." ]
          { class_ := "card-body" },
        p [ "Coming soon" ] { class_ := "soon" }
      ] { class_ := "card muted" }
    ] { class_ := "cards" },
    section_ [
      h2 [ "This site is written in Lean" ],
      p [ "Pages are typed HTML values, so bad nesting is a compile error. The directory is parsed from the ",
          a { href := listUrl } [ "awesome-lean" ],
          " readme with a Markdown parser proved to produce well-formed HTML, and search streams results over server-sent events with Datastar." ]
    ] { class_ := "about" }
  ]

def awesomePage (site : Awesome) (interactive : Bool) : String :=
  layout "Awesome Lean: libraries and tools for Lean 4"
    s!"A curated directory of {site.entryCount} Lean 4 libraries, tools and projects for programmers."
    (interactive := interactive) ([
    section_ ([
      h1 [ "Awesome Lean" ],
      p (inlines site.tagline) { class_ := "lede" }
    ] ++ site.intro.toList.map (fun para => p (inlines para)) ++ [
      p [ (s!"{site.entryCount} entries, curated in the " : Node .phrasing),
          a { href := listUrl } [ "awesome-lean" ],
          " repository. Suggest additions there." ] { class_ := "meta" }
    ]) { class_ := "hero" }
  ] ++ (if interactive then [searchBox] else []) ++ [
    categoryNav site,
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
    h1 [ (c.title : Node .phrasing) ]
  ] ++ c.intro.toList.map (fun para => p (inlines para) { class_ := "lede" }) ++
    c.groups.toList.flatMap groupNodes ++ [
    nav [
      match prev with
      | some p' => a { href := categoryHref p' } [ (s!"← {p'.title}" : Node .phrasing) ]
      | none => span [],
      match next with
      | some n => a { href := categoryHref n } [ (s!"{n.title} →" : Node .phrasing) ]
      | none => span []
    ] { class_ := "pager" }
  ])

def notFoundPage (interactive : Bool) : String :=
  layout "Not found: Leangineering" "Page not found." (interactive := interactive) [
    h1 [ "Not found" ],
    p [ "There's nothing here. Try the ", a { href := "/awesome" } [ "directory" ], "." ]
  ]

end Leangineering.Views
