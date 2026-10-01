import { defineConfig } from "@playwright/test";

// The same tests run against both ways the site is served: `leangineering serve`, where search
// runs in Lean and streams results over SSE, and the static build that GitHub Pages hosts,
// where Datastar and `static/search.js` filter in the browser.
const server = "http://127.0.0.1:3201";
const staticSite = "http://127.0.0.1:3202";

export default defineConfig({
  testDir: "./tests",
  forbidOnly: !!process.env.CI,
  projects: [
    { name: "server", use: { baseURL: server } },
    { name: "static", use: { baseURL: staticSite } },
  ],
  webServer: [
    {
      command: "PORT=3201 lake exe leangineering serve",
      cwd: "..",
      url: server,
      reuseExistingServer: !process.env.CI,
    },
    {
      command: "lake exe leangineering build e2e/.dist && python3 -m http.server 3202 -b 127.0.0.1 -d e2e/.dist",
      cwd: "..",
      url: staticSite,
      reuseExistingServer: !process.env.CI,
    },
  ],
});
