import CommonMark

/-!
# The awesome-lean-programming list as data

`parse` turns the awesome-lean-programming readme into categories and entries. The readme stays the single
source of truth: this module only reads the structure the awesome format already has.

- `##` headings are categories, and `###` headings are subcategories of the `##` above them.
- A paragraph that is entirely bold (`**Games**`) starts a group within a category.
- Other paragraphs before the first entry are the category's intro.
- List items of the form `[Name](url) - Description` are entries.
-/

namespace Leangineering

open CommonMark

structure Entry where
  name : String
  url : String
  description : List Inline
  deriving Inhabited

structure Group where
  label : Option String
  entries : Array Entry
  deriving Inhabited

structure Category where
  title : String
  slug : String
  /-- The `##` heading a `###` category sits under, e.g. "Libraries". -/
  parent : Option String
  intro : Array (List Inline)
  groups : Array Group
  deriving Inhabited

structure Awesome where
  tagline : List Inline
  intro : Array (List Inline)
  categories : Array Category
  deriving Inhabited

/-- Sections of the readme that are about the list itself, not entries in it. -/
def skippedSections : List String := ["Contents", "Contributing", "Footnotes"]

def slugify (s : String) : String :=
  let dashed := String.ofList (s.toLower.toList.map fun c => if c.isAlphanum then c else '-')
  "-".intercalate ((dashed.splitOn "-").filter (!·.isEmpty))

def containsSubstr (haystack needle : String) : Bool :=
  needle.isEmpty || (haystack.splitOn needle).length > 1

namespace Entry

/-- `owner/repo` for GitHub links. -/
def githubRepo? (e : Entry) : Option String :=
  let prefix_ := "https://github.com/"
  if e.url.startsWith prefix_ then
    match ((e.url.drop prefix_.length).toString.splitOn "/").filter (!·.isEmpty) with
    | owner :: repo :: _ => some s!"{owner}/{repo}"
    | _ => none
  else none

def searchText (e : Entry) (c : Category) : String :=
  s!"{e.name} {plainTextOfInlines e.description} {c.title}".toLower

end Entry

namespace Category

def entries (c : Category) : Array Entry := c.groups.flatMap (·.entries)

def entryCount (c : Category) : Nat := c.groups.foldl (· + ·.entries.size) 0

/-- Keeps only the entries whose text contains every word of `query`. Empty groups are dropped. -/
def filter (c : Category) (query : String) : Category :=
  let words := (query.toLower.splitOn " ").filter (!·.isEmpty)
  let keep (e : Entry) := let t := e.searchText c; words.all (containsSubstr t ·)
  { c with groups := c.groups.filterMap fun g =>
      let es := g.entries.filter keep
      if es.isEmpty then none else some { g with entries := es } }

end Category

namespace Awesome

def entryCount (a : Awesome) : Nat := a.categories.foldl (· + ·.entryCount) 0

def find? (a : Awesome) (slug : String) : Option Category := a.categories.find? (·.slug == slug)

def search (a : Awesome) (query : String) : Array Category :=
  (a.categories.map (·.filter query)).filter (·.entryCount > 0)

end Awesome

/-- Splits `[Name](url) - Description` into an entry. -/
def parseEntry? (item : List Block) : Option Entry :=
  match item with
  | .paragraph (.link url _ label :: rest) :: _ =>
    let description := match rest with
      | .text s :: more =>
        let s' := if s.startsWith " - " then (s.drop 3).toString else s
        if s'.isEmpty then more else .text s' :: more
      | other => other
    some { name := plainTextOfInlines label, url, description }
  | _ => none

private structure State where
  tagline : List Inline := []
  intro : Array (List Inline) := #[]
  categories : Array Category := #[]
  /-- The current `##` heading, used as the parent of `###` categories. -/
  section_ : Option String := none
  skipping : Bool := false

private def State.modifyCurrent (st : State) (f : Category → Category) : State :=
  match st.categories.back? with
  | some c => { st with categories := st.categories.pop.push (f c) }
  | none => st

private def State.startCategory (st : State) (title : String) (parent : Option String) : State :=
  let c : Category := { title, slug := slugify title, parent, intro := #[], groups := #[] }
  { st with categories := st.categories.push c }

private def State.addEntries (st : State) (es : Array Entry) : State :=
  st.modifyCurrent fun c =>
    match c.groups.back? with
    | some g => { c with groups := c.groups.pop.push { g with entries := g.entries ++ es } }
    | none => { c with groups := #[{ label := none, entries := es }] }

def parse (markdown : String) : Awesome := Id.run do
  let mut st : State := {}
  for block in parseDocument markdown do
    match block with
    | .heading level content =>
      let title := plainTextOfInlines content
      if level.val == 1 then
        st := { st with section_ := some title, skipping := skippedSections.contains title }
        if !st.skipping then st := st.startCategory title none
      else if level.val == 2 && !st.skipping then
        st := st.startCategory title st.section_
    | .blockQuote [.paragraph content] =>
      if st.categories.isEmpty then st := { st with tagline := content }
    | .paragraph [.strong label] =>
      if !st.skipping then
        st := st.modifyCurrent fun c =>
          { c with groups := c.groups.push { label := some (plainTextOfInlines label), entries := #[] } }
    | .paragraph content =>
      if st.section_.isNone then st := { st with intro := st.intro.push content }
      else if !st.skipping then
        st := st.modifyCurrent fun c =>
          if c.groups.isEmpty then { c with intro := c.intro.push content } else c
    | .list _ _ items =>
      if !st.skipping && st.section_.isSome then
        st := st.addEntries (items.filterMap parseEntry?).toArray
    | _ => pure ()
  -- A `##` heading that only groups `###` subsections (like "Libraries") has no entries itself.
  return { tagline := st.tagline, intro := st.intro,
           categories := st.categories.filter (·.entryCount > 0) }

end Leangineering
