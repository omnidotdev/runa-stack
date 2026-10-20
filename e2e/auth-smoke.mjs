#!/usr/bin/env node
// End-to-end auth smoke test for a locally self-hosted runa (run up runa, or docker compose up).
// Drives a real browser through sign-up -> email-verify -> sign-in -> authenticated app,
// handling two self-host quirks:
//   - the consent checkbox lives in a label that also wraps the Terms/Privacy links, so a
//     role-based click can land on a link; toggle the hidden input directly instead
//   - there is no SMTP locally, so email verification is completed by flipping the DB flag
//
// Usage:
//   bun install                 # installs playwright (devDependency)
//   bunx playwright install chromium   # one time, if chromium is missing
//   bun run smoke               # headless, exits non-zero on failure
//   HEADED=1 bun run smoke      # watch it run
//
// Config via env: APP_URL (default https://localhost), AUTH_DB_CONTAINER (default runa-auth-db-1),
// AUTH_DB_NAME (default auth). Requires docker for the DB verify step.

import { execFileSync } from "node:child_process";
import { chromium } from "playwright";

const APP_URL = process.env.APP_URL || "https://localhost";
const AUTH_DB_CONTAINER = process.env.AUTH_DB_CONTAINER || "runa-auth-db-1";
const AUTH_DB_NAME = process.env.AUTH_DB_NAME || "auth";
const HEADED = process.env.HEADED === "1";

// Unique identity per run so the script is idempotent across repeated runs.
// Username policy allows lowercase letters, numbers, and hyphens only.
const stamp = Date.now().toString(36);
const user = {
  firstName: "Smoke",
  lastName: "Test",
  username: `smoke-${stamp}`,
  email: `smoke-${stamp}@example.com`,
  password: "RunaSmoke1234!",
};

function log(step, msg) {
  console.log(`[${step}] ${msg}`);
}

function verifyEmailInDb(email) {
  // No SMTP locally; mark the account verified directly (documented self-host fallback)
  const out = execFileSync(
    "docker",
    [
      "exec",
      AUTH_DB_CONTAINER,
      "psql",
      "-U",
      "postgres",
      "-d",
      AUTH_DB_NAME,
      "-tAc",
      `UPDATE "user" SET email_verified = true WHERE email = '${email}' RETURNING id;`,
    ],
    { encoding: "utf8" },
  );
  const id = out.trim().split("\n")[0];
  if (!id) throw new Error(`no user row created for ${email}`);
  return id;
}

async function main() {
  const browser = await chromium.launch({ headless: !HEADED });
  // Accept the mkcert self-signed cert used for local HTTPS
  const context = await browser.newContext({ ignoreHTTPSErrors: true });
  const page = await context.newPage();
  const errors = [];
  page.on("console", (m) => m.type() === "error" && errors.push(m.text()));

  try {
    // 1. Landing -> sign-up
    log("1/6", `open ${APP_URL}`);
    await page.goto(APP_URL, { waitUntil: "networkidle" });
    await page.getByRole("button", { name: "Get Started Free" }).first().click();
    await page.waitForURL(/\/sign-in/);
    await page.getByRole("tab", { name: "Sign Up" }).click();

    // 2. Fill the sign-up form
    log("2/6", `sign up as ${user.email}`);
    await page.getByRole("textbox", { name: "First Name" }).fill(user.firstName);
    await page.getByRole("textbox", { name: "Last Name" }).fill(user.lastName);
    await page.getByRole("textbox", { name: "Username" }).fill(user.username);
    await page.getByRole("textbox", { name: "Email" }).fill(user.email);
    await page.getByRole("textbox", { name: "Password", exact: true }).fill(user.password);
    await page.getByRole("textbox", { name: "Confirm Password" }).fill(user.password);
    // The consent label wraps the policy links, so toggle the hidden input directly
    await page.evaluate(() => {
      const i = document.getElementById("checkbox:legalConsent:input");
      if (i && !i.checked) i.click();
    });
    await page.getByRole("button", { name: "Create an Account" }).click();
    await page.waitForURL(/verify-email/);

    // 3. Verify email (no SMTP locally)
    log("3/6", "verify email via DB");
    const id = verifyEmailInDb(user.email);
    log("3/6", `verified user ${id}`);

    // 4. Sign in: email step
    log("4/6", "sign in");
    await page.goto(APP_URL, { waitUntil: "networkidle" });
    await page.getByRole("button", { name: "Get Started Free" }).first().click();
    await page.waitForURL(/\/sign-in/);
    await page.getByRole("textbox", { name: "Email or Username" }).fill(user.email);
    await page.getByRole("button", { name: "Continue" }).click();

    // 5. Password step
    await page.getByRole("textbox", { name: "Password" }).fill(user.password);
    await page.getByRole("button", { name: "Sign In", exact: true }).click();

    // 6. Assert we landed in the authenticated app
    log("5/6", "await authenticated app");
    await page.waitForURL(/\/workspaces/, { timeout: 15000 });
    const title = await page.title();
    if (!/Runa/.test(title)) throw new Error(`unexpected title after sign-in: ${title}`);

    log("6/6", `PASS - authenticated at ${page.url()} (title: ${title})`);
    if (errors.length) log("warn", `console errors seen: ${errors.length}`);
    await browser.close();
    process.exit(0);
  } catch (err) {
    console.error(`FAIL: ${err.message}`);
    try {
      await page.screenshot({ path: "auth-smoke-failure.png" });
      console.error("saved auth-smoke-failure.png");
    } catch {}
    await browser.close();
    process.exit(1);
  }
}

main();
