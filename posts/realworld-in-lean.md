---
title: An ordinary web application in Lean, by construction
excerpt: "A theorem and its proof by construction: RealWorld, a Medium clone with official test suites, written in Lean by Claude Code at my direction. It passes the suites, three common mistakes in it don't compile, and three open problems stand between it and production."
date: 2026-10-08
draft: true
---

**Abstract.** Lean 4 is best known as a theorem prover, but it also compiles ordinary programs. This note exhibits an ordinary web application written in it: [RealWorld](https://github.com/realworld-apps/realworld), a Medium clone with official test suites, built by Claude Code, an AI coding agent, at my direction. The application passes both suites, its backend is shorter than the TypeScript, Go and C# backends it was compared with, and three common mistakes in it do not compile. What keeps it out of production is the ecosystem around the language: an HTTP server that tops out at about 3,000 requests per second, monthly releases that break libraries, and libraries with one maintainer each.

![The home page, rendered on the server by Lean.](static/blog/realworld-home.png)

## Introduction

Using a theorem prover to build a Medium clone needs a word of explanation. The question was whether Lean can carry an ordinary web application, and a question of that kind is better settled by construction than by argument. RealWorld is a convenient specimen. It has users, articles, comments, tags and follows, which is most of what a web application ordinarily has; it has been built in over a hundred stacks, so comparisons are easy to come by; and it comes with official test suites, so whether an implementation works is not a matter of opinion. That suggests a definition.

**Definition.** A *RealWorld implementation* is a program that passes RealWorld's API suite and its website suite[^suites].

**Theorem.** There is a RealWorld implementation in Lean.

The proof is by construction, the way existence theorems often are proved: build the thing, then check it. The program has three parts, a server, a database and a website, and each is a lemma in the engineering sense, which is to say that it is proved by being built and then leaned on. Building it in a theorem prover rather than in Go raises a second question, whether Lean's types buy anything in a program like this one, and each lemma ends with an answer. (The short answer is yes, and in one place the answer is a proof about every article title anyone will ever write.)

## The construction

**Lemma 1 (The server).** Lean can answer the specification's HTTP requests, and a handler whose types disagree with its route does not compile.

*Proof.* Lean's standard library has had an HTTP server, `Std.Http`, since April. On top of it, the application declares its routes in a table from [lean-routing](https://github.com/paulbutcher/lean-routing), which derives from each route the type its handler must have:

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

The `←` runs an action and takes its result, much like `await`. The `comment` route captures a `String` and a `Nat`, so its handler must take a `String` and a `Nat`. A `deleteComment` that took the id as a `String`, intending to parse it itself, is turned away:

```
error: Application type mismatch: The argument
  deleteComment env
has type
  String → String → Api.Handler
but is expected to have type
  HandlerType Api.patterns.comment Result
```

In Express or Go, the id arrives as a string and every handler parses it, most of them correctly. In Rust's axum, a route and a handler that disagree fail when a request arrives, not when the program builds. Here a request whose id isn't a number never reaches the handler. The rest of the server is what any web stack provides: [lean-json](https://github.com/paulbutcher/lean-json) parses request bodies, [lean-libcrypto](https://github.com/paulbutcher/lean-libcrypto) hashes passwords with OpenSSL's scrypt, and [lean-jose](https://github.com/paulbutcher/lean-jose) signs the JSON Web Tokens that keep users signed in. ∎

**Lemma 2 (The database).** Lean can keep the application's data in Postgres, and every slug it stores is well formed.

*Proof.* [leanpostgres](https://github.com/paulbutcher/leanpostgres) wraps Postgres's C client, and a query is a string with values in braces:

```lean
def userByEmail (db : Conn) (email : String) : IO (Option UserRow) := do
  first (← db sql!"SELECT id, username, email, password_hash, bio, image FROM users
                     WHERE email = {email}")
```

`sql!` looks like string interpolation, but it sends `{email}` to Postgres as a query parameter, so a value never becomes SQL.

Articles are stored and addressed by a slug made from the title, so "How to train your dragon!" lives at `/article/how-to-train-your-dragon`. Here Lean does something the other stacks cannot, because the application's slug type carries a proof:

```lean
inductive Valid : List Char → Prop where
  | single {c} : isSlugChar c → Valid [c]
  | cons {c rest} : isSlugChar c → Valid rest → Valid (c :: rest)
  | hyphen {c rest} : isSlugChar c → Valid rest → Valid (c :: '-' :: rest)

structure Slug where
  toString : String
  valid : Valid toString.toList

def ofTitle (title : String) : Slug := ...
```

`Valid` says that a slug is runs of `a-z` and `0-9` joined by single hyphens, so it is never empty and has no hyphen at either end or two in a row. A `Slug` is a string together with a proof that the string is valid, and Lean will not make one without the proof. The type of `ofTitle`, `String → Slug`, therefore promises that every title gets a valid slug, and the program does not compile unless the body of `ofTitle` keeps the promise. The functions that write to the database take a `Slug`, not a `String`, so nothing unproved reaches them.

Is the proof long? (About 40 lines, for a function of 10.) Is it worth it? (A property-based test would take a few lines and try a few thousand titles; the proof covers every title there is. The reader may do the arithmetic.) ∎

**Lemma 3 (The website).** Lean can render the website and make it interactive, and a page cannot include what a user typed without escaping it.

*Proof.* Pages are rendered on the server from [lean-html](https://github.com/paulbutcher/lean-html) nodes rather than templates. Here is the function that renders a comment, with its text and, for the comment's author, an icon that deletes it:

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

Each element takes its children in brackets and its attributes in braces, and the icon takes one more list, for the Datastar attribute that makes it clickable. `c.body` is whatever the commenter typed, which is to say anything at all. lean-html's node constructor is private, so only its own functions can build a node, and each of them escapes the strings it is given unless the code calls `Node.unsafeRaw`. A comment containing `<script>` renders as text. React does the same, outside `dangerouslySetInnerHTML`; lean-html goes further and proves that its escaping leaves no `<`, `>` or `"` behind.

The icon's `onClick` is all the frontend code there is for deleting a comment. [Datastar](https://data-star.dev), a script the page loads, sends the `DELETE` and applies the server's answer, which removes the comment from the page. The server handles it by calling the same function as the JSON API, so the site and the API share every rule, and there is no frontend build step to speak of, or indeed at all. ∎

![An article page. The body is Markdown rendered by lean-markdown, and the follow and favorite buttons update in place through Datastar.](static/blog/realworld-article.png)

*Proof of the theorem.* Lemmas 1 to 3 construct the program, and both suites, run against it, pass, so it is a RealWorld implementation. ∎

The proofs prove a little more than the theorem asks. The last clause of each lemma holds by construction in the programmer's sense, which is the title's second meaning: a version of the program that mistypes a route, forgets to escape a comment or makes a malformed slug does not compile[^sorry].

## Remarks

**Remark 1 (On cost).** The backend is 1,033 lines of Lean and SQL, proofs included. That is fewer than the TypeScript (1,267), Go (1,371) and C# (2,396) backends I compared it with[^loc], none of which, to be fair, had any proofs to count. The website adds 616 lines. The binary is 7.6 MB, and on an M1 the application builds in 18 seconds once its libraries are built.

**Remark 2 (On the libraries).** The application stands on eleven libraries: ten by Paul Butcher, covering routing, middleware, Postgres, JSON, HTML, Markdown and cryptography, and Carlo Hamalainen's datastar-lean. They are careful libraries, several with proofs of their own, and along the way Claude Code and I contributed improvements to six of them, such as CORS support in lean-middleware[^prs].

## Open problems

The theorem says that the application can be built. The stronger statement, that it is fit for production, is at present false, and three problems stand in the way.

**Problem 1 (Throughput).** With 64 connections, the application serves 1,170 to 1,650 requests per second, depending on the page, while Postgres uses less than half a core. The bottleneck is `Std.Http`. The throughput of a bare `Std.Http` server that only answers `ok` does not, alas, increase with the number of connections. It serves fewer requests at 64 than at one, while Go's serves four times more[^bench]:

| Server, answering `ok` | 1 connection | 64 connections |
|---|---|---|
| `Std.Http`, Lean 4.34.1 | 3,020 req/s, median 283 µs | 1,800 req/s, median 35 ms |
| `net/http`, Go 1.25 | 34,600 req/s, median 26 µs | 143,000 req/s, median 227 µs |

A small site would never notice. A busy one would notice the last column, in which a server that does nothing takes a median 35 ms to say `ok`.

**Problem 2 (Stability).** Lean releases monthly, and compatibility between releases is not an invariant it promises to preserve. Lean 4.34 deprecated six lemmas, and lean-json, which treats warnings as errors, stopped building, taking three other libraries with it. The fix is a rename. Such breakage is common. Across Reservoir, Lean's package index, 9% of the packages without dependencies that built on one release from 4.26 to 4.33 failed on the next, and so did 23% of the packages with dependencies[^stability]. No Rust release in the year after 1.0 broke more than 1.3% of crates.

**Problem 3 (Maintainers).** Paul Butcher's ten libraries were all created between July and September of this year, and nine of them have no contributor besides him and me[^contributors], so each depends on one maintainer.

None of this stops a small site from running on Lean today. It does rule out anything that needs to scale, or to keep building across Lean releases without someone tending it. Solving the three problems would take an HTTP server that scales with connections, a compatibility policy for Lean's releases, and more than one person behind the libraries, and I leave them as exercises for the reader. Readers who take one up, or who are building anything else in Lean, will find company on the [Leangineer Discord](https://discord.gg/ACKNs7ZJPj). The code is [on GitHub](https://github.com/saviorand/lean-realworld-example-app), with instructions for running the app and both suites.

**Acknowledgments.** It is a pleasure to thank Paul Butcher, whose libraries this application stands on, and Carlo Hamalainen, for datastar-lean.

The voice of this note is borrowed from Paul Halmos. His essay [*How to Write Mathematics*](https://faculty.washington.edu/heagerty/Courses/b572/public/HalmosHowToWrite.pdf) (L'Enseignement Mathématique 16, 1970) suggests choosing a writer whose style can teach you and adapting it to your own subject. This note took the advice. Halmos also brought into mathematics the ∎ that ends its proofs.

---

[^suites]: The API suite is 154 requests, and the implementation passes all of them. The website suite has 139 tests, of which 65 skip themselves for an application that serves both ends, because they intercept the browser's requests to `/api`, read the session token from `localStorage`, or plant their data through a separate API. The implementation passes the other 74.

[^sorry]: Lean accepts a placeholder proof, `sorry`, with a warning, and the application's CI fails if any theorem depends on one.

[^loc]: Lines that are neither blank nor comments, excluding tests: [nitro-prisma-zod](https://github.com/realworld-apps/nitro-prisma-zod-realworld-example-app), [golang-gin](https://github.com/gothinkster/golang-gin-realworld-example-app) and [aspnetcore](https://github.com/realworld-apps/aspnetcore-realworld-example-app). The Lean figure includes the SQL schema.

[^prs]: The repository's README lists every library change and its pull request.

[^bench]: Apple M1 with 8 GB of memory, wrk with up to four threads for ten seconds, three runs per row against a freshly started server, and the median of the three. Lean 4.34.1 and Go 1.25.3.

[^stability]: Reservoir rebuilds each package against new releases. The figures pool the eight release pairs from 4.26 to 4.27 through 4.33 to 4.34, 29 of 331 packages without dependencies and 39 of 169 with them, and leave out packages that depend on Mathlib. Rust's figure comes from the crater reports of its first year and is an upper bound.

[^contributors]: GitHub's contributor lists, as of October 2026. lean-markdown has one more contributor.
