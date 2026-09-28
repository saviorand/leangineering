# leangineering

Source for [leangineer.com](https://leangineer.com), a community and learning resource for software engineers using Lean 4. The site is written in Lean.

## What's here

- `/awesome`: the [awesome-lean](https://github.com/saviorand/awesome-lean) list as a browsable directory, with a page per category and live search.
- Guides are coming next.

The directory is generated from the awesome-lean readme, which stays the single source of truth. To change an entry, open a pull request there.

## Stack

- [lean-html](https://github.com/paulbutcher/lean-html): pages are typed HTML values, so invalid nesting is a compile error and all text is escaped.
- [lean-routing](https://github.com/paulbutcher/lean-routing): typed routes and links.
- [lean-markdown](https://github.com/paulbutcher/lean-markdown): parses the readme; entry descriptions render to typed HTML nodes, with no raw HTML.
- [datastar-lean](https://github.com/saviorand/datastar-lean): search streams results to the page over server-sent events.
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

Both modes read `data/awesome-lean.md` and `static/site.css` from the working directory. To pull the latest list:

```sh
scripts/sync-awesome.sh
```

## Deploying

`.github/workflows/pages.yml` builds the static site and deploys it to GitHub Pages on every push, daily, and when awesome-lean sends a `repository_dispatch` of type `awesome-lean-updated`. It pulls the latest list before building.

## Layout

- `Leangineering/Awesome.lean`: parses the readme into categories, groups and entries, plus search.
- `Leangineering/Views.lean`: page templates.
- `Leangineering/Server.lean`: route table and handlers, including the Datastar search endpoint.
- `Main.lean`: the `serve` and `build` commands.
