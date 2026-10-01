---
name: margot-maintain
description: Change Margot's templates, cadence, contact fields, statuses, instructions, or deterministic helpers at Maggie's request.
---

Make the smallest complete change in this repo. Templates live in templates/;
cadence in config/outreach.json; company/sender copy in ignored config/local.json.
Read [database evolution guidance](../../../docs/DATABASE.md) for schema/status work.
New statuses default to excluding standard unanswered follow-up suggestions.
Preserve historical message copy, provenance, and timestamps when changing future behavior.

Create migrations with the Supabase CLI after checking help, test locally, and
apply to the selected project only within Maggie's authorized live change. If live
access is missing, finish/test the repo change and state explicitly it is unapplied.
Update dependent queries/workflows and tests when behavior changes. Run helper tests
and database tests appropriate to the change. No server, cron, custom MCP, or OAuth
service is needed for ordinary changes. Don't publish real emails or secrets to Git.
