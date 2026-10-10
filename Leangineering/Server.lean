import Std.Http
import Routing
import Datastar
import Leangineering.Awesome
import Leangineering.Blog
import Leangineering.Views

namespace Leangineering

open Std Http Async Server
open Routing Datastar

-- `search` sits outside `/awesome/`, so no category's slug can collide with it.
route_table Site
  [ home := "/",
    blog := "/blog",
    post := "/blog/:slug:String",
    awesome := "/awesome",
    search := "/search",
    category := "/awesome/:slug:String",
    css := "/static/site.css",
    asset := "/static/blog/:file:String" ]

/-- The media type of a post's image, by its extension. -/
def contentType (file : String) : String :=
  if file.endsWith ".png" then "image/png"
  else if file.endsWith ".jpg" || file.endsWith ".jpeg" then "image/jpeg"
  else if file.endsWith ".webp" then "image/webp"
  else if file.endsWith ".svg" then "image/svg+xml"
  else "application/octet-stream"

structure SearchSignals where
  q : String
  deriving Lean.FromJson

/-- Datastar search: reads the `q` signal and patches `#results` with the matching entries. -/
def searchHandler (site : Awesome) (req : Request Body.Stream) : ContextAsync (Response Body.Any) := do
  match ← readSignals (α := SearchSignals) req with
  | .error e => return ← Response.badRequest |>.text e
  | .ok { q } =>
    sseResponse fun sse => sse.send <| patchElements (Views.results site q).render

/-- `assets` are the files in `static/blog/`, read at startup, so a request can only ever name one
of them. -/
def app (site : Awesome) (posts : Array Post) (assets : Array (String × ByteArray)) (css : String)
    (mode : Views.Mode) : StatelessHandler :=
  let notFound : Result := fun _ => Response.notFound.html (Views.notFoundPage mode)
  [ .get Site.patterns.home (fun _ => Response.ok.html (Views.homePage site mode)),
    .get Site.patterns.blog (fun _ => Response.ok.html (Views.blogPage posts mode)),
    .get Site.patterns.post (fun slug req =>
      match posts.find? (·.slug == slug) with
      | some post => Response.ok.html (Views.postPage post mode)
      | none => notFound req),
    .get Site.patterns.awesome (fun _ => Response.ok.html (Views.awesomePage site mode)),
    .get Site.patterns.search (searchHandler site),
    .get Site.patterns.category (fun slug req =>
      match site.find? slug with
      | some c => Response.ok.html (Views.categoryPage site c mode)
      | none => notFound req),
    .get Site.patterns.css (fun _ =>
      Response.ok |>.header! "Content-Type" "text/css; charset=utf-8" |>.fromBytes css.toUTF8),
    .get Site.patterns.asset (fun file req =>
      match assets.find? (·.1 == file) with
      | some (_, bytes) => Response.ok |>.header! "Content-Type" (contentType file) |>.fromBytes bytes
      | none => notFound req) ]
  |> toHandler (notFound := notFound)

end Leangineering
