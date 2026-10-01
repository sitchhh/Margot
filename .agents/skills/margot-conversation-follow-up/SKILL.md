---
name: margot-conversation-follow-up
description: Draft replies or context-aware follow-ups after an investor, introducer, or adviser exchange or meeting; send only when Maggie explicitly asks. Read the full conversation and outstanding commitments first.
---

# Follow up on a conversation

Use this skill when Maggie asks to reply or follow up after an exchange, including
when she sent the latest message and is waiting on an agreed next step. Use
[unanswered outreach](../margot-follow-up/SKILL.md) for standard first or second
nudges with no inbound history. An out-of-office notice alone is not a substantive
reply; review its timing and meaning before proposing any custom message.

## Establish what is outstanding

Identify the recipient and relevant conversation. Read the full Gmail thread in
chronological order, including messages Maggie sent outside Margot. Check other
relevant threads using the exact address, all result pages, and full message bodies;
do not draft from snippets, the latest message alone, or CRM status alone.

Read the contact's recorded messages, notes, meeting debriefs, commitments, next
action, suppression, and unresolved sends. Use
[reply processing](../margot-process-replies/SKILL.md) to reconcile new correspondence
within Maggie's request. An explicitly read-only review does not authorize writes.
If history is unavailable, identify the gap. Supplied thread text can support a
provisional draft; do not claim the full history was checked or proceed to send.

Give Maggie the context that affects the next message:

- Who last wrote, when, and what they asked or answered.
- Stated interest, concerns, objections, declines, or timing restrictions.
- What either person promised, who owes the next action, and what is still open.
- Any agreed date or milestone and whether it has actually been met.

Separate evidence from inference. An unanswered question from the recipient may
mean Maggie owes an answer, not that they need a reminder. Don't repeat a request
already answered, promise materials were sent without evidence, treat vague interest
as a commitment, or reinterpret a decline as permission to keep pitching. Ask only
for missing facts or intent that materially affect the message.

## Prepare the next message

Use [the playbook](../../../docs/PLAYBOOK.md) to draft a concise, specific response
that addresses the outstanding point and matches the exchange's tone.
Use [brand voice](../margot-brand-voice/SKILL.md) to choose professional or casual
wording according to Maggie's direction and the actual relationship. Conversation
follow-ups use tailored copy; the two unanswered-outreach templates and their cadence
do not govern this exchange. Respect requested timing and contact restrictions.
Do not relabel a third standard unanswered nudge as a conversation reply to bypass
the two-follow-up limit. Explain when waiting or taking another action fits better.

Choose the path supported by the full history:

- **Existing email conversation:** preserve the verified Gmail thread, original
  subject, and correct reply target. Use `reply`, even when Maggie wrote last.
- **First email after an offline conversation:** if the complete Gmail search and
  CRM history establish there has been no prior email, use `offline_follow_up`.
  Save a dated note for this contact recording the meeting/call, what was discussed,
  and the requested next step. Include its UUID as `offline_note_id` in the intent.
  Use a truthful new subject and omit thread/reply IDs; Gmail supplies the new thread
  after sending. An email-less prospect first needs a verified address added to
  their existing contact. Follow the conversation's agreed timing and restrictions.

Use the custom-copy provenance, authorization, reservation and evidence rules in
[the sending procedure](../../../docs/OUTREACH.md) for either path. Missing access
or incomplete search is not evidence of no prior mail. Never invent thread IDs or
mislabel this as an introduction. This first offline follow-up does not enter the
two-template unanswered-intro cadence; later requested correspondence uses `reply`
in the real thread. Record and review the agreed next action.

Nothing runs or sends automatically. A review, a draft, a due date, or a saved next
action is not send authorization. Send only when Maggie explicitly requests the
identified recipient and message in the active conversation; use clear existing
authorization without asking twice. Refresh Gmail history immediately before sending;
if new mail changes the proposed response, revise it and resolve any materially
changed recipient or copy with Maggie. Preserve suppression and unresolved intents.
