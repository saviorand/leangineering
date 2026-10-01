import { test as base, expect, type Page } from "@playwright/test";

// Every test fails if its page logs an error, such as Datastar failing to load or evaluate.
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

const entries = (page: Page) => page.locator("#results li.entry:visible");
const summary = (page: Page) => page.locator(".result-summary");
const search = (page: Page) => page.getByRole("searchbox", { name: "Search the directory" });

test("the home page links to the directory", async ({ page }) => {
  await page.goto("./");
  await page.getByRole("link", { name: "Directory" }).first().click();
  await expect(page).toHaveURL(/\/awesome\/?$/);
  await expect(entries(page).first()).toBeVisible();
});

test("search narrows the directory and counts the matches", async ({ page }) => {
  await page.goto("awesome/");
  const all = await entries(page).count();
  expect(all).toBeGreaterThan(100);
  await expect(summary(page)).toBeHidden();

  await search(page).fill("sqlite");
  await expect(summary(page)).toHaveText(/⊢ \d+ match(es)? for “sqlite”/);
  const n = Number((await summary(page).innerText()).match(/\d+/)![0]);
  await expect(entries(page)).toHaveCount(n);
  await expect(page.getByRole("link", { name: "leansqlite" })).toBeVisible();

  await search(page).fill("");
  await expect(summary(page)).toBeHidden();
  await expect(entries(page)).toHaveCount(all);
});

test("search with no matches says so", async ({ page }) => {
  await page.goto("awesome/");
  await search(page).fill("zzqqxx");
  await expect(summary(page)).toContainText("Nothing matches “zzqqxx”");
  await expect(entries(page)).toHaveCount(0);
});

test("every search word has to match", async ({ page }) => {
  await page.goto("awesome/");
  await search(page).fill("sqlite bindings");
  await expect(summary(page)).toHaveText(/for “sqlite bindings”/);
  for (const text of await entries(page).allInnerTexts()) {
    expect(text.toLowerCase()).toContain("sqlite");
  }
});

test("a category page lists its entries", async ({ page }) => {
  await page.goto("awesome/");
  const first = page.locator("#results section h2 a").first();
  const name = (await first.innerText()).trim();
  await first.click();
  await expect(page.getByRole("heading", { level: 1 })).toContainText(name);
  await expect(page.locator("li.entry").first()).toBeVisible();
});
