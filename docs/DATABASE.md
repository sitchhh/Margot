# Database reference

The private `margot` schema uses caller privileges and verified management/owner
access. No client RLS policies or Data API grants are present.

| Table | Meaning |
| --- | --- |
| contacts | Unique normalized email, identity, status, next action, dates |
| contact_statuses | Extensible labels and intro/follow-up/suppression flags |
| lead_sources | Append-only sources, URLs, introducers |
| notes | Append-only notes/corrections |
| commitments | Promises/tasks and due/completed times; edits audited |
| send_intents | Immutable planned copy/authorization; preparation/outcome state |
| messages | Append-only actual Gmail evidence |
| events | Append-only before/after audit records |

Emails are trimmed/lowercased; no plus-tag/dot collapsing or fuzzy merging. Store
timestamptz, display in Maggie's timezone. Cadence comes from repo config via SQL
arguments, with at most two standard follow-ups. Changes affect future eligibility,
not historical timestamps. Any inbound history excludes a contact from standard
unanswered-outreach suggestions; changing status back to active does not restore
eligibility. Conversation follow-ups use tailored `reply` messages. These are
eligibility and bookkeeping rules; no query, date, or status triggers sending.

## Query recipes

`:placeholders` below illustrate bound values, not literal runnable SQL. Use tool
parameters when supported; otherwise quote data safely as SQL values (including
backslash/string mode and dollar-quote delimiter handling). Never interpolate raw
email text into SQL. Every tool call uses the configured project reference.

```sql
select * from margot.contacts where email = lower(btrim(:email));
select * from margot.messages where contact_id = :contact_id order by occurred_at, recorded_at;
select * from margot.send_intents where contact_id = :contact_id order by created_at;
select * from margot.notes where contact_id = :contact_id order by created_at;
select * from margot.lead_sources where contact_id = :contact_id order by captured_at;
select * from margot.commitments where contact_id = :contact_id order by due_at;
```

Add a contact/source atomically. On duplicate email retain the existing identity
and status; ask before replacing identity details. Append each source only once
on retries. A single SQL operation can use a CTE:

```sql
with added as (
  insert into margot.contacts(email, first_name, last_name, firm)
  values (lower(btrim(:email)), :first_name, :last_name, :firm)
  on conflict (email) do nothing returning id
), target as (
  select id from added union all
  select id from margot.contacts where email = lower(btrim(:email))
)
insert into margot.lead_sources(contact_id, description, source_url, introduced_by)
select id, :source_description, :source_url, :introduced_by from target
where not exists (select 1 from margot.lead_sources s
  where s.contact_id = target.id and s.description = :source_description
    and s.source_url is not distinct from :source_url)
returning contact_id;
```

If a concurrent insert caused no ID to return, read the contact again and append
the missing source; do not claim a new lead was saved without observing it.

Due candidates (not send authorization):

```sh
python3 scripts/margot.py due-sql --as-of 2026-10-01T12:00:00-06:00
```

The helper prints executable SQL with current configured delays. It excludes
unresolved sends, inbound history, ineligible/suppressed statuses, latest imported
outbound mail, and contacts with both standard follow-ups already sent.
next_action_at may postpone eligibility. This query is not a list of all conversation
work; also review next actions, commitments, and relevant threads when asked.

Prepare a send with a once-generated operation UUID:

```sql
insert into margot.send_intents(id, contact_id, kind, envelope, authorization_note)
values (:operation_uuid, :contact_id, :kind, :planned_envelope::jsonb, :authorization_note)
returning id, state;
```

kind: intro, follow_up_1, follow_up_2, reply. Envelope: sender_email, recipient_email,
subject, body_text, template_path, template_sha256. Follow-ups also require both
configured delays, gmail_thread_id, in_reply_to_message_id; replies require the
last two. Never send demo output. An existing UUID means reconcile, not resend.

```sql
select margot.record_sent(:intent_uuid, :gmail_message_id, :gmail_thread_id,
  :sent_at::timestamptz, :actual_envelope::jsonb);
select margot.record_inbound(:contact_id, :mailbox_email, :gmail_message_id,
  :gmail_thread_id, :received_at::timestamptz, :classification, :actual_envelope::jsonb);
```

Actual evidence includes sender_email, recipient_email, subject, body_text. Incoming
mail may additionally contain HTML, CCs, headers, etc. Associate incoming mail by
verified thread/addresses; the database cannot infer a contact from mailer-daemon.
Inbound classification: reply, auto_reply, bounce, opt_out. Exact replays return
the existing message; conflicting replays fail. Correct with a new note and explicit
state update, never edit the original message.

```sql
select * from margot.send_intents where state in ('prepared', 'uncertain') order by created_at;
select * from margot.contacts where status = 'needs_review' order by updated_at;
select * from margot.contacts where next_action_at <= now() order by next_action_at;
select * from margot.commitments where completed_at is null order by due_at nulls last;
```

## Outside-Margot mail and exceptional reconciliation

Import relevant Gmail history with its unique (mailbox_email, gmail_message_id) and
exact evidence. Incoming mail uses record_inbound. For outside-Margot outbound mail,
insert messages with direction outbound, kind imported, no send_intent_id. In the
same transaction move an unsuppressed contact to needs_review and append an import
note. Preserve blocked statuses. On conflict read/compare, never overwrite.

Don't fabricate template hashes for imports or treat them as standard follow-up
candidates. Maggie can request a conversation follow-up in the verified thread.

If a cancelled intent was actually sent, import the evidence and append a note
linking its UUID. If an unresolved intent's sent message was already imported,
verify exact evidence and resolve it as cancelled with a resolution_note stating
the send is already recorded under that message ID. Preserve both records; this
bookkeeping resolution never authorizes a resend.

## Schema changes

New status labels are rows, not enum alterations. Default new statuses to excluding
standard unanswered follow-up suggestions. City is already included; other fields
use additive migrations.
Inspect CLI help, then `supabase migration new <name>`. Test locally and deploy
through the selected project's migration tool within Maggie's requested change.
Preserve applied migration files; add subsequent files for changes. Record backfills
explicitly. Never reset the live database or delete outreach history.
