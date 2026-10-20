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

// These read the forum's snapshot committed in `data/community.json`.

test("the community page lists posts shared on the Discord, linking to where they were published", async ({ page }) => {
  await page.goto("./");
  await page.getByRole("link", { name: "Community" }).first().click();
  await expect(page).toHaveURL(/\/community\/?$/);

  await expect(page.locator(".post-item").first()).toBeVisible();
  for (const title of await page.locator(".post-title").all()) {
    expect(await title.getAttribute("href")).toMatch(/^https?:\/\//);
  }
  // Who shared it, and when.
  await expect(page.locator(".post-meta").first()).toHaveText(/^.+ · [A-Z][a-z]+ \d{1,2}, \d{4}$/);
});
