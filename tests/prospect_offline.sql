\set ON_ERROR_STOP on
begin;
do $$
declare
  jane uuid := gen_random_uuid(); other uuid := gen_random_uuid();
  note_id uuid := gen_random_uuid(); intent uuid := gen_random_uuid(); source_id uuid := gen_random_uuid();
  e jsonb; actual jsonb; message uuid; replay uuid; other_note uuid; cadence_contact uuid; cadence_intent uuid;
begin
  insert into margot.contacts(id, first_name, firm) values (jane, 'Jane', 'Example Ventures');
  insert into margot.contacts(id, first_name, firm) values (other, 'Jane', 'Example Ventures');
  insert into margot.lead_sources(id, contact_id, description, introduced_by)
  values (source_id, jane, 'Possible introduction; not yet offered', 'Sarah');
  insert into margot.notes(id, contact_id, body)
  values (note_id, jane, 'Maggie met Jane at a fitness event on October 1. Jane asked for a short overview.');
  -- Replaying stable IDs does not create another prospect or source.
  insert into margot.contacts(id, first_name) values (jane, 'Jane') on conflict (id) do nothing;
  insert into margot.lead_sources(id, contact_id, description)
  values (source_id, jane, 'Possible introduction; not yet offered') on conflict (id) do nothing;
  if (select count(*) from margot.contacts where first_name = 'Jane') <> 2 or
     (select count(*) from margot.lead_sources where contact_id = jane) <> 1 then
    raise exception 'Prospect identity/idempotency failed';
  end if;
  e := jsonb_build_object('sender_email', 'maggie@example.com', 'recipient_email', 'jane@example.com',
    'subject', 'Nice meeting you', 'body_text', 'Here is the overview you requested.',
    'template_path', '.local/meeting-email.md', 'template_sha256', repeat('c', 64), 'offline_note_id', note_id);
  begin
    insert into margot.send_intents(id, contact_id, kind, envelope, authorization_note)
    values (intent, jane, 'offline_follow_up', e, 'Maggie asked to send this message');
    raise exception 'Missing email should block sending';
  exception when raise_exception then
    if sqlerrm <> 'Add a verified email before preparing a send' then raise; end if;
  end;

  update margot.contacts set email = 'jane@example.com' where id = jane;
  if not exists(select 1 from margot.notes where id = note_id and contact_id = jane) or
     not exists(select 1 from margot.lead_sources where id = source_id and contact_id = jane) then
    raise exception 'Adding email lost prospect history';
  end if;
  begin
    update margot.contacts set email = 'jane@example.com' where id = other;
    raise exception 'Duplicate known email accepted';
  exception when unique_violation then null; end;
  if (select email from margot.contacts where id = other) is not null then
    raise exception 'Email collision modified the other contact';
  end if;
  begin
    insert into margot.send_intents(id, contact_id, kind, envelope, authorization_note)
    values (intent, jane, 'offline_follow_up', e - 'offline_note_id', 'test');
    raise exception 'Missing conversation context accepted';
  exception when raise_exception then
    if position('saved conversation note' in sqlerrm) = 0 then raise; end if;
  end;
  insert into margot.notes(contact_id, body) values (other, 'A different person met Maggie.') returning id into other_note;
  begin
    insert into margot.send_intents(id, contact_id, kind, envelope, authorization_note)
    values (intent, jane, 'offline_follow_up', e || jsonb_build_object('offline_note_id', other_note), 'test');
    raise exception 'Another contact''s note accepted';
  exception when raise_exception then
    if position('saved conversation note' in sqlerrm) = 0 then raise; end if;
  end;
  begin
    insert into margot.send_intents(id, contact_id, kind, envelope, authorization_note)
    values (intent, jane, 'offline_follow_up', e || '{"gmail_thread_id":"invented"}', 'test');
    raise exception 'Invented thread accepted';
  exception when raise_exception then
    if position('omit reply IDs' in sqlerrm) = 0 then raise; end if;
  end;
  update margot.contacts set status = 'do_not_contact' where id = jane;
  begin
    insert into margot.send_intents(id, contact_id, kind, envelope, authorization_note)
    values (intent, jane, 'offline_follow_up', e, 'test');
    raise exception 'Suppressed contact accepted';
  exception when raise_exception then
    if position('Contact is suppressed' in sqlerrm) = 0 then raise; end if;
  end;
  update margot.contacts set status = 'meeting' where id = jane;
  insert into margot.send_intents(id, contact_id, kind, envelope, authorization_note)
  values (intent, jane, 'offline_follow_up', e, 'Maggie asked to send this exact message');
  begin
    update margot.contacts set email = 'changed@example.com' where id = jane;
    raise exception 'Reserved identity changed';
  exception when raise_exception then
    if position('Reconcile the unresolved send' in sqlerrm) = 0 then raise; end if;
  end;
  actual := e - 'offline_note_id';
  message := margot.record_sent(intent, 'offline-message', 'new-gmail-thread', now(), actual);
  replay := margot.record_sent(intent, 'offline-message', 'new-gmail-thread', now(), actual);
  if message <> replay or (select status from margot.contacts where id = jane) <> 'meeting' or
     (select kind from margot.messages where id = message) <> 'offline_follow_up' then
    raise exception 'Offline send evidence or status lost';
  end if;
  update margot.contacts set status = 'active' where id = jane;
  if exists(select 1 from margot.due_followups(now() + interval '100 days', 5, 7) where contact_id = jane) then
    raise exception 'Offline conversation entered unanswered intro cadence';
  end if;
  begin
    insert into margot.send_intents(id, contact_id, kind, envelope, authorization_note)
    values (gen_random_uuid(), jane, 'offline_follow_up', e, 'test');
    raise exception 'Second first-offline email accepted';
  exception when raise_exception then
    if position('Existing email history' in sqlerrm) = 0 then raise; end if;
  end;
  -- Subsequent conversation mail uses the real newly created Gmail thread.
  insert into margot.send_intents(id, contact_id, kind, envelope, authorization_note)
  values (gen_random_uuid(), jane, 'reply', e || jsonb_build_object('gmail_thread_id', 'new-gmail-thread',
    'in_reply_to_message_id', 'offline-message'), 'Maggie requests the next conversation reply');

  -- Removing a no-longer-known address excludes even a previously due contact.
  insert into margot.contacts(email, first_name) values ('cadence@example.com', 'Cadence') returning id into cadence_contact;
  cadence_intent := gen_random_uuid();
  e := e || jsonb_build_object('recipient_email', 'cadence@example.com');
  insert into margot.send_intents(id, contact_id, kind, envelope, authorization_note)
  values (cadence_intent, cadence_contact, 'intro', e, 'Fictional test authorization');
  perform margot.record_sent(cadence_intent, 'cadence-message', 'cadence-thread', now(), e);
  if not exists(select 1 from margot.due_followups(now() + interval '6 days', 5, 7) where contact_id = cadence_contact) then
    raise exception 'Control contact should be due before email is removed';
  end if;
  update margot.contacts set email = null where id = cadence_contact;
  if exists(select 1 from margot.due_followups(now() + interval '6 days', 5, 7) where contact_id = cadence_contact) then
    raise exception 'Email-less contact appeared in due email candidates';
  end if;
  raise notice 'PASS: email-less prospects, stable identity, offline send guards, exact recording, and later replies';
end $$;
rollback;
