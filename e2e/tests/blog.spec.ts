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

test("the home page links to the blog, which lists its posts", async ({ page }) => {
  await page.goto("./");
  await page.getByRole("link", { name: "Blog" }).first().click();
  await expect(page).toHaveURL(/\/blog\/?$/);
  await expect(page.locator(".post-item").first()).toBeVisible();
});

test("a post renders as a paper", async ({ page }) => {
  await page.goto("blog/");
  await page.locator(".post-title").first().click();
  await expect(page).toHaveURL(/\/blog\/[^/]+\/?$/);

  await expect(page.locator(".abstract")).toBeVisible();
  await expect(page.locator("h2 .sec-num").first()).toHaveText("1");
  await expect(page.locator(".theorem .thm-label").first()).toBeVisible();
  // Every proof ends in a ∎, inline or on a line of its own.
  for (const proof of await page.locator(".proof").all()) {
    await expect(proof).toContainText("∎");
  }

  const figure = page.locator("figure").first();
  await expect(figure.locator(".fig-label")).toHaveText("Figure 1.");
  await figure.scrollIntoViewIfNeeded();
  await expect.poll(() => figure.locator("img").evaluate((img: HTMLImageElement) => img.naturalWidth)).toBeGreaterThan(0);

  // A note number jumps to its note, and the note links back.
  const ref = page.locator(".fn-ref a").first();
  const target = (await ref.getAttribute("href"))!.split("#")[1];
  await ref.click();
  await expect(page).toHaveURL(new RegExp(`#${target}$`));
  await expect(page.locator(`#${target}`)).toBeInViewport();
});

test("an unknown post is not found", async ({ page, consoleErrors }) => {
  const response = await page.goto("blog/no-such-post");
  expect(response?.status()).toBe(404);
  // The browser logs the 404 itself, which is the point here.
  consoleErrors.length = 0;
});
