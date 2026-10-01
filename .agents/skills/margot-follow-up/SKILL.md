---
name: margot-follow-up
description: Review or draft first and second follow-ups to unanswered investor outreach, and send only when Maggie explicitly asks. Use the conversation follow-up skill for an existing exchange.
---

Use this skill for an introduction that has received no inbound message. For a
reply, a follow-up after an exchange, or a meeting debrief with an agreed next step,
use [conversation follow-up](../margot-conversation-follow-up/SKILL.md).

Read config/outreach.json and [the sending procedure](../../../docs/OUTREACH.md).
When Maggie asks who is due, generate the due query with the helper and an explicit
current offset-aware time; execute against the selected project. Show candidates,
their last send, and due time in Maggie's timezone. These dates help her choose
what to review; nothing runs in the background or sends because a date passes.

Before drafting or sending, read full Gmail history, including Maggie's own mail,
and [reconcile new inbound mail](../margot-process-replies/SKILL.md). Check what was
already asked or supplied so the draft does not repeat or contradict it. If any
inbound message exists, the contact is ineligible for these standard templates.
An auto-reply needs review; it does not establish a substantive conversation.

Use templates/follow-up-1.md or templates/follow-up-2.md according to the actual
recorded sends. Use [brand voice](../margot-brand-voice/SKILL.md) for any requested
copy changes, retaining the professional tone by default and the template provenance.
Preserve the original subject and verified Gmail thread/reply
target. The limit is two standard unanswered follow-ups, not a limit on replies
in a real conversation. Snoozes postpone eligibility; they never authorize a send.
Honor suppression and unresolved send attempts. Explain exclusions when asked.

A review or draft request ends with candidates or copy. Send only when Maggie
explicitly requests the identified recipient and message in the active conversation,
following the shared sending procedure. Honor clear existing authorization without
asking twice. Query results and template approval never authorize sending.
