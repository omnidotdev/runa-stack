# runa e2e

End-to-end smoke test for a self-hosted runa instance.

`auth-smoke.mjs` drives a real browser through the full auth flow (sign-up, email
verification, sign-in) and asserts it lands on the authenticated app, so a self-host
deployment can be validated in one command instead of clicking through by hand.

## Prerequisites

- A running runa stack, e.g. `run up runa` or `docker compose up` from the repo root
- Docker (the email-verify step flips the DB flag, since local self-host has no SMTP)

## Run

```bash
bun install
bunx playwright install chromium
bun run smoke          # headless, exits non-zero on failure
HEADED=1 bun run smoke # watch it run
```

## Config

Environment variables (all optional):

- `APP_URL` the app base URL (default `https://localhost`)
- `AUTH_DB_CONTAINER` the auth database container (default `runa-auth-db-1`)
- `AUTH_DB_NAME` the auth database name (default `auth`)

Each run creates a fresh unique user, so the test is safe to run repeatedly. On
failure it writes `auth-smoke-failure.png`.
