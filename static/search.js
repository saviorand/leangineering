// Search for the static build. Every entry, group and section carries its lowercased search
// text in `data-s`, and Datastar re-evaluates these from `data-show` / `data-text` as `$q` changes.
// The server build doesn't load this: it searches in Lean and streams results over SSE.
(() => {
  const words = q => (q || "").toLowerCase().split(/\s+/).filter(Boolean);
  const matches = (ws, text) => ws.every(w => text.includes(w));

  window.lgMatchAny = (q, texts) => {
    const ws = words(q);
    return ws.length === 0 || texts.split("\n").some(t => matches(ws, t));
  };

  window.lgSummary = q => {
    const ws = words(q);
    if (ws.length === 0) return "";
    const n = [...document.querySelectorAll(".entry[data-s]")]
      .filter(e => matches(ws, e.dataset.s)).length;
    const shown = q.trim();
    return n === 0
      ? `⊢ False  Nothing matches “${shown}”. Maybe nobody has built it yet? Sounds like your next project.`
      : `⊢ ${n} ${n === 1 ? "match" : "matches"} for “${shown}”`;
  };
})();
