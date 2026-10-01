-- Internal, single-operator CRM. Access through the selected Supabase management
-- connection as postgres, not the public Data API. No external credentials here.
create schema margot;
revoke all on schema margot from public, anon, authenticated, service_role;
alter default privileges in schema margot revoke execute on functions from public;

create table margot.contact_statuses (
  code text primary key,
  label text not null,
  permits_intro boolean not null default false,
  permits_followup boolean not null default false,
  blocks_send boolean not null default false
);
insert into margot.contact_statuses values
  ('new', 'New', true, false, false),
  ('active', 'Awaiting reply', false, true, false),
  ('needs_review', 'Reply needs review', false, false, false),
  ('interested', 'Interested', false, false, false),
  ('meeting', 'Meeting', false, false, false),
  ('committed', 'Committed', false, false, false),
  ('maybe_later', 'Maybe later', false, false, false),
  ('passed', 'Passed', false, false, true),
  ('do_not_contact', 'Do not contact', false, false, true),
  ('bounced', 'Bounced', false, false, true),
  ('archived', 'Archived', false, false, true);

create table margot.contacts (
  id uuid primary key default gen_random_uuid(),
  email text not null unique check (email = lower(btrim(email)) and email ~ '^[^[:space:]<>@,;]+@[^[:space:]<>@,;]+\.[^[:space:]<>@,;]+$'),
  first_name text not null check (length(btrim(first_name)) > 0),
  last_name text,
  firm text,
  city text,
  status text not null default 'new' references margot.contact_statuses(code),
  next_action_at timestamptz,
  next_action text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index contacts_status_next_action on margot.contacts(status, next_action_at);

create table margot.lead_sources (
  id uuid primary key default gen_random_uuid(),
  contact_id uuid not null references margot.contacts(id),
  description text not null check (length(btrim(description)) > 0),
  source_url text,
  introduced_by text,
  captured_at timestamptz not null default now()
);
create index lead_sources_contact on margot.lead_sources(contact_id);

create table margot.notes (
  id uuid primary key default gen_random_uuid(),
  contact_id uuid not null references margot.contacts(id),
  body text not null check (length(btrim(body)) > 0),
  created_at timestamptz not null default now()
);
create index notes_contact on margot.notes(contact_id, created_at);

create table margot.commitments (
  id uuid primary key default gen_random_uuid(),
  contact_id uuid not null references margot.contacts(id),
  description text not null,
  due_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now()
);
create index commitments_contact on margot.commitments(contact_id);
create index commitments_due on margot.commitments(due_at) where completed_at is null;

create table margot.send_intents (
  id uuid primary key, -- Created once by the agent; reuse for all reconciliation.
  contact_id uuid not null references margot.contacts(id),
  kind text not null check (kind in ('intro', 'follow_up_1', 'follow_up_2', 'reply')),
  envelope jsonb not null,
  authorization_note text not null check (length(btrim(authorization_note)) > 0),
  state text not null default 'prepared' check (state in ('prepared', 'uncertain', 'sent', 'cancelled')),
  resolution_note text,
  created_at timestamptz not null default now()
);
create unique index one_unresolved_send_per_contact on margot.send_intents(contact_id)
  where state in ('prepared', 'uncertain');
create index send_intents_contact on margot.send_intents(contact_id, created_at);

create table margot.messages (
  id uuid primary key default gen_random_uuid(),
  contact_id uuid not null references margot.contacts(id),
  send_intent_id uuid unique references margot.send_intents(id),
  direction text not null check (direction in ('inbound', 'outbound')),
  kind text not null check (kind in ('intro', 'follow_up_1', 'follow_up_2', 'reply', 'auto_reply', 'bounce', 'opt_out', 'imported')),
  mailbox_email text not null check (mailbox_email = lower(btrim(mailbox_email))),
  gmail_message_id text not null check (length(btrim(gmail_message_id)) > 0),
  gmail_thread_id text not null check (length(btrim(gmail_thread_id)) > 0),
  occurred_at timestamptz not null,
  envelope jsonb not null, -- Exact retrieved sender, recipient, subject, body_text.
  recorded_at timestamptz not null default now(),
  unique (mailbox_email, gmail_message_id),
  check (direction = 'outbound' or send_intent_id is null)
);
create index messages_contact_time on margot.messages(contact_id, occurred_at desc);
create index messages_thread on margot.messages(mailbox_email, gmail_thread_id);

create table margot.events (
  id bigint generated always as identity primary key,
  contact_id uuid references margot.contacts(id),
  event_type text not null,
  details jsonb not null,
  recorded_at timestamptz not null default now()
);
create index events_contact_time on margot.events(contact_id, recorded_at);

create function margot.reject_history_change() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  raise exception 'History is retained. Append a correction or archive the contact.';
end $$;

create function margot.audit_row() returns trigger
language plpgsql security invoker set search_path = '' as $$
declare cid uuid;
begin
  if tg_table_name = 'contacts' then cid := new.id;
  else cid := new.contact_id; end if;
  insert into margot.events(contact_id, event_type, details)
  values (cid, tg_table_name || '.' || lower(tg_op),
    jsonb_build_object('before', case when tg_op = 'UPDATE' then to_jsonb(old) else null end, 'after', to_jsonb(new)));
  return new;
end $$;

create function margot.touch_contact() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end $$;
create trigger touch_contact before update on margot.contacts for each row execute function margot.touch_contact();

-- No anonymous/client access: RLS is defense in depth, with no client policies.
do $$
declare t text;
begin
  foreach t in array array['contact_statuses', 'contacts', 'lead_sources', 'notes', 'commitments', 'send_intents', 'messages', 'events'] loop
    execute format('alter table margot.%I enable row level security', t);
    execute format('create trigger retain_rows before delete on margot.%I for each row execute function margot.reject_history_change()', t);
    execute format('create trigger retain_table before truncate on margot.%I for each statement execute function margot.reject_history_change()', t);
  end loop;
  foreach t in array array['lead_sources', 'notes', 'messages', 'events'] loop
    execute format('create trigger retain_history before update on margot.%I for each row execute function margot.reject_history_change()', t);
  end loop;
  foreach t in array array['contacts', 'lead_sources', 'notes', 'commitments', 'send_intents', 'messages'] loop
    execute format('create trigger audit_change after insert or update on margot.%I for each row execute function margot.audit_row()', t);
  end loop;
end $$;

create function margot.validate_envelope(e jsonb) returns void
language plpgsql security invoker set search_path = '' as $$
declare k text;
begin
  foreach k in array array['sender_email', 'recipient_email', 'subject', 'body_text'] loop
    if jsonb_typeof(e -> k) is distinct from 'string' or length(btrim(e ->> k)) = 0 then
      raise exception 'Missing envelope field: %', k;
    end if;
  end loop;
  foreach k in array array['sender_email', 'recipient_email'] loop
    if e ->> k <> lower(btrim(e ->> k)) or e ->> k !~ '^[^[:space:]<>@,;]+@[^[:space:]<>@,;]+\.[^[:space:]<>@,;]+$' then
      raise exception 'Expected one normalized email for %', k;
    end if;
  end loop;
  if e ->> 'subject' ~ E'[\r\n]' then raise exception 'Subject contains a newline'; end if;
  if e ?| array['cc', 'bcc', 'attachments', 'body_html'] then
    raise exception 'V1 supports single-recipient plain-text email only';
  end if;
end $$;

-- Cadence is supplied from repo config; changing it changes unsent due dates.
create function margot.due_followups(p_as_of timestamptz, p_first_days integer, p_second_days integer)
returns table (contact_id uuid, email text, kind text, due_at timestamptz, gmail_thread_id text)
language plpgsql stable security invoker set search_path = '' as $$
begin
  if p_as_of is null or p_first_days is null or p_second_days is null or
     p_first_days not between 1 and 365 or p_second_days not between 1 and 365 then
    raise exception 'Supply as-of and delays between 1 and 365 days';
  end if;
  return query
  select c.id, c.email,
    case when last_message.kind = 'intro' then 'follow_up_1' else 'follow_up_2' end,
    greatest(last_message.occurred_at + make_interval(hours => 24 *
      case when last_message.kind = 'intro' then p_first_days else p_second_days end), c.next_action_at),
    last_message.gmail_thread_id
  from margot.contacts c
  join margot.contact_statuses s on s.code = c.status
  cross join lateral (
    select m.kind, m.occurred_at, m.gmail_thread_id
    from margot.messages m where m.contact_id = c.id and m.direction = 'outbound'
    order by m.occurred_at desc, m.recorded_at desc, m.id desc limit 1
  ) last_message
  where s.permits_followup and not s.blocks_send
    and last_message.kind in ('intro', 'follow_up_1')
    and not exists (select 1 from margot.messages m where m.contact_id = c.id and m.direction = 'inbound')
    and not exists (select 1 from margot.send_intents i where i.contact_id = c.id and i.state in ('prepared', 'uncertain'))
    and greatest(last_message.occurred_at + make_interval(hours => 24 *
      case when last_message.kind = 'intro' then p_first_days else p_second_days end), c.next_action_at) <= p_as_of
  order by 4, c.email;
end $$;

-- Preparation is a database reservation, not a send action or scheduler.
create function margot.guard_intent() returns trigger
language plpgsql security invoker set search_path = '' as $$
declare c margot.contacts; s margot.contact_statuses;
begin
  if tg_op = 'UPDATE' then
    if (to_jsonb(new) - 'state' - 'resolution_note') <> (to_jsonb(old) - 'state' - 'resolution_note') then
      raise exception 'Prepared send content is immutable; cancel and prepare a new intent';
    end if;
    if old.state in ('sent', 'cancelled') and new.state <> old.state then
      raise exception 'Resolved sends cannot be reopened';
    end if;
    if new.state = 'sent' and not exists (select 1 from margot.messages where send_intent_id = new.id) then
      raise exception 'Use record_sent with confirmed Gmail evidence';
    end if;
    if new.state = 'cancelled' and coalesce(length(btrim(new.resolution_note)), 0) = 0 then
      raise exception 'Explain how Gmail confirmed this was not sent';
    end if;
    return new;
  end if;
  if new.state <> 'prepared' then raise exception 'New intent must be prepared'; end if;
  select * into strict c from margot.contacts where id = new.contact_id for update;
  select * into strict s from margot.contact_statuses where code = c.status;
  if s.blocks_send then raise exception 'Contact is suppressed: %', c.status; end if;
  perform margot.validate_envelope(new.envelope);
  if new.envelope ->> 'recipient_email' <> c.email then raise exception 'Recipient does not match contact'; end if;
  if new.envelope ->> 'demo_only' = 'true' or (new.envelope ->> 'body_text') ~ '\{\{|\}\}' then
    raise exception 'Demo or unresolved placeholder cannot be sent';
  end if;
  if coalesce(new.envelope ->> 'template_path', '') = '' or
     coalesce(new.envelope ->> 'template_sha256', '') !~ '^[0-9a-f]{64}$' then
    raise exception 'Include source path and SHA-256 (including for custom replies)';
  end if;
  if new.kind = 'intro' then
    if not s.permits_intro or exists (select 1 from margot.messages where contact_id = c.id) then
      raise exception 'Intro requires a new contact with no prior messages';
    end if;
  elsif new.kind in ('follow_up_1', 'follow_up_2') then
    if not exists (
      select 1 from margot.due_followups(now(),
        (new.envelope ->> 'first_follow_up_days')::integer,
        (new.envelope ->> 'second_follow_up_days')::integer) d
      where d.contact_id = c.id and d.kind = new.kind and d.gmail_thread_id = new.envelope ->> 'gmail_thread_id'
    ) then raise exception 'Follow-up is not due or thread does not match'; end if;
  end if;
  if new.kind <> 'intro' and (coalesce(new.envelope ->> 'gmail_thread_id', '') = '' or
     coalesce(new.envelope ->> 'in_reply_to_message_id', '') = '') then
    raise exception 'Replies need the verified Gmail thread and reply target';
  end if;
  return new;
end $$;
create trigger guard_intent before insert or update on margot.send_intents
  for each row execute function margot.guard_intent();

create function margot.record_sent(p_intent uuid, p_message_id text, p_thread_id text,
  p_sent_at timestamptz, p_actual jsonb) returns uuid
language plpgsql security invoker set search_path = '' as $$
declare i margot.send_intents; existing margot.messages; result uuid;
begin
  select * into strict i from margot.send_intents where id = p_intent for update;
  select * into existing from margot.messages where send_intent_id = p_intent;
  if found then
    if existing.gmail_message_id is distinct from p_message_id or existing.gmail_thread_id is distinct from p_thread_id
      or existing.envelope is distinct from p_actual or existing.occurred_at is distinct from p_sent_at then
      raise exception 'Reconciliation conflicts with recorded send';
    end if;
    return existing.id;
  end if;
  if i.state = 'cancelled' then raise exception 'Cancelled intent: import actual send and append an explanation'; end if;
  perform margot.validate_envelope(p_actual);
  if p_actual ->> 'sender_email' <> i.envelope ->> 'sender_email' or
     p_actual ->> 'recipient_email' <> i.envelope ->> 'recipient_email' then
    raise exception 'Actual sender/recipient differs from reserved send; investigate and import evidence';
  end if;
  if i.kind <> 'intro' and p_thread_id <> i.envelope ->> 'gmail_thread_id' then
    raise exception 'Thread mismatch; investigate and import evidence';
  end if;
  insert into margot.messages(contact_id, send_intent_id, direction, kind, mailbox_email,
    gmail_message_id, gmail_thread_id, occurred_at, envelope)
  values (i.contact_id, i.id, 'outbound', i.kind, p_actual ->> 'sender_email',
    p_message_id, p_thread_id, p_sent_at, p_actual) returning id into result;
  update margot.send_intents set state = 'sent' where id = i.id;
  -- Record facts even if an opt-out raced with the Gmail call. Never undo suppression.
  update margot.contacts set status = 'active' where id = i.contact_id and status = 'new';
  return result;
end $$;

create function margot.record_inbound(p_contact uuid, p_mailbox text, p_message_id text,
  p_thread_id text, p_received_at timestamptz, p_kind text, p_actual jsonb) returns uuid
language plpgsql security invoker set search_path = '' as $$
declare existing margot.messages; result uuid;
begin
  perform 1 from margot.contacts where id = p_contact for update;
  if p_kind not in ('reply', 'auto_reply', 'bounce', 'opt_out') or p_kind is null then
    raise exception 'Invalid inbound classification';
  end if;
  -- Incoming messages may have HTML, CCs, mailer-daemon senders, or blank subjects.
  -- Preserve supplied Gmail evidence; do not apply outgoing formatting rules.
  if jsonb_typeof(p_actual) is distinct from 'object' or not p_actual ?& array['sender_email', 'recipient_email', 'subject', 'body_text'] then
    raise exception 'Include complete Gmail message evidence';
  end if;
  select * into existing from margot.messages where mailbox_email = p_mailbox and gmail_message_id = p_message_id;
  if found then
    if existing.contact_id <> p_contact or existing.direction <> 'inbound' or existing.envelope <> p_actual
       or existing.gmail_thread_id <> p_thread_id or existing.occurred_at <> p_received_at or existing.kind <> p_kind then
      raise exception 'Gmail message already recorded with different evidence; append a correction';
    end if;
    return existing.id;
  end if;
  insert into margot.messages(contact_id, direction, kind, mailbox_email, gmail_message_id,
    gmail_thread_id, occurred_at, envelope)
  values (p_contact, 'inbound', p_kind, p_mailbox, p_message_id, p_thread_id, p_received_at, p_actual)
  returning id into result;
  update margot.contacts c set status = case
    when p_kind = 'opt_out' then 'do_not_contact'
    when s.blocks_send then c.status
    when p_kind = 'bounce' then 'bounced' else 'needs_review' end
  from margot.contact_statuses s where c.id = p_contact and s.code = c.status;
  return result;
end $$;

revoke all on all tables in schema margot from public, anon, authenticated, service_role;
revoke all on all sequences in schema margot from public, anon, authenticated, service_role;
revoke all on all functions in schema margot from public, anon, authenticated, service_role;
