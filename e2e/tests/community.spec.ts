import { test as base, expect } from "@playwright/test";

// Every test fails if its page logs an error.
const test = base.extend<{ consoleErrors: string[] }>({
  consoleErrors: [
    async ({ page }, use) => {
      const errors: string[] = [];
      page.on("console", (m) => m.type() === "error" && errors.push(m.text()));
      page.on("pageerror", (e) => errors.push(String(e)));
      await use(errors);
      expect(errors).toEqual([]);
    },
    { auto: true },
  ],
});

// These read the forums' snapshot committed in `data/community.json`.

test("the writing page mixes the site's posts with posts shared on the Discord", async ({ page }) => {
  await page.goto("blog/");
  await expect(page.locator(".post-item:not(.shared)").first()).toBeVisible();

  const shared = page.locator(".post-item.shared");
  await expect(shared.first()).toBeVisible();
  for (const title of await shared.locator(".post-title").all()) {
    expect(await title.getAttribute("href")).toMatch(/^https?:\/\//);
  }
  // Who shared it, on which site, and when.
  await expect(shared.locator(".post-meta").first()).toHaveText(/^.+ · [a-z0-9.-]+ · [A-Z][a-z]+ \d{1,2}, \d{4}$/);
});

test("the directory starts with at most five recent projects from the Discord", async ({ page }) => {
  await page.goto("awesome/");
  const projects = page.locator(".recent-projects li.entry");
  await expect(projects.first()).toBeVisible();
  expect(await projects.count()).toBeLessThanOrEqual(5);
  for (const name of await projects.locator(".entry-name").all()) {
    expect(await name.getAttribute("href")).toMatch(/^https?:\/\//);
  }
});
