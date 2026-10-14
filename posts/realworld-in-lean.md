---
title: An ordinary web application in Lean, by construction
excerpt: "I built RealWorld, the reference full-stack app with official test suites, entirely in Lean 4. Can it be done? Yes. Is it ready for production? Somewhat. Can it be made correct by construction? Partly. It can certainly be made more robust than the average full-stack app, though."
date: 2026-10-14
draft: false
---

![The home page, rendered on the server by Lean.](static/blog/realworld-home.png)

## Introduction

Lean 4 is a functional programming language in the same family as Haskell and OCaml. Most people know it as a proof assistant. Lately its standard library has also gained an HTTP server. The community is writing the other libraries that ordinary apps need too, like Postgres drivers, cryptography and HTML rendering.

So can you build a real web app in Lean yet? I built [RealWorld](https://github.com/realworld-apps/realworld) in it to find out. RealWorld is a well-known reference app, a Medium clone that comes with official test suites for its API and its website. My version is written entirely in Lean including the frontend, which uses datastar-lean for interactivity. The code is [on GitHub](https://github.com/saviorand/lean-realworld-example-app).

I've written this post like a math paper, mostly because it's fun and partly because it keeps the structure clear. Most of what follows is still plain engineering of the kind you would do in any language. The few things that are actually proved are marked as propositions. Lean checks those proofs every time the code builds.

## Existence

The first question is whether a RealWorld app can be built in Lean at all. The test suites turn that into something we can check.

**Definition 1.** A *RealWorld implementation* is a program that passes RealWorld's API suite and its website suite[^suites].

**Theorem 1.** There is a RealWorld implementation in Lean.

The proof is to build one. The test suites define what it has to do. The API tests send HTTP requests and check the JSON that comes back, so we need a server. The data in those answers has to be kept between requests, which means a database. The website tests click through the site in a real browser, so the server has to render pages as well.

**Construction 1 (The server).** Lean's standard library has had an HTTP server, `Std.Http`, since April. It takes care of all the low-level connection handling for you. On top of that server I use [lean-routing](https://github.com/paulbutcher/lean-routing) to declare the API's routes in a table. Each route has a path with typed parameters and gets its own handler. Read `←` in the code below as `await`:

```lean
route_table Api
  [ ...
    comment := "/api/articles/:slug:String/comments/:id:Nat",
    ... ]

def deleteComment (env : Env) (slug : String) (id : Nat) : Handler := fun req => respond do
  Service.deleteComment env (← requireUser env req) slug id
  noContent

def routes (env : Env) : List (Route Result) :=
  [ ...
    .delete patterns.comment (deleteComment env),
    ... ]
```

This handler deletes a comment. It checks the user's login token with `requireUser`, calls the service layer to delete the comment and replies with `204 No Content`. The website calls the same service layer and therefore follows exactly the same rules. Everything else comes from libraries, as it would in any language:

- [lean-json](https://github.com/paulbutcher/lean-json) for JSON
- [lean-libcrypto](https://github.com/paulbutcher/lean-libcrypto) for hashing passwords with OpenSSL's scrypt
- [lean-jose](https://github.com/paulbutcher/lean-jose) for the login tokens (JSON Web Tokens)
- [lean-middleware](https://github.com/paulbutcher/lean-middleware) for CORS, cookies and static files

**Construction 2 (The database).** The data lives in Postgres. I talk to it through [leanpostgres](https://github.com/paulbutcher/leanpostgres), which wraps Postgres's C client and keeps a pool of connections. You write the SQL right in the code. Each row that comes back is turned into a Lean structure:

```lean
def userByEmail (db : Conn) (email : String) : IO (Option UserRow) := do
  first (← db sql!"SELECT id, username, email, password_hash, bio, image FROM users
                     WHERE email = {email}")
```

The `{email}` inside `sql!` becomes a query parameter, which Postgres receives separately from the SQL text. So user input can never run as SQL. The database schema is plain SQL that [leanmigrate](https://github.com/paulbutcher/leanmigrate) applies when the server starts.

**Construction 3 (The website).** The pages are rendered on the server with [lean-html](https://github.com/paulbutcher/lean-html). There are no templates because the HTML is written as ordinary Lean functions. This one shows a comment, plus a trash icon if you wrote it:

```lean
def commentCard (viewer : Option Db.UserRow) (slug : String) (c : Db.CommentRow) : Node .flow :=
  let delete : List (Node .phrasing) :=
    if viewer.any (·.id == c.authorId) then
      [ span [ i [] { class_ := "ion-trash-a" } ] { class_ := "mod-options" }
          [onClick (action "delete" (Site.links.comment slug c.id.toInt.toNat))] ]
    else []
  div [
    div [ p [ c.body ] { class_ := "card-text" } ] { class_ := "card-block" },
    ...
  ] { class_ := "card", id := s!"comment-{c.id}" }
```

That `onClick` is all the frontend code needed to delete a comment. [Datastar](https://data-star.dev), a small script on the page, sends the `DELETE` request when you click the icon. It then updates the page with the server's reply. The server builds that reply with the same function the JSON API uses. There's no frontend build step because the pages are just HTML plus one script. On the server I use [datastar-lean](https://github.com/starfederation/datastar-lean), the official Lean SDK for Datastar that Carlo Hamalainen and I maintain.

![An article page. The body is Markdown rendered by lean-markdown, and the follow and favorite buttons update in place through Datastar.](static/blog/realworld-article.png)

*Proof of Theorem 1.* Put the three parts together and run both test suites against the result. They pass[^computation]. ∎

**Remark 1 (On cost).** The Lean backend comes to 1,033 lines, the shortest of the four implementations I compared[^loc]. The TypeScript one has 1,267 lines, the Go one 1,371 and the C# one 2,396. Ten of the eleven libraries it uses are by Paul Butcher. Claude Code and I contributed fixes to six of them along the way[^prs].

## Production

Passing tests on a laptop doesn't mean an app is ready for real users. So the second question is about production.

**Question 2.** Can the implementation of Theorem 1 serve real users?

There are two problems.

**Remark 2 (A young stack).** Lean's HTTP server maxes out at a few thousand requests per second per process. That's mostly due to a bug in Lean's runtime, which is already fixed but not yet released[^http]. Lean also ships a new version every month. New versions often break libraries[^stability]. Neither problem matters for a small site that pins its versions.

**Remark 3 (Who wrote it).** Almost none of this code was written by hand. Claude Code wrote the app at my direction. Most of the libraries were written the same way. It's all a few months old. Most of it has only one or two contributors[^contributors]. Code written this fast hasn't had many readers or users yet. So the kind of bugs you only find in real use are probably still in there.

The easiest parts to trust are the types and the theorems, because Lean checks them. Those hold no matter who or what wrote the code. The [instructions](https://github.com/paulbutcher/lean-html/blob/main/CLAUDE.md) the libraries give their AI agent push in this direction. They ask for "the strongest form a claim admits: a proven theorem over a property … over an example and an expected result". They also forbid using `sorry` as a placeholder for a missing proof. Several of the libraries do include real proofs. Code that no theorem covers is only as reliable as its tests. That goes double for the bindings to C libraries, where Lean can't check the C code at all.

You still need to read the proved parts, though. Lean checks that each proof is correct, but it can't check whether the theorem states what you actually need. Agents asked for proofs often prove things that don't matter. When Dan Luu had coding agents implement Zstd compression and told them to use Lean 4, they mostly proved arithmetic facts that missed the bug-prone code. Those proofs didn't make the code any more correct[^luu]. So you still have to read all of it, theorems and proofs included. Check that it does what you need and fix it where it doesn't. Don't trust any part you haven't checked yourself.

Tools like [claimcheck](https://github.com/metareflection/claimcheck) can help with that reading. It has an AI model restate each theorem in plain English without knowing what the theorem was meant to say. A second step compares that restatement with the original intent[^claimcheck]. It's a useful check, but it doesn't replace reading.

*Partial answer to Question 2.* So can the app serve real users? Yes, as long as three things hold: (H1) traffic stays modest, (H2) you pin the toolchain, and (H3) someone actually reads the code. The server's limits don't matter while traffic stays modest. You can also run several copies of the app for more load because it keeps no state between requests. A pinned toolchain means a new Lean release can't break anything until you choose to upgrade. Reading the code is doable where it matters most because the app is only about 1,600 lines. Someone should read its handlers, its SQL and its C bindings carefully before real users see them.

## Correctness

I think correctness by construction is what you should aim for, especially when an AI writes most of your code. It means first writing down exactly what the program should do in a formal language. The code is then derived from that description in steps that are each proved correct.

Today most people rely on tests instead, or hand the agent a spec and hope it follows it. Tests only check the cases someone thought to write. Dan Luu's experiments also show that agents write poor tests, even when told which technique to use. A spec on its own can't show that the code actually follows it. Correctness by construction closes that gap, because Lean checks every step from the spec to the code. It's the only reliable way I see to ship high-quality code while keeping the speed AI gives you.

So the last question is whether this app could be correct by construction. Here is the precise definition.

**Definition 2.** A program is *correct by construction* if it is derived from a formal specification by steps, each proved to preserve correctness[^cbc].

**Question 3.** Is there a RealWorld implementation in Lean that is correct by construction?

Definition 2 has two parts, a formal specification and a step-by-step derivation from it. Let's check each one.

*The specification.* Does RealWorld have a formal specification? Partly. Its contract is an OpenAPI file plus the test suites. The OpenAPI file is precise about shapes, like which endpoints exist, what fields they take and which status codes they return. What the endpoints actually do is only described in English. The tests pin that down for the specific cases they check, and nowhere else. So RealWorld is formal about types and informal about behavior.

*The derivation.* Was the app derived from that specification? No. That was a conscious choice. RealWorld is only formal about types, so there's nothing precise enough to derive the app's behavior from. Full correctness by construction wasn't possible with the spec as it stands. So I wrote the app first and tested it afterwards, which is the opposite of what Definition 2 asks for. I picked a few important properties to verify instead. Three of them are guaranteed just because the code compiles. Here they are.

**Proposition 1.** If a handler's types don't match its route, the code doesn't compile.

*Proof.* lean-routing works out each handler's type from its route. The OpenAPI file says a comment's id is an integer. The route table says `Nat` as well. So a handler that takes the id as a `String` won't compile:

```
error: Application type mismatch: The argument
  deleteComment env
has type
  String → String → Api.Handler
but is expected to have type
  HandlerType Api.patterns.comment Result
```

This error appears at compile time, before the app ever runs. ∎

Every handler in Express or Go parses the id itself. A mismatch in Rust's axum only shows up when a request comes in. One weak spot remains here. I copied the route table from the OpenAPI file by hand. Generating it from the file automatically would close that gap.

Slugs show Definition 2 on a small scale. A slug is the URL-friendly version of a title, like `how-to-train-your-dragon`. RealWorld doesn't say what a slug should look like, so I wrote the specification first, as a Lean type called `Valid`. A single lowercase letter or digit is a valid slug. You can grow a valid slug by putting a letter or digit in front of it, or a letter or digit followed by a hyphen. Nothing else is valid. That rules out empty slugs, hyphens at either end and double hyphens. A `Slug` is a string bundled with a proof that it follows these rules:

```lean
inductive Valid : List Char → Prop where
  | single {c} : isSlugChar c → Valid [c]
  | cons {c rest} : isSlugChar c → Valid rest → Valid (c :: rest)
  | hyphen {c rest} : isSlugChar c → Valid rest → Valid (c :: '-' :: rest)

structure Slug where
  toString : String
  valid : Valid toString.toList
```

**Proposition 2.** Every slug the app stores is well formed.

*Proof.* The functions that save slugs only accept a `Slug`, so every saved slug carries its proof. Most of those proofs come from `ofTitle` when it turns a title into a slug. It only compiles because it comes with a proof that its result is valid for every possible title[^sorry]. ∎

Here's `ofTitle`. It calls a helper, `chars`, which keeps the title's letters and digits, lowercases them and turns everything in between into single hyphens. Then `ofTitle` returns that string together with a proof that it's valid. The proof is the part after `by`:

```lean
def ofTitle (title : String) : Slug :=
  match h : chars title.toList false false with
  | [] => ⟨"article", ...⟩   -- a title with no letters or digits
  | c :: cs =>
    ⟨String.ofList (c :: cs), by
      rw [String.toList_ofList, ← h]
      exact (chars_valid title.toList false).resolve_left (by rw [h]; exact List.cons_ne_nil _ _)⟩
```

That proof relies on a lemma about `chars`. It says that for any title, `chars` returns either nothing or a valid slug. The lemma is proved by induction over the title's characters:

```lean
theorem chars_valid (cs : List Char) (pending : Bool) :
    chars cs false pending = [] ∨ Valid (chars cs false pending) := by
  induction cs generalizing pending with
  | nil => exact Or.inl rfl
  | cons c cs ih => ...
```

In total that's about forty lines of proof for ten lines of code. A property-based test would check a few thousand random titles. The proof covers every title including the ones nobody has written yet.

**Proposition 3.** Unless the code calls `Node.unsafeRaw`, anything a user typed is escaped before it appears on a page.

*Proof.* You can't build a page element in lean-html directly. Only lean-html's own functions can. All of them except `Node.unsafeRaw` run their text through `escape`. lean-html also proves that `escape` never leaves a `<`, `>` or `"` in its output:

```lean
def escapeChar (c : Char) : String :=
  match c with
  | '&' => "&amp;"
  | '<' => "&lt;"
  | '>' => "&gt;"
  | '"' => "&quot;"
  | c    => String.singleton c

theorem escape_safe (s : String) :
    ∀ c ∈ (escape s).toList, c ≠ '<' ∧ c ≠ '>' ∧ c ≠ '"' := ...
```

In plain words, the escaped version of any string contains no `<`, `>` or `"`. ∎

RealWorld's website tests do check for cross-site scripting. They inject malicious text through the API and check that the page shows it as plain text. The suite skips those tests for apps that serve both the API and the pages, like this one. So here the proof is the only check. React escapes text the same way, but there only tests check that the escaping is right.

So this app is not correct by construction. Whether any RealWorld app in Lean can be (Question 3) is still open. Answering it would start with writing RealWorld's behavior down in Lean. Deriving the app from that would also need a model of SQL, plus proofs about the C libraries and `Std.Http` underneath. For now, the slug is the only part where the method has been carried all the way through.

Instructions for running the app and both test suites are in the repository.

**Acknowledgments.** Thanks to Paul Butcher, whose libraries made this possible, and to Carlo Hamalainen for datastar-lean.

---

[^suites]: All 154 requests of the API suite pass. The website suite has 139 tests. When one app serves both the API and the site, 65 of them are skipped. The other 74 pass.

[^computation]: The last step of this proof is running the two test suites, which is a computation. Proofs that end in a computer run have a long history, the four colour theorem being the most famous. This one also assumes that Postgres, a web browser and the test runners work correctly, so a strict mathematician might call it an experiment.

[^loc]: Non-blank, non-comment lines, tests excluded, for [nitro-prisma-zod](https://github.com/realworld-apps/nitro-prisma-zod-realworld-example-app), [golang-gin](https://github.com/gothinkster/golang-gin-realworld-example-app) and [aspnetcore](https://github.com/realworld-apps/aspnetcore-realworld-example-app). The Lean count includes the SQL schema and the proofs. The website adds 616 lines. The 7.6 MB binary builds in 18 seconds on an M1, excluding the libraries.

[^prs]: The repository's README lists every library change and its pull request.

[^http]: In Lean 4.34.1, a bare `Std.Http` server answering `ok` handles about 1,800 requests per second at 64 connections. Go handles over 100,000. The app itself handles 1,170 to 1,650, with Postgres using less than half a core. Most of the gap comes from a bug in Lean's async runtime. It was fixed in [lean4#15174](https://github.com/leanprover/lean4/pull/15174) on 22 September 2026, but no release includes the fix yet, 4.35.0 included. With the fix, the bare server reaches 8,640 requests per second. A single event-loop lock, tracked in [lean4#13469](https://github.com/leanprover/lean4/issues/13469), then keeps it about thirteen times behind Go. Measured on an Apple M1 with wrk for ten seconds, taking the median of three runs.

[^stability]: Reservoir is Lean's package index. Between 4.26 and 4.34, 9% of its packages without dependencies broke from one release to the next. For packages with dependencies the figure was 23%. Both figures leave out packages that depend on Mathlib. Release 4.34 alone broke four of the libraries used here, for want of a rename. No Rust release in the year after 1.0 broke more than 1.3% of crates.

[^contributors]: GitHub's contributor lists, October 2026.

[^luu]: Dan Luu, ["How well do agents use test and verification techniques?"](https://danluu.com/agentic-testing/), September 2026. He ran Codex with GPT-5.6 Sol about 80 times for each of 26 instructions, such as "Use Lean 4" or "Use property-based testing". All the implementations were in Rust. Agents told to use the other formal tools mostly proved irrelevant properties too.

[^claimcheck]: claimcheck was built for Dafny, another language for proving programs correct. Its repository also runs the same check on Lean 4 specifications from the VERINA benchmark. Its authors, Fernanda Graciolli and Nada Amin, [describe it](https://midspiral.com/blog/claimcheck-narrowing-the-gap-between-proof-and-intent/) as "a probabilistic sanity check that requires human review and approval".

[^sorry]: Lean compiles a proof left as `sorry` and only warns about it. The app's CI therefore rejects any theorem that depends on one.

[^cbc]: The idea goes back to E. W. Dijkstra, "A constructive approach to the problem of program correctness", BIT 8 (1968). D. G. Kourie and B. W. Watson set it out as a method in *The Correctness-by-Construction Approach to Programming* (Springer, 2012).
