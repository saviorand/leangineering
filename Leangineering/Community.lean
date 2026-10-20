import Lean.Data.Json

/-!
# Posts from the community

The community page lists the posts in the `#blog-posts` forum on the Leangineer Discord. Each forum post is
a thread whose first message holds a link, and Discord's preview of that link gives the title and
description. A post without a link, such as a question, is skipped, and so is a post linking to
this site, since the blog page already lists those, and a post tagged
`Unlisted`, which is how an author keeps their post off the page. The forum's tag should be an
ordinary one, not a moderated one, so that authors can apply it to their own posts.

`leangineering sync-community` reads the forum through Discord's HTTP API as a bot, with the
bot's token in `DISCORD_BOT_TOKEN`, and saves the posts to `data/community.json`. The site reads
that snapshot, as it reads the awesome list's readme, so a build never needs the token or waits on
Discord. A sync that fails keeps the last snapshot.

The posts come from other people. Only a title, a link, a date, a plain-text excerpt and the
poster's name are kept, and lean-html escapes them like any other text. A link that isn't http or
https is dropped, so a post can't add a `javascript:` link either.
-/

namespace Leangineering

open Lean (Json FromJson ToJson fromJson? toJson)

/-- A post shared in the forum, linking to where it was published. -/
structure CommunityPost where
  title : String
  url : String
  /-- `YYYY-MM-DD`, when it was shared. -/
  date : String
  /-- Plain text. -/
  excerpt : String
  /-- Who shared it. -/
  author : String
  deriving Inhabited, FromJson, ToJson

namespace Discord

/-! ## Discord's API

Only the fields this module reads, under Discord's names. A field Discord can leave out is an
`Option`. -/

structure Tag where
  id : String
  name : String
  deriving FromJson

structure Forum where
  guild_id : String
  available_tags : Option (Array Tag)
  deriving FromJson

structure ThreadMetadata where
  archive_timestamp : String
  deriving FromJson

/-- A thread, which is what a forum post is. -/
structure Thread where
  id : String
  parent_id : Option String
  name : String
  applied_tags : Option (Array String)
  thread_metadata : Option ThreadMetadata
  deriving FromJson

structure Threads where
  threads : Array Thread
  has_more : Option Bool
  deriving FromJson

structure User where
  username : String
  global_name : Option String
  deriving FromJson

/-- A link's preview. -/
structure Embed where
  url : Option String
  title : Option String
  description : Option String
  deriving FromJson

structure Message where
  content : String
  /-- ISO 8601. -/
  timestamp : String
  author : User
  embeds : Array Embed
  deriving FromJson

/-! ## A forum post as a post on the page -/

def isWebUrl (url : String) : Bool := url.startsWith "https://" || url.startsWith "http://"

/-- The host a URL names, lowercased: `leangineer.com` for `https://Leangineer.com/blog/`. -/
def host (url : String) : String :=
  match url.splitOn "://" with
  | [_, rest] => (((rest.splitOn "/").headD "").splitOn ":").headD "" |>.toLower
  | _ => ""

/-- Whether a URL is on this site, whose own posts are on the blog page. -/
def isThisSite (url : String) : Bool :=
  let h := host url
  h == "leangineer.com" || h.endsWith ".leangineer.com"

/-- A URL without its trailing slash, so a link matches its preview with or without one. -/
def normalizeUrl (url : String) : String := (url.dropEndWhile (· == '/')).toString

/-- The web links in a message's text, in order. Discord's `<url>` and `[text](url)` forms are
unwrapped, and punctuation that ends a sentence is left off. -/
def links (text : String) : List String :=
  let spaced := text.map fun c => if c.isWhitespace || "<>()[]\"".contains c then ' ' else c
  (spaced.splitOn " ").map (fun w => (w.dropEndWhile fun (c : Char) => ".,;:!?".contains c).toString) |>.filter isWebUrl

/-- Whitespace collapsed to single spaces. -/
def collapse (s : String) : String :=
  " ".intercalate ((s.map fun c => if c.isWhitespace then ' ' else c).splitOn " " |>.filter (!·.isEmpty))

/-- How long an excerpt runs, in characters, before it's cut at a word. -/
def excerptLength : Nat := 300

def excerptOf (text : String) : String :=
  let text := collapse text
  if text.length ≤ excerptLength then text else
    match ((text.take excerptLength).toString.splitOn " ").dropLast with
    | [] => (text.take excerptLength).toString ++ "…"
    | words => " ".intercalate words ++ "…"

/-- `2026-10-18T09:12:45.123000+00:00` as `2026-10-18`. -/
def dateOf? (timestamp : String) : Option String :=
  match (timestamp.take 10).toString.splitOn "-" |>.map String.toNat? with
  | [some y, some m, some d] =>
    let pad (n : Nat) := if n < 10 then s!"0{n}" else toString n
    if 1 ≤ m && m ≤ 12 && 1 ≤ d && d ≤ 31 then some s!"{y}-{pad m}-{pad d}" else none
  | _ => none

/-- The post a forum thread shares: the first link in its first message, titled by Discord's
preview of that link, or else by the thread's own title. None if that link is to this site. -/
def post? (thread : Thread) (message : Message) : Option CommunityPost := do
  let url ← (links message.content).head?
  if isThisSite url then none
  let preview := message.embeds.find? (·.url.map normalizeUrl == some (normalizeUrl url))
  let title := collapse ((preview.bind (·.title)).getD thread.name)
  let date ← dateOf? message.timestamp
  if title.isEmpty then none
  else some { title, url, date,
              excerpt := excerptOf ((preview.bind (·.description)).getD ""),
              author := collapse (message.author.global_name.getD message.author.username) }

/-! ## Reading the forum -/

def api : String := "https://discord.com/api/v10"

/-- The form Discord asks bots to identify themselves in. -/
def userAgent : String := "DiscordBot (https://leangineer.com, 1)"

/-- One GET as the bot, with curl: the status and the body. The token goes to curl on its standard
input, so it never shows up in a process list. -/
def requestOnce (token path : String) : IO (Nat × String) := do
  let child ← IO.Process.spawn {
    cmd := "curl"
    args := #["-sS", "--proto", "=https", "--max-time", "30", "-A", userAgent, "-H", "@-",
              "-w", "\n%{http_code}", api ++ path]
    stdin := .piped, stdout := .piped, stderr := .piped }
  let (stdin, child) ← child.takeStdin
  stdin.putStr s!"Authorization: Bot {token}\n"
  stdin.flush
  let out ← child.stdout.readToEnd
  let err ← child.stderr.readToEnd
  unless (← child.wait) == 0 do throw (IO.userError s!"curl: {err.trimAscii}")
  let lines := out.splitOn "\n"
  return ((lines.getLast?.bind String.toNat?).getD 0, "\n".intercalate lines.dropLast)

/-- A GET as the bot, retried after the wait Discord asks for when it's rate limited. -/
def request (token path : String) (retries : Nat := 5) : IO (Nat × String) := do
  let (status, body) ← requestOnce token path
  match retries, status with
  | n + 1, 429 =>
    let seconds := (Json.parse body >>= (·.getObjValAs? Float "retry_after")).toOption.getD 1
    IO.sleep (seconds * 1000 + 100).toUInt32
    request token path n
  | _, _ => return (status, body)

/-- GET `path` and decode it, or `none` if it isn't there, such as a deleted message. -/
def get? [FromJson α] (token path : String) : IO (Option α) := do
  let (status, body) ← request token path
  if status == 404 then return none
  unless status == 200 do throw (IO.userError s!"GET {path}: HTTP {status}: {(body.take 200).toString}")
  match Json.parse body >>= fromJson? with
  | .ok a => return some a
  | .error e => throw (IO.userError s!"GET {path}: {e}")

def get [FromJson α] (token path : String) : IO α := do
  let some a ← get? token path | throw (IO.userError s!"GET {path}: HTTP 404")
  return a

/-- An `archive_timestamp` as a query parameter. -/
def encodeTimestamp (s : String) : String := (s.replace ":" "%3A").replace "+" "%2B"

/-- The forum's posts, open or archived, newest first, apart from those tagged `Unlisted`. -/
def fetchPosts (token forumId : String) : IO (Array CommunityPost) := do
  let forum : Forum ← get token s!"/channels/{forumId}"
  let unlisted := (forum.available_tags.getD #[]).filter (·.name.toLower == "unlisted") |>.map (·.id)
  let active : Threads ← get token s!"/guilds/{forum.guild_id}/threads/active"
  let mut threads := active.threads.filter (·.parent_id == some forumId)
  -- Forum posts are archived after a few days without messages, so most of them are here.
  let mut before := ""
  for _ in [0:100] do
    let page : Threads ← get token s!"/channels/{forumId}/threads/archived/public?limit=100{before}"
    threads := threads ++ page.threads
    match page.has_more, page.threads.back?.bind (·.thread_metadata) with
    | some true, some last => before := s!"&before={encodeTimestamp last.archive_timestamp}"
    | _, _ => break
  let mut posts := #[]
  for thread in threads do
    if (thread.applied_tags.getD #[]).any unlisted.contains then continue
    -- A forum post's first message has the thread's ID.
    let some (message : Message) ← get? token s!"/channels/{thread.id}/messages/{thread.id}" | continue
    if let some post := post? thread message then posts := posts.push post
  return posts.qsort (·.date > ·.date)

end Discord

/-! ## The snapshot -/

/-- Reads the forum's posts into `snapshot`. Without a token, or if Discord fails, the last
snapshot stays. -/
def syncCommunity (forumId : String) (snapshot : System.FilePath) : IO Unit := do
  let token := (← IO.getEnv "DISCORD_BOT_TOKEN").getD ""
  if token.isEmpty then
    IO.eprintln s!"warning: DISCORD_BOT_TOKEN isn't set; keeping {snapshot}"
    return
  try
    let posts ← Discord.fetchPosts token forumId
    IO.FS.writeFile snapshot ((toJson posts).pretty ++ "\n")
    IO.println s!"{posts.size} posts from the forum in {snapshot}"
  catch e =>
    IO.eprintln s!"warning: reading the forum failed: {e}; keeping {snapshot}"

/-- The posts in `snapshot`, newest first. A missing or unreadable snapshot is a warning, and the
rest of the site still builds. -/
def loadCommunity (snapshot : System.FilePath) : IO (Array CommunityPost) := do
  unless ← snapshot.pathExists do return #[]
  match Json.parse (← IO.FS.readFile snapshot) >>= fromJson? (α := Array CommunityPost) with
  | .ok posts => return posts.qsort (·.date > ·.date)
  | .error e =>
    IO.eprintln s!"warning: {snapshot}: {e}"
    return #[]

end Leangineering
