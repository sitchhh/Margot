# First-time setup with Maggie

Read `AGENTS.md`. The company is Pink Fitness Club; the operator is Maggie.
Do not assume “Magnolia” is her company or signature.

## 1. Prepare the repo

Maggie needs GitHub access to this private repository. Clone
`https://github.com/sitchhh/Margot`, open that local folder in Codex, and trust it
after reviewing its instructions. Start a fresh chat if repo skills do not appear;
`AGENTS.md` also routes to their files directly.

Run `python3 scripts/margot.py init`. It creates `config/local.json` without
overwriting an existing file. Fill in Maggie's sender address, signature, IANA
timezone, company summary, fundraising context, and call to action. Use her facts
and words. Review the three templates and set `templates_approved` to true once
she accepts the copy. Review the five/seven-day defaults in `config/outreach.json`.
Days are elapsed 24-hour periods, including weekends, after the previous send.

Run `python3 scripts/margot.py doctor`. This checks local files only. Python is
required for helpers, not for reading the instructions or connecting plugins.

## 2. Connect and check Gmail in Maggie's Codex session

Find Gmail in the app's Plugins directory and connect Maggie's Google account
through its sign-in flow. Labels/actions vary by account and client; inspect the
actual tools. ChatGPT chat access does not prove Codex access, and a Free plan
must not be assumed to include every required action.

Record completed checks and dates in ignored `.local/connection-check.md`:

| Check | Passing evidence |
| --- | --- |
| Identity | Mailbox matches sender_email; if no profile action, Maggie confirms the account and a sent message verifies its sender |
| Search/read | Retrieve a thread Maggie identifies, including all pages and full messages |
| Draft | If available, create/retrieve a harmless draft to Maggie herself |
| Send | If available, send a self-test only when Maggie requests it; retrieve sent message/thread IDs, body, timestamp |
| Reply | Verify the actual reply action/parameters preserve an existing thread and reply target |

Only claim completed checks. Self-tests do not authorize investor outreach; keep
them out of the CRM. If an action is unavailable, name it. Read/draft-only access
supports preparation but is not send-ready. Manual sending requires Maggie's
participation and subsequent Gmail evidence reconciliation. Do not build custom
OAuth or silently switch accounts.

## 3. Select and connect Supabase

Maggie selects a dedicated existing project, or creates one herself. Copy its
project reference from the dashboard URL to `config/local.json`. Do not create,
link, or modify another project discovered in the account.

Use the Supabase plugin's authentication flow. If direct MCP configuration is
needed, use the official endpoint with the selected reference:

```text
https://mcp.supabase.com/mcp?project_ref=YOUR_PROJECT_REF&features=database,docs
```

Replace the reference before configuring it through the client's MCP settings.
This repo has no active account-wide MCP configuration. Browser authentication
needs no custom OAuth application or service-role key in this repo.

Scope the connection to the project where supported. For tools exposing multiple
projects, pass the exact configured reference every time. Initial inspection can
be read-only; setup and CRM writes need a writable connection. A read-only error
is not a reason to expose tables to the Data API.

Verify the project via tool metadata/URL, then query:

```sql
select current_user, current_database(), version();
select to_regnamespace('margot') as margot_schema;
```

The schema expects PostgreSQL 17+ and management access as `postgres` (owner) or
an equivalent verified role. Client anon/authenticated/service_role access is
deliberately denied. Inspect unexpected role permissions before proposing specific
grants; do not add broad client access.

## 4. Apply the repository migration

When Maggie requests setup on the selected project, inspect existing tables and
migration history first. If `margot` exists, compare it with recorded migrations;
do not drop it or replay the initial migration.

Use the plugin's migration action (`apply_migration` when available) on the selected
project with each file in `supabase/migrations/`, in filename order, using the file's
descriptive name. This records live migration history. If a call times out, inspect
history/schema before retrying. Never use database reset on the live project.

The initial migration creates only the `margot` schema and lookup values, no contact
seed data. Keep it out of the Data API exposed schemas.

Run `supabase/verify.sql` with the SQL tool. All eight tables should have RLS,
client schema privileges must be false, client policies absent, and functions
must not be SECURITY DEFINER. Check migration history and run the plugin's security
and performance advisors; review findings in context.

Run `supabase/smoke.sql` for a transactional write/read check that rolls back its
fictional contact. Save project reference, migration name, role, date, and observed
results in `.local/connection-check.md`. Never store tokens in this file.

## 5. Start working

Ask for a daily review, then add one real lead at Maggie's request and preview an
intro. First real send: history check → explicit send authorization → database
reservation → Gmail send → retrieve evidence → record confirmation.

If Gmail succeeds but database recording fails, leave the intent unresolved and
reconcile that existing message when access returns. Do not send another copy.
A fresh checkout can repeat verification; the CRM remains in Supabase.

Official references:
[Repo skills](https://learn.chatgpt.com/docs/build-skills),
[OpenAI plugins](https://developers.openai.com/plugins/quickstart),
[Supabase MCP](https://supabase.com/docs/guides/ai-tools/mcp),
[RLS](https://supabase.com/docs/guides/database/postgres/row-level-security).
