# leangineering

[Join the Leangineer Discord](https://discord.gg/ACKNs7ZJPj) to talk about building software in Lean.

Source for [leangineer.com](https://leangineer.com), a community and learning resource for software engineers using Lean 4. The site is written in Lean.

## What's here

- `/awesome`: the [awesome-lean-programming](https://github.com/saviorand/awesome-lean-programming) list as a browsable directory, with a page per category and live search.
- `/blog`: posts written as maths papers.
- `/community`: posts about Lean shared in the `#blog-posts` forum on the [Discord](https://discord.gg/ACKNs7ZJPj).
- Guides are coming next.

The directory is generated from the awesome-lean-programming readme, which stays the single source of truth. To change an entry, open a pull request there.

The community page lists every post in the Discord's `#blog-posts` forum that links somewhere, using Discord's preview of the link for the title and description. An author keeps a post off the page by giving it the forum's `Unlisted` tag.

## Stack

- [lean-html](https://github.com/paulbutcher/lean-html): pages are typed HTML values, so invalid nesting is a compile error and all text is escaped.
- [lean-routing](https://github.com/paulbutcher/lean-routing): typed routes and links.
- [lean-markdown](https://github.com/paulbutcher/lean-markdown): parses the readme; entry descriptions render to typed HTML nodes, with no raw HTML.
- [datastar-lean](https://github.com/starfederation/datastar-lean): search streams results to the page over server-sent events.
- `Std.Http`: the HTTP server that ships with Lean.

## Running

Requires [elan](https://github.com/leanprover/elan). The toolchain is pinned in `lean-toolchain`.

```sh
lake build
.lake/build/bin/leangineering              # serve on http://127.0.0.1:8080
PORT=3000 HOST=0.0.0.0 .lake/build/bin/leangineering
.lake/build/bin/leangineering build dist   # static site in dist/, searched in the browser
BASE_PATH=/leangineering/ .lake/build/bin/leangineering build dist   # hosted under a subpath
```

With a server, search runs in Lean and streams results over SSE. The static build filters in the browser instead, with Datastar and `static/search.js`.

Both modes read `data/awesome-lean.md`, `static/site.css` and `brand/logo.svg` from the working directory, and the community's posts from `data/community.json`. To pull the latest list and posts:

```sh
scripts/sync-awesome.sh
DISCORD_BOT_TOKEN=... .lake/build/bin/leangineering sync-community
```

`sync-community` reads the forum as the Leangineer bot, which needs View Channels and Read Message History on the forum, and the Message Content intent. The deploy runs both syncs daily, with the token from the `DISCORD_BOT_TOKEN` secret. Without a token, or if Discord fails, the committed snapshot is used.


## End-to-end tests

Playwright drives Chromium against both the server (`leangineering serve`, port 3201) and the
static build (served on port 3202), running the same tests in each. It starts both itself:

```sh
cd e2e
npm ci
npx playwright install chromium
npx playwright test
```

## Deploying

`.github/workflows/pages.yml` builds the static site and deploys it to GitHub Pages on every push, daily, and when awesome-lean-programming sends a `repository_dispatch` of type `awesome-lean-updated`. It pulls the latest list before building.

## Layout

- `Leangineering/Awesome.lean`: parses the readme into categories, groups and entries, plus search.
- `Leangineering/Views.lean`: page templates.
- `Leangineering/Server.lean`: route table and handlers, including the Datastar search endpoint.
- `Main.lean`: the `serve` and `build` commands.
- `brand/`: the logo. `logo.svg` is the source, read at startup and inlined as the favicon; `export/` has PNGs from 16 to 2048px, and `discord-icon.png` is the 512px Discord upload.
