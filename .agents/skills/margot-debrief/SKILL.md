---
name: margot-debrief
description: Help Maggie debrief an investor, introducer, or adviser conversation and record its outcome, questions, promises, and next action when requested.
---

# Debrief a conversation

Read [the outreach playbook](../../../docs/PLAYBOOK.md), especially its current
CRM mapping. Identify the person using Maggie's context and existing records;
resolve ambiguous identity before saving. Read relevant history if connected.

Let Maggie describe what happened. Ask only for missing details that matter:

- What did they ask, find useful, or object to?
- What materials, introductions, or other actions did either person promise?
- What is the next step, who owns it, and when?
- If they said "not now," did they specify a date or condition for revisiting it?
- If money came up, what amount and currency, what conditions, and what exact
  wording distinguished a possibility from a commitment or funds received?

Separate what was said from Maggie's interpretation. Friendly words do not establish
investment interest or a commitment. An introduction suggested is not an introduction
made. Do not pressure her to extract more names from a declined conversation.

Summarize the outcome and resolve material ambiguity. If she asked to log or update
it, proceed within that request without asking for the same permission again. A
request just to discuss the conversation can end with a proposed note and next step.

For a requested save, use [the database guide](../../../docs/DATABASE.md):

- Append the dated meeting/call summary, evidence, objections, and relevant lessons
  to `margot.notes`; corrections are additional notes.
- Change `contacts.status` only when Maggie's instruction supports that judgment.
  Preserve suppression; a debrief does not make standard unanswered-outreach
  templates applicable to an existing conversation.
- Set the requested `next_action` and `next_action_at`. Resolve relative dates using
  her timezone; ask when a necessary date is ambiguous. If no date was agreed, say
  so and propose one rather than recording an invented commitment.
- Store promised tasks in `margot.commitments` with owner/context in `description`.
  Record financial statements in notes as described in the playbook; this table
  does not track investment balances or cash receipts.
- Preserve the introducer in `lead_sources` for new contacts Maggie asks to add,
  using [add a lead](../margot-add-lead/SKILL.md). Incomplete new contacts remain
  explicitly unsaved in chat, or can be mentioned in the existing contact's note.

For milestone-based follow-up, record both the condition and any review date. A
date passing does not establish that the condition happened or authorize a send.
Do not create scheduled reminders. Suggest a thank-you or useful follow-up when
appropriate; use [conversation follow-up](../margot-conversation-follow-up/SKILL.md)
when asked to draft or send it, carrying forward the debrief and relevant email
history. Every send requires Maggie's explicit instruction.

Verify requested writes before saying they were saved. With no Supabase connection,
return the proposed summary in chat and state it is not saved to the CRM. Finish
with the next action and date or unresolved condition, without promising to act
later on Margot's own initiative.
