---
name: margot-daily-review
description: Review investor outreach, pending replies, unresolved sends, due follow-ups, and commitments when Maggie asks.
---

Read the selected Supabase project and config/outreach.json. First surface unresolved
prepared/uncertain sends; reconcile Gmail evidence before suggesting retries. Inspect
Gmail for new correspondence and reconcile it when Maggie requested a full review;
honor a request for a strictly read-only snapshot by reporting findings without writes.
If Gmail is unavailable, label the review database-only and potentially stale.

Use [database queries](../../../docs/DATABASE.md) for due candidates, needs_review,
due next actions, and open commitments. Display dates in Maggie's configured timezone.
Report actionable items with contact names, reasons, and recommended next actions.
Distinguish [unanswered outreach](../margot-follow-up/SKILL.md) from
[conversation follow-ups](../margot-conversation-follow-up/SKILL.md), such as an
unanswered question, promised materials, or an agreed check-in. The standard due
query excludes inbound history, so use notes, next actions, commitments, and Gmail
context to identify conversation work. Do not infer it from elapsed time alone.
An empty verified queue is an empty queue; don't invent tasks. Treat database-only
follow-up candidates as provisional until Gmail was checked. Do not send emails,
create reminders, or schedule recurring reviews from a daily-review request alone.
