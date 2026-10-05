import Std.Http
import Routing
import Datastar
import Leangineering.Awesome
import Leangineering.Views

namespace Leangineering

open Std Http Async Server
open Routing Datastar

-- `search` sits outside `/awesome/`, so no category's slug can collide with it.
route_table Site
  [ home := "/",
    awesome := "/awesome",
    search := "/search",
    category := "/awesome/:slug:String",
    css := "/static/site.css" ]

structure SearchSignals where
  q : String
  deriving Lean.FromJson

/-- Datastar search: reads the `q` signal and patches `#results` with the matching entries. -/
def searchHandler (site : Awesome) (req : Request Body.Stream) : ContextAsync (Response Body.Any) := do
  match ← readSignals (α := SearchSignals) req with
  | .error e => return ← Response.badRequest |>.text e
  | .ok { q } =>
    sseResponse fun sse => sse.send <| patchElements (Views.results site q).render

def app (site : Awesome) (css : String) (mode : Views.Mode) : StatelessHandler :=
  let notFound : Result := fun _ => Response.notFound.html (Views.notFoundPage mode)
  [ .get Site.patterns.home (fun _ => Response.ok.html (Views.homePage site mode)),
    .get Site.patterns.awesome (fun _ => Response.ok.html (Views.awesomePage site mode)),
    .get Site.patterns.search (searchHandler site),
    .get Site.patterns.category (fun slug req =>
      match site.find? slug with
      | some c => Response.ok.html (Views.categoryPage site c mode)
      | none => notFound req),
    .get Site.patterns.css (fun _ =>
      Response.ok |>.header! "Content-Type" "text/css; charset=utf-8" |>.fromBytes css.toUTF8) ]
  |> toHandler (notFound := notFound)

end Leangineering
