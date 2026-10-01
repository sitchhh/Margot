# Margot

Margot is the agent working in this repo: Maggie's investor-outreach assistant
for **Pink Fitness Club**, powered by Codex.

```text
Maggie → ChatGPT Desktop / Codex → Margot repo
                                  ├── behavior, skills, templates, helpers
                                  ├── Supabase plugin/MCP → persistent memory
                                  └── Gmail plugin → Maggie's mailbox
```

**Maggie's Gmail and Supabase are not connected. No live migration has been
applied.** Gmail read, draft, send, and reply capabilities must be checked on her
actual account. Plugin availability alone does not verify those actions.

## Maggie's first session

1. Clone this private repo using a GitHub account with access to `sitchhh/Margot`.
2. Open the `Margot` folder as a local Codex project in ChatGPT Desktop.
3. Say: **“Margot, walk me through first-time setup using docs/SETUP.md.”**

Margot will help fill in your identity and company copy, connect the two plugins,
apply the schema to your selected project, and verify the setup. Authentication
stays in the plugins. No OpenAI API key or application deployment is needed.

[Project brief](docs/PROJECT.md) · [Setup guide](docs/SETUP.md) · [Outreach procedure](docs/OUTREACH.md) ·
[Database guide](docs/DATABASE.md) · [Outreach playbook](docs/PLAYBOOK.md)

## Project context that travels with the repo

[The project brief](docs/PROJECT.md) records what Pink Fitness Club is, the sourced
Kickstarter result, why Margot exists, and what Maggie still needs to confirm.
`AGENTS.md` directs Margot to read it at the start of each conversation. First-time
setup turns Maggie's answers into current context and approved local email copy.
Leads and relationship history live in Supabase; the brief travels with the repo
and can orient Margot even before the accounts are connected.

## What's here

| Path | Purpose |
| --- | --- |
| `AGENTS.md` | Margot's identity and operating rules |
| `docs/PROJECT.md` | Pink Fitness Club's business context, sources, and questions for Maggie |
| `.agents/skills/` | Network mapping, prospect research, debriefs, setup, leads, email workflows, review, maintenance |
| `docs/PLAYBOOK.md` | Prospect fit, introductions, conversation preparation, and useful next steps |
| `templates/` | Canonical email copy; placeholders require Maggie's actual facts |
| `config/outreach.json` | Five days to follow-up #1, seven more to #2; editable defaults |
| `config/local.example.json` | Profile to copy locally; real configuration is Git-ignored |
| `scripts/margot.py` | Offline checks, strict rendering, and due-query generation |
| `supabase/migrations/` | Private CRM schema and transactional bookkeeping functions |
| `tests/` | Helper and database behavior tests with fictional data |

## Try it without connections

Python 3.10+ is enough for helpers. Substitute `python` on systems using that name.
Timezone validation needs the IANA timezone database; if absent (often Windows),
install Python's `tzdata` package.

```sh
python3 scripts/margot.py doctor
python3 scripts/margot.py render investor-intro --demo --data examples/intro.json
python3 -m unittest discover -s tests -v
```

`doctor` exits 1 while the profile is incomplete and never claims to verify live
connections. `--demo` outputs fictional, unsendable copy. No helper sends email or
connects to a live database.

Developer database tests: `python3 scripts/test_database.py` starts an isolated,
temporary PostgreSQL 17+ cluster. Install Postgres or set `MARGOT_PG_BIN` to its
binaries directory. Maggie does not need local Postgres for daily plugin use.

## Things Maggie can ask

- “Help me work through people I know who could invest or introduce me.”
- “Research this organization: why might it fit, and how could I get introduced?”
- “Let me tell you how that meeting went; record the outcome and next step.”
- “Add Alex as a lead; here's their email and where I met them.”
- “Draft an intro for Alex.”
- “Who needs their first follow-up?”
- “Read my exchange with Alex and draft a follow-up about the financials they requested.”
- “Process replies and show me anything I need to answer.”
- “Move Alex to Maybe Later and set a next action for November.”
- “Make the second follow-up less formal.”
- “Change the first follow-up delay to seven days.”

The network, research, and debrief skills can help before the accounts are connected;
they distinguish proposed findings from information actually saved in Supabase.

Work runs when Maggie asks in the conversation. Opening the repo starts nothing.
Next-action dates and follow-up intervals help Maggie review what is due; they do
not schedule work or send email. Every send needs her explicit request for that
recipient and message in the active conversation.

There are two follow-up skills: [unanswered outreach](.agents/skills/margot-follow-up/SKILL.md)
uses the first and second follow-up templates when there has been no inbound mail;
[conversation follow-up](.agents/skills/margot-conversation-follow-up/SKILL.md) reads
the full thread, meeting notes, and outstanding promises to prepare a tailored
message after an exchange. Either skill sends only on Maggie's explicit instruction.
The two-template limit applies to unanswered outreach, not to ongoing conversations.

## Editing email templates

The editable originals live in this repo: [introduction](templates/investor-intro.md),
[first follow-up](templates/follow-up-1.md), and
[second follow-up](templates/follow-up-2.md). Maggie can edit the Markdown directly
or say, "Make the introduction warmer and show me a preview." Margot updates the
template and checks the rendered copy; approving a template does not send an email.

Keep one editable source for each template. Supabase records the exact message
actually sent and the hash identifying the template used. Editing future copy
does not rewrite that history. There is no second editable template copy to sync.

## Boundaries

One operator, one mailbox, one Supabase project. Standard sends support one
recipient and plain text; CC/BCC, attachments, rich HTML, and bulk sending require
a workflow extension. Historical Gmail evidence can still preserve these fields.
The management connection has database-owner powers. RLS and history triggers
protect against routine mistakes and Data API access, not an owner deliberately
changing schema. Use a dedicated project and normal Supabase backups.

References checked September 30, 2026:
[Codex skills](https://learn.chatgpt.com/docs/build-skills),
[OpenAI plugins](https://developers.openai.com/plugins/quickstart),
[Supabase MCP](https://supabase.com/docs/guides/ai-tools/mcp).
Account-specific access remains a first-session check.
