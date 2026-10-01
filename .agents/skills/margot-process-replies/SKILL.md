---
name: margot-process-replies
description: Read and reconcile Gmail replies, bounces, opt-outs, and outside-Margot correspondence with the investor CRM when Maggie asks for reply processing or an outreach task needing current history.
---

Use [database recording rules](../../../docs/DATABASE.md). Inspect tracked threads
and exact-contact-address searches, including all pages and messages sent by Maggie.
Gmail read/unread state is not an import cursor. Deduplicate by mailbox and provider
message ID. Associate replies by actual participants/thread, not subject alone;
resolve ambiguous identities before writing.

Preserve exact full evidence and timestamp. Call record_inbound for reply,
auto_reply, bounce, or opt_out. Any inbound makes the contact ineligible for the
standard unanswered-outreach templates. Auto-replies are not investor interest;
an out-of-office return date is a suggested review date, not permission to send.
Honor opt-outs immediately. Preserve blocked statuses.
Record commitments/next actions only when grounded in the actual exchange; ask
about ambiguous promises or dates. Don't claim investment based on vague interest.

Append corrections instead of editing history. Summarize who replied, what they
need, and what Maggie should decide. Use
[conversation follow-up](../margot-conversation-follow-up/SKILL.md) when she asks to
draft or send a response grounded in that exchange. Processing records what happened;
it runs only within her requested task and never authorizes an email. Every send
requires her explicit instruction for the recipient and message.
