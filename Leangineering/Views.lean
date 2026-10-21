import Html
import CommonMark
import GFMarkdown
import Leangineering.Awesome
import Leangineering.Blog
import Leangineering.Community

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

/-- Link previews need absolute URLs, which the `<base>` tag doesn't give. -/
def siteUrl : String := "https://leangineer.com/"
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

/-- What LinkedIn, Slack and the like show for a link to a post, as Open Graph tags. `path` is
relative to `siteUrl` and `image` is a file in `static/blog/`, or empty. -/
structure Preview where
  title : String
  path : String
  image : String

def Preview.tags (p : Preview) (description : String) : List (Node .flow) :=
  let prop (name content : String) : Node .flow := meta_ [("property", name), ("content", content)]
  [ prop "og:type" "article",
    prop "og:site_name" "Leangineering",
    prop "og:title" p.title,
    prop "og:description" description,
    prop "og:url" (siteUrl ++ p.path) ] ++
  (if p.image.isEmpty then [] else
    [ prop "og:image" s!"{siteUrl}static/blog/{p.image}",
      meta_ [("name", "twitter:card"), ("content", "summary_large_image")] ])

def layout (pageTitle description : String) (content : List (Node .flow))
    (mode : Mode) (preview : Option Preview := none) : String :=
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
    ] ++ (preview.map (·.tags description)).getD []
      ++ (if mode.favicon.isEmpty then [] else [link { rel := "icon", href := mode.favicon }])
      ++ (if mode.interactive then [] else [script { src := "static/search.js" }])
      ++ [script { src := datastarJs } [("type", "module")]]),
    body [
      header [
        nav [
          a { href := "./", class_ := "brand" } [ "Leangineering" ],
          span [
            a { href := "blog" } [ "Writing" ],
            a { href := "awesome" } [ "Directory" ],
            a { href := discordUrl, class_ := "nav-cta" } [ "Discord" ],
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

/-- The ∎ that ends a proof's last sentence. -/
def qedMark : Node .phrasing := span [ "∎" ] { class_ := "qed-mark" }

/-- The invitation to the Discord, set after the content a reader came for. -/
def discordInvite : Node .flow :=
  div [
    p [ "The ", a { href := discordUrl } [ "Leangineer Discord" ],
        " is a place for people who build software with Lean, or want to. You don't need a maths background. Come ask questions and share what you're working on." ],
    p [ a { href := discordUrl, class_ := "button" } [ "Join the Discord" ] ]
  ] { class_ := "invite" }

/-! ## The listing and the infoview -/

def tk (cls : String) (s : String) : Node .phrasing := span [ (s : Node .phrasing) ] { class_ := cls }
def kw := tk "tk-kw"
def str := tk "tk-str"
def cm := tk "tk-cm"

/-- Real code from this site, lightly abridged, and a `#check` of the lean-html theorem that its
escaping rests on. The infoview shows what Lean prints for that `#check`. -/
def editorPane : Node .flow :=
  div [
    div [ span [ "Main.lean" ] ] { class_ := "pane-bar" },
    pre [
      cm "-- the routes this page was served from", "\n",
      kw "route_table", " Site", "\n",
      "  [ home     := ", str "\"/\"", ",\n",
      "    blog     := ", str "\"/blog\"", ",\n",
      "    awesome  := ", str "\"/awesome\"", ",\n",
      "    category := ", str "\"/awesome/:slug:String\"", " ]", "\n\n",
      kw "def", " hero : Node .flow :=", "\n",
      "  h1 [ ", str "\"Lean 4 for Software Engineers\"", " ]", "\n\n",
      cm "-- what lean-html proves about escaping", "\n",
      kw "#check", " escape_safe", span [] { class_ := "caret" }
    ] { class_ := "pane-code" }
  ] { class_ := "pane" }

def infoview : Node .flow :=
  div [
    div [ span [ "Lean Infoview" ] ] { class_ := "pane-bar" },
    div [
      p [ "▼ Main.lean:12:0" ] { class_ := "iv-loc" },
      p [ "Html.escape_safe\n  (s : String) (c : Char) :\n  c ∈ (escape s).toList →\n    c ≠ '<' ∧ c ≠ '>' ∧\n    c ≠ '\\\"'" ]
        { class_ := "iv-type" }
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

def postHref (post : Post) : String := s!"blog/{post.slug}"

/-- A post in a list: its title, its date and its excerpt. -/
def postItem (post : Post) : Node .listItem :=
  li [
    a { href := postHref post, class_ := "post-title" } [ (post.title : Node .phrasing) ],
    span [ (Post.formatDate post.date ++ (if post.draft then " · draft" else "") : Node .phrasing) ]
      { class_ := "post-meta" },
    p [ (post.excerpt : Node .phrasing) ] { class_ := "post-excerpt" }
  ] { class_ := "post-item" }

/-! ## From the Discord

Posts shared in `#blog-posts` join the site's own on the writing page, and projects shared in
`#projects-and-repos` head the directory. They link to where they were published. Everything here
comes from other people, so it's only ever text, which lean-html escapes.
-/

/-- `carlo-hamalainen.net` for `https://www.carlo-hamalainen.net/2026/10/18/post/`. -/
def siteName (url : String) : String :=
  let h := Discord.host url
  if h.startsWith "www." then (h.drop 4).toString else h

/-- A post shared in `#blog-posts`: its title, linking to where it was published, who shared it,
on which site and when, and how it starts. -/
def sharedPostItem (post : CommunityPost) : Node .listItem :=
  li (([
    a { href := post.url, class_ := "post-title" } [ (post.title : Node .phrasing) ],
    span [ (s!"{post.author} · {siteName post.url} · {Post.formatDate post.date}" : Node .phrasing) ]
      { class_ := "post-meta" }
  ] : List (Node .flow)) ++
    (if post.excerpt.isEmpty then [] else [p [ (post.excerpt : Node .phrasing) ] { class_ := "post-excerpt" }]))
    { class_ := "post-item shared" }

/-- The site's posts and the ones shared in `#blog-posts`, newest first. -/
def writingItems (posts : Array Post) (shared : Array CommunityPost) : List (Node .listItem) :=
  let items := posts.map (fun p => (p.date, postItem p)) ++ shared.map (fun p => (p.date, sharedPostItem p))
  (items.qsort (·.1 > ·.1)).toList.map (·.2)

/-- A project shared in `#projects-and-repos`, set like a directory entry: its name, who shared it
and when, and its repository, or else its site. -/
def projectItem (project : CommunityPost) : Node .listItem :=
  li [
    a { href := project.url, class_ := "entry-name" } [ (project.title : Node .phrasing) ],
    span [ (s!"{project.author} · {Post.formatDate project.date}" : Node .phrasing) ] { class_ := "entry-desc" },
    span [ ((githubRepo? project.url).getD (siteName project.url) : Node .phrasing) ] { class_ := "entry-repo" }
  ] { class_ := "entry" }

/-- How many recent projects the directory shows. Older ones make their way into the curated list. -/
def recentProjectCount : Nat := 5

/-- How many posts, and recent projects, the home page lists before pointing to the full page. -/
def homePostCount : Nat := 3

def homePage (site : Awesome) (posts : Array Post) (community : Community) (mode : Mode) : String :=
  let writing := writingItems posts community.writing
  layout "Leangineering: Lean 4 for software engineers"
    "A community for people who use Lean 4 to build software." (mode := mode) [
    div [
      h1 [ "Lean 4 for Software Engineers" ],
      p [ "leangineer.com · ", a { href := discordUrl } [ "Join the Discord" ] ] { class_ := "venue" }
    ] { class_ := "title-block" },
    div [
      h2 [ "Abstract" ] { class_ := "abstract-title" },
      p [ "Lean 4 is best known as a theorem prover for mathematics. It's also a compiled functional language you can build real software with today." ],
      p [ "Leangineering is a community for people who use Lean for software engineering and computer science." ],
      p [ "Start with the ", a { href := "awesome" } [ "directory of Lean libraries and tools" ], ", or read ",
          a { href := "blog" } [ "writing about real projects" ], " built with them." ]
    ] { class_ := "abstract" },
    section_ ([
      sectionHeading 1 [ "The directory" ],
      p [ (s!"Awesome Lean Programming is a directory of {site.entryCount} libraries, tools and projects for building software in Lean." : Node .phrasing) ]
    ] ++ (if community.projects.isEmpty then [] else [
      h3 [ "Recent projects" ] { class_ := "group-label" },
      ul ((community.projects.toList.take homePostCount).map projectItem) { class_ := "entries" }
    ]) ++ [
      p [ "Built something in Lean? Share it in #projects-and-repos on the ", a { href := discordUrl } [ "Discord" ], "." ],
      p [ a { href := "awesome", class_ := "button" } [ "Browse the directory" ] ]
    ]),
    section_ ([
      sectionHeading 2 [ "Writing" ],
      if writing.isEmpty then p [ "Nothing here yet." ] { class_ := "note" }
      else ul (writing.take homePostCount) { class_ := "post-list" },
      p [ "Written about Lean? Share it in #blog-posts on the ", a { href := discordUrl } [ "Discord" ], "." ]
    ] ++ (if writing.length > homePostCount then [p [ a { href := "blog", class_ := "button" } [ "All writing" ] ]] else [])),
    section_ [
      sectionHeading 3 [ "How this site is built" ],
      div [
        p [ span [ "Theorem 1" ] { class_ := "thm-label" }, " (Written in Lean). ",
            em [ "Every page on this site is a typed HTML value produced by a Lean program." ] ]
      ] { class_ := "theorem" },
      div [
        p [ em [ "Proof." ], " Pages are built with lean-html, so a ", code [ "<div>" ],
            " inside a ", code [ "<p>" ], " is a compile error. The directory comes from the awesome-lean-programming readme, which the site sanitizes and turns into lean-html nodes as well. Search streams results from the server with Datastar, so there's no frontend build step. Figure 1 shows part of the code.",
            qedMark ]
      ] { class_ := "proof" },
      figure [
        div [ editorPane, infoview ] { class_ := "panes" },
        figcaption [ p [ span [ "Figure 1." ] { class_ := "fig-label" },
                         " Some of the code behind this page. On the right, Lean's infoview shows the theorem lean-html proves about escaping." ] ]
      ],
      p [ "The ", a { href := sourceUrl } [ "site's code" ], " is open source if you want to see how it's done or improve it." ]
    ],
    section_ [
      sectionHeading 4 [ "Community" ],
      p [ "Most of the conversation happens on the Discord. Beginners and people without a maths background are welcome." ],
      p [ a { href := discordUrl, class_ := "button" } [ "Join the Discord" ] ]
    ]
  ]

def awesomePage (site : Awesome) (projects : Array CommunityPost) (mode : Mode) : String :=
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
          " repo. Missing something? Open a PR there and it shows up here too, or mention it on the ",
          a { href := discordUrl } [ "Discord" ], "." ]
    ]) { class_ := "abstract" }
  ] ++ (if projects.isEmpty then [] else [
    section_ [
      h2 [ "Recent projects" ] { class_ := "toc-title" },
      ul ((projects.toList.take recentProjectCount).map projectItem) { class_ := "entries" },
      p [ "Shared in #projects-and-repos on the ", a { href := discordUrl } [ "Discord" ], "." ] { class_ := "note" }
    ] { class_ := "recent-projects" }
  ]) ++ [
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
      p [ "Nothing here. Maybe it hasn't been written yet. In the meantime, the ",
          a { href := "awesome" } [ "directory" ], " has 300+ things to look at. If you were looking for something specific, ask on the ",
          a { href := discordUrl } [ "Discord" ], "." ]
    ] { class_ := "title-block" }
  ]

/-! ## Blog

A post renders as a paper. `##` headings are numbered sections. A paragraph that opens in bold with
a theorem-like label (`**Lemma 1 (Routing).**`) is set as a theorem, its statement in italics. One
that opens with `*Proof.*` starts a proof, which runs to the block ending in `∎`. The ∎ follows
the proof's last sentence. A proof that ends in a code block gets a ∎ on a line of its own, but
reads better ending in a sentence. A paragraph holding only an image is a numbered figure, captioned
with the image's alt text. Lean code blocks get the same keyword, string and comment styles as the home
page's listing.
-/

open CommonMark.Parser (RawInline)

def leanKeywords : List String :=
  ["def", "theorem", "lemma", "inductive", "structure", "class", "instance", "where", "match",
   "with", "fun", "by", "do", "let", "if", "then", "else", "return", "namespace", "end", "open",
   "import", "deriving", "abbrev", "route_table"]

def isIdentChar (c : Char) : Bool := c.isAlphanum || c == '_' || c == '.' || c == '?' || c == '!'

/-- Keywords after which the next word is the name being defined. -/
def definingKeywords : List String :=
  ["def", "theorem", "lemma", "inductive", "structure", "class", "abbrev"]

/-- `String` and `Db.UserRow` are types, by Lean's naming convention; `Service.deleteComment` is not. -/
def isTypeName (word : String) : Bool :=
  ((word.splitOn ".").getLast?.bind (·.toList.head?)).any Char.isUpper

/-- One run of identifier characters, or of anything else, coloured. `afterDef` says whether the
run follows a defining keyword; the result says whether the next one does. -/
def highlightRun (afterDef : Bool) (run : List Char) : Node .phrasing × Bool :=
  let word := String.ofList run
  if !run.any isIdentChar then ((word : Node .phrasing), afterDef && run.all Char.isWhitespace)
  else if leanKeywords.contains word then (kw word, definingKeywords.contains word)
  else if afterDef then (tk "tk-def" word, false)
  else if run.all Char.isDigit then (tk "tk-num" word, false)
  else if isTypeName word then (tk "tk-ty" word, false)
  else ((word : Node .phrasing), false)

/-- Consecutive characters of the same kind, by `p`. -/
def runs (p : Char → Bool) (cs : List Char) : List (List Char) :=
  cs.foldr (init := []) fun c acc =>
    match acc with
    | (d :: ds) :: rest => if p c == p d then (c :: d :: ds) :: rest else [c] :: acc
    | _ => [c] :: acc

/-- `s` split at the double quotes that open or close string literals, skipping the one in the
character literal `'"'` and escaped ones inside strings. -/
def splitQuotes (s : String) : List String :=
  let rec go : List Char → List Char → Array String → Array String
    | [], cur, acc => acc.push (String.ofList cur.reverse)
    | '\'' :: '"' :: '\'' :: rest, cur, acc => go rest ('\'' :: '"' :: '\'' :: cur) acc
    | '\\' :: c :: rest, cur, acc => go rest (c :: '\\' :: cur) acc
    | '"' :: rest, cur, acc => go rest [] (acc.push (String.ofList cur.reverse))
    | c :: rest, cur, acc => go rest (c :: cur) acc
  (go s.toList [] #[]).toList

/-- One line of Lean, with keywords, string literals and a trailing comment marked. `inString` says
whether the line starts inside a string that an earlier line opened; the result says whether it
ends inside one. -/
def highlightLine (inString : Bool) (line : String) : List (Node .phrasing) × Bool :=
  let (source, comment) := if inString then (line, none) else match line.splitOn "--" with
    | first :: rest@(_ :: _) => (first, some ("--" ++ "--".intercalate rest))
    | _ => (line, none)
  let segments := splitQuotes source
  -- Segments alternate between code and string, starting with string inside an open one.
  let offset := if inString then 1 else 0
  let code := segments.zipIdx.flatMap fun (segment, i) =>
    if (i + offset) % 2 == 1 then
      [str ((if i > 0 then "\"" else "") ++ segment ++ (if i + 1 < segments.length then "\"" else ""))]
    else ((runs isIdentChar segment.toList).foldl (init := (#[], false)) fun (nodes, afterDef) run =>
      let (node, afterDef) := highlightRun afterDef run
      (nodes.push node, afterDef)).1.toList
  (code ++ (match comment with | some c => [cm c] | none => []),
   (segments.length - 1 + offset) % 2 == 1)

def codeBlock (info : Option String) (literal : String) : Node .flow :=
  let text := (literal.dropEndWhile (· == '\n')).toString
  let body : List (Node .phrasing) :=
    if info == some "lean" then
      let (lines, _) := (text.splitOn "\n").foldl (init := (#[], false)) fun (lines, inString) line =>
        let (nodes, inString) := highlightLine inString line
        (lines.push nodes, inString)
      lines.toList.intersperse [("\n" : Node .phrasing)] |>.flatten
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
  ["Theorem", "Lemma", "Definition", "Corollary", "Proposition", "Claim", "Observation", "Question",
   "Construction", "Problem", "Gap", "Remark"]

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

/-- A theorem-like paragraph. Constructions, problems, gaps and remarks are discussion, so only
statements are italic. -/
def theoremBlock (post : Post) (label : String) (name : Option String)
    (statement : List RawInline) : Node .flow :=
  let body := postInlines post (trimStart statement)
  let italic := !(label.startsWith "Construction" || label.startsWith "Problem" || label.startsWith "Gap" ||
    label.startsWith "Remark")
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

def blogPage (posts : Array Post) (shared : Array CommunityPost) (mode : Mode) : String :=
  let writing := writingItems posts shared
  layout "Writing: Leangineering" "Writing about building software in Lean 4, from this site and the community."
    (mode := mode) [
    div [
      h1 [ "Writing" ],
      p [ "About building software in Lean, from this site and the community" ] { class_ := "venue" }
    ] { class_ := "title-block" },
    if writing.isEmpty then p [ "Nothing here yet." ] { class_ := "note" }
    else ul writing { class_ := "post-list" },
    p [ "Have you written about Lean? Share it in #blog-posts on the ", a { href := discordUrl } [ "Discord" ],
        " and it shows up here." ]
  ]

def postPage (post : Post) (mode : Mode) : String :=
  layout s!"{post.title}: Leangineering" post.excerpt (mode := mode)
    (preview := some { title := post.title, path := s!"{postHref post}/", image := post.image }) ([
    div [
      h1 [ (post.title : Node .phrasing) ],
      p [ (Post.formatDate post.date ++ (if post.draft then " · draft" else "") : Node .phrasing), " · ",
          a { href := "blog" } [ "Writing" ] ] { class_ := "venue" }
    ] { class_ := "title-block" },
    div [
      h2 [ "Abstract" ] { class_ := "abstract-title" },
      p [ (post.excerpt : Node .phrasing) ]
    ] { class_ := "abstract" },
    article (paperBody post) { class_ := "post" },
    discordInvite
  ] ++ notesSection post)

end Leangineering.Views
