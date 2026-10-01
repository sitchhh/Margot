# First-time setup with Maggie

Read `AGENTS.md` and [the project brief](PROJECT.md). The company is Pink Fitness
Club; the operator is Maggie, publicly named Magnolia Barney on Kickstarter.
Confirm her preferred outreach name and signature.

Start with account creation if Maggie is new to Supabase. The connection order is
Supabase account and project → Supabase plugin → Gmail plugin → verification.
We use **plugin** for what Maggie installs in ChatGPT Desktop; MCP is the
technology that connects its tools to the service. She completes sign-up and
permission screens herself. Skip steps already completed after checking the
selected account and project.

## 1. Prepare the repo

Maggie needs GitHub access to this private repository. Clone
`https://github.com/sitchhh/Margot`, open that local folder in Codex, and trust it
after reviewing its instructions. Start a fresh chat if repo skills do not appear;
`AGENTS.md` also routes to their files directly.

Before filling in company copy, briefly recap the project brief and work through
its unanswered handoff questions with Maggie. Confirm the current additional
funding need; Rocky's roughly $120,000 recollection is not approved outreach copy.
Record confirmed context and its date in the appropriate place described in the
brief. Keep unknowns explicit and continue independent setup steps.

Use [the brand voice skill](../.agents/skills/margot-brand-voice/SKILL.md) to draft
company copy and show Maggie the professional investor and casual community
examples. Refine them using her edits; do not treat the initial profiles or the
Kickstarter's historical plans as approved current email copy. Reviewing tone or
templates never authorizes sending an email.

Run `python3 scripts/margot.py init`. It creates `config/local.json` without
overwriting an existing file. Fill in Maggie's sender address, signature, IANA
timezone, company summary, fundraising context, and call to action. Use her facts
and words. Review the three templates and set `templates_approved` to true once
she accepts the copy. Review the five/seven-day defaults in `config/outreach.json`.
Days are elapsed 24-hour periods, including weekends, after the previous send.

Run `python3 scripts/margot.py doctor`. This checks local files only. Python is
required for helpers, not for reading the instructions or connecting plugins.
An incomplete-profile result is expected until the account and profile steps
are finished; continue setup and rerun it afterward.

## 2. Create Maggie's Supabase account and project

1. Open the [Supabase dashboard](https://supabase.com/dashboard) and sign up with
   an account Maggie controls, or sign in if she already has one. Complete any
   account verification requested by Supabase.
2. Create an organization if prompted, or select her existing organization.
   Maggie chooses the plan shown during setup.
3. Create a dedicated project, for example **Margot**, in that organization.
   Choose its region and save any database password in her password manager.
   Wait for provisioning to finish. If she already has a dedicated project,
   select it instead of creating a duplicate.
4. Copy the project reference from the dashboard URL
   (`https://supabase.com/dashboard/project/YOUR_PROJECT_REF`) into
   `supabase_project_ref` in the ignored `config/local.json`.

Account creation alone does not connect Margot to Supabase. Never reuse the
developer's account or choose another project discovered in the account. Do not
put passwords, tokens, or database keys in chat or the repository.

## 3. Connect and check the Supabase plugin

1. In ChatGPT Desktop, open **Plugins**, search for **Supabase**, and install it.
2. Complete the plugin's connection/sign-in flow with the Supabase account from
   step 2. Select the organization containing her Margot project and review the
   requested permissions.
3. Scope the connection to the selected project where the connection UI supports
   it. Installing the plugin and authenticating are separate from selecting the
   correct project.
4. Start a new chat in the local Margot project to load the installed tools, then
   ask Margot to continue `docs/SETUP.md` and verify the selected project.

If direct MCP configuration is needed, use the official endpoint with the
selected reference and follow the [Supabase MCP guide](https://supabase.com/docs/guides/ai-tools/mcp):

```text
https://mcp.supabase.com/mcp?project_ref=YOUR_PROJECT_REF&features=database,docs,debugging
```

Replace the reference before configuring it through the client's MCP settings.
The `debugging` group enables the advisors used during verification.
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

## 4. Connect and check the Gmail plugin

1. In ChatGPT Desktop, open **Plugins**, search for **Gmail**, and install it.
2. Complete Google's sign-in flow with the mailbox Maggie will use for investor
   outreach. Review the requested permissions and finish the connection.
3. Start a new chat in the local Margot project and say, **“Margot, continue
   first-time setup using docs/SETUP.md.”** Check that the connected mailbox
   matches `sender_email` in `config/local.json`.

If a plugin or action is unavailable in her account, record that limitation and
continue the independent setup steps. Labels/actions vary by account and client;
inspect the actual tools. ChatGPT chat access does not prove Codex access, and a
Free plan must not be assumed to include every required action.

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

## 5. Apply the repository migration

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

## 6. Start working

Ask for a daily review, then add one real lead at Maggie's request and preview an
intro. First real send: history check → explicit send authorization → database
reservation → Gmail send → retrieve evidence → record confirmation.

If Gmail succeeds but database recording fails, leave the intent unresolved and
reconcile that existing message when access returns. Do not send another copy.
A fresh checkout can repeat verification; the CRM remains in Supabase.

Official references (connection instructions checked October 1, 2026):
[Repo skills](https://learn.chatgpt.com/docs/build-skills),
[OpenAI plugins](https://learn.chatgpt.com/docs/plugins),
[Supabase MCP](https://supabase.com/docs/guides/ai-tools/mcp),
[RLS](https://supabase.com/docs/guides/database/postgres/row-level-security).
