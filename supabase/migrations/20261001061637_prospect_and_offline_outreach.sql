-- Additive upgrade: preserve all existing contact IDs, messages and source records.
-- NULL means an email is not yet known; the existing unique/check constraints
-- still validate every non-NULL email. Names never become identity keys.
alter table margot.contacts alter column email drop not null;

alter table margot.send_intents drop constraint send_intents_kind_check;
alter table margot.send_intents add constraint send_intents_kind_check
  check (kind in ('intro', 'follow_up_1', 'follow_up_2', 'reply', 'offline_follow_up'));
alter table margot.messages drop constraint messages_kind_check;
alter table margot.messages add constraint messages_kind_check
  check (kind in ('intro', 'follow_up_1', 'follow_up_2', 'reply', 'offline_follow_up', 'auto_reply', 'bounce', 'opt_out', 'imported'));

-- An unresolved send keeps its reserved identity until reconciled/cancelled.
create function margot.guard_contact_email() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  if new.email is distinct from old.email and exists (
    select 1 from margot.send_intents where contact_id = old.id and state in ('prepared', 'uncertain')
  ) then raise exception 'Reconcile the unresolved send before changing its contact email'; end if;
  return new;
end $$;
create trigger guard_contact_email before update of email on margot.contacts
  for each row execute function margot.guard_contact_email();

create or replace function margot.due_followups(p_as_of timestamptz, p_first_days integer, p_second_days integer)
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
  where c.email is not null and s.permits_followup and not s.blocks_send
    and last_message.kind in ('intro', 'follow_up_1')
    and not exists (select 1 from margot.messages m where m.contact_id = c.id and m.direction = 'inbound')
    and not exists (select 1 from margot.send_intents i where i.contact_id = c.id and i.state in ('prepared', 'uncertain'))
    and greatest(last_message.occurred_at + make_interval(hours => 24 *
      case when last_message.kind = 'intro' then p_first_days else p_second_days end), c.next_action_at) <= p_as_of
  order by 4, c.email;
end $$;

create or replace function margot.guard_intent() returns trigger
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
  if c.email is null then raise exception 'Add a verified email before preparing a send'; end if;
  perform margot.validate_envelope(new.envelope);
  if new.envelope ->> 'recipient_email' is distinct from c.email then raise exception 'Recipient does not match contact'; end if;
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
  elsif new.kind = 'offline_follow_up' then
    if exists (select 1 from margot.messages where contact_id = c.id) then
      raise exception 'Existing email history requires a verified conversation reply';
    end if;
    if not exists (select 1 from margot.notes n where n.contact_id = c.id
      and n.id = (new.envelope ->> 'offline_note_id')::uuid) then
      raise exception 'Offline follow-up requires this contact''s saved conversation note';
    end if;
    if coalesce(new.envelope ->> 'gmail_thread_id', '') <> '' or
       coalesce(new.envelope ->> 'in_reply_to_message_id', '') <> '' then
      raise exception 'First offline follow-up starts a new thread; omit reply IDs';
    end if;
  elsif new.kind in ('follow_up_1', 'follow_up_2') then
    if not exists (
      select 1 from margot.due_followups(now(),
        (new.envelope ->> 'first_follow_up_days')::integer,
        (new.envelope ->> 'second_follow_up_days')::integer) d
      where d.contact_id = c.id and d.kind = new.kind and d.gmail_thread_id = new.envelope ->> 'gmail_thread_id'
    ) then raise exception 'Follow-up is not due or thread does not match'; end if;
  end if;
  if new.kind in ('follow_up_1', 'follow_up_2', 'reply') and (coalesce(new.envelope ->> 'gmail_thread_id', '') = '' or
     coalesce(new.envelope ->> 'in_reply_to_message_id', '') = '') then
    raise exception 'Replies need the verified Gmail thread and reply target';
  end if;
  return new;
end $$;

create or replace function margot.record_sent(p_intent uuid, p_message_id text, p_thread_id text,
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
  if i.kind in ('follow_up_1', 'follow_up_2', 'reply') and p_thread_id <> i.envelope ->> 'gmail_thread_id' then
    raise exception 'Thread mismatch; investigate and import evidence';
  end if;
  insert into margot.messages(contact_id, send_intent_id, direction, kind, mailbox_email,
    gmail_message_id, gmail_thread_id, occurred_at, envelope)
  values (i.contact_id, i.id, 'outbound', i.kind, p_actual ->> 'sender_email',
    p_message_id, p_thread_id, p_sent_at, p_actual) returning id into result;
  update margot.send_intents set state = 'sent' where id = i.id;
  -- Record facts even if an opt-out raced with the Gmail call. Never undo suppression.
  update margot.contacts set status = case when i.kind = 'offline_follow_up'
    then 'needs_review' else 'active' end where id = i.contact_id and status = 'new';
  return result;
end $$;

revoke all on all functions in schema margot from public, anon, authenticated, service_role;
