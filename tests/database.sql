\set ON_ERROR_STOP on
begin;
set local timezone = 'America/New_York';

create function pg_temp.assert_true(ok boolean, label text) returns void language plpgsql as $$
begin
  if ok is not true then raise exception 'FAIL: %', label; end if;
  raise notice 'PASS: %', label;
end $$;

create function pg_temp.expect_error(statement text, fragment text) returns void language plpgsql as $$
begin
  begin
    execute statement;
  exception when others then
    if position(fragment in sqlerrm) = 0 then raise exception 'Unexpected error: % (expected %)', sqlerrm, fragment; end if;
    return;
  end;
  raise exception 'Expected failure: %', fragment;
end $$;

do $$
declare
  c uuid; suppressed uuid; i uuid := gen_random_uuid(); i2 uuid := gen_random_uuid();
  i3 uuid := gen_random_uuid(); m uuid; replay uuid; t timestamptz := now() - interval '20 days';
  envelope jsonb := jsonb_build_object('sender_email', 'maggie@example.com',
    'recipient_email', 'alex@example.com', 'subject', 'Hello', 'body_text', 'A real test body.',
    'template_path', 'templates/investor-intro.md', 'template_sha256', repeat('a', 64));
  inbound jsonb := jsonb_build_object('sender_email', 'alex@example.com',
    'recipient_email', 'maggie@example.com', 'subject', 'Re: Hello', 'body_text', 'Please stop.');
begin
  perform pg_temp.assert_true((select count(*) = 8 and bool_and(rowsecurity) from pg_tables where schemaname = 'margot'), 'RLS enabled on all eight tables');
  perform pg_temp.assert_true(not has_schema_privilege('anon', 'margot', 'USAGE')
    and not has_schema_privilege('authenticated', 'margot', 'USAGE')
    and not has_schema_privilege('service_role', 'margot', 'USAGE'), 'No client schema access');
  perform pg_temp.assert_true(not exists(select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'margot' and (p.prosecdef or has_function_privilege('anon', p.oid, 'EXECUTE'))), 'No definer or anonymous functions');
  perform pg_temp.assert_true(not exists(select 1 from pg_policies where schemaname = 'margot'), 'No client RLS policies');

  insert into margot.contacts(email, first_name) values ('alex@example.com', 'Alex') returning id into c;
  perform pg_temp.expect_error($q$insert into margot.contacts(email, first_name) values ('Alex@Example.com', 'Alex')$q$, 'check constraint');
  perform pg_temp.expect_error($q$insert into margot.contacts(email, first_name) values ('alex@example.com', 'Other')$q$, 'unique constraint');
  perform pg_temp.assert_true((select count(*) = 1 from margot.events where contact_id = c), 'Contact creation audited');

  insert into margot.send_intents(id, contact_id, kind, envelope, authorization_note)
  values (i, c, 'intro', envelope, 'Explicit test authorization');
  perform pg_temp.expect_error(format('insert into margot.send_intents(id, contact_id, kind, envelope, authorization_note) values (gen_random_uuid(), %L, ''intro'', %L, ''test'')', c, envelope), 'unique constraint');
  perform pg_temp.expect_error(format('update margot.send_intents set envelope = %L where id = %L', envelope || '{"subject":"Changed"}', i), 'immutable');
  perform pg_temp.expect_error(format('update margot.send_intents set state = ''sent'' where id = %L', i), 'confirmed Gmail evidence');
  perform pg_temp.expect_error(format('select margot.record_sent(%L, ''bad'', ''thread-a'', null, %L)', i, envelope), 'not-null constraint');
  perform pg_temp.assert_true((select state = 'prepared' from margot.send_intents where id = i)
    and not exists(select 1 from margot.messages where contact_id = c), 'Failed recording rolls back all state');

  m := margot.record_sent(i, 'sent-1', 'thread-a', t, envelope);
  replay := margot.record_sent(i, 'sent-1', 'thread-a', t, envelope);
  perform pg_temp.assert_true(m = replay and (select count(*) = 1 from margot.messages where contact_id = c), 'Confirmed send replay is idempotent');
  perform pg_temp.assert_true((select state = 'sent' from margot.send_intents where id = i)
    and (select status = 'active' from margot.contacts where id = c), 'Send resolves reservation and advances contact');
  perform pg_temp.expect_error(format('select margot.record_sent(%L, ''different-id'', ''thread-a'', %L, %L)', i, t, envelope), 'conflicts');
  perform pg_temp.expect_error(format('update margot.send_intents set state = ''prepared'' where id = %L', i), 'cannot be reopened');

  perform pg_temp.assert_true(not exists(select 1 from margot.due_followups(t + interval '119 hours 59 minutes', 5, 7)), 'Not due before boundary');
  perform pg_temp.assert_true(exists(select 1 from margot.due_followups(t + interval '120 hours', 5, 7) where contact_id = c and kind = 'follow_up_1'), 'Due at exact first boundary');
  perform pg_temp.assert_true(not exists(select 1 from margot.due_followups(t + interval '120 hours', 7, 7)), 'Cadence edits affect unsent due dates');
  update margot.contacts set next_action_at = now() + interval '1 day' where id = c;
  perform pg_temp.assert_true(not exists(select 1 from margot.due_followups(now(), 5, 7)), 'Snooze postpones eligibility');
  update margot.contacts set next_action_at = null where id = c;

  envelope := envelope || jsonb_build_object('gmail_thread_id', 'thread-a', 'in_reply_to_message_id', 'sent-1',
    'first_follow_up_days', 5, 'second_follow_up_days', 7);
  insert into margot.send_intents(id, contact_id, kind, envelope, authorization_note)
  values (i2, c, 'follow_up_1', envelope, 'Explicit follow-up authorization');
  update margot.send_intents set state = 'uncertain' where id = i2;
  perform pg_temp.assert_true(not exists(select 1 from margot.due_followups(now(), 5, 7)), 'Uncertain intent blocks duplicate follow-ups');
  perform margot.record_sent(i2, 'sent-2', 'thread-a', t + interval '120 hours', envelope);
  perform pg_temp.assert_true(not exists(select 1 from margot.due_followups(t + interval '287 hours', 5, 7)), 'Second delay starts at first follow-up send');
  perform pg_temp.assert_true(exists(select 1 from margot.due_followups(t + interval '288 hours', 5, 7) where kind = 'follow_up_2'), 'Second follow-up boundary');

  insert into margot.send_intents(id, contact_id, kind, envelope, authorization_note)
  values (i3, c, 'follow_up_2', envelope, 'Explicit second authorization');
  perform margot.record_sent(i3, 'sent-3', 'thread-a', t + interval '288 hours', envelope);
  perform pg_temp.assert_true(not exists(select 1 from margot.due_followups(now(), 5, 7)), 'No third standard follow-up');

  m := margot.record_inbound(c, 'maggie@example.com', 'reply-1', 'thread-a', now(), 'opt_out', inbound);
  replay := margot.record_inbound(c, 'maggie@example.com', 'reply-1', 'thread-a', now(), 'opt_out', inbound);
  perform pg_temp.assert_true(m = replay and (select status = 'do_not_contact' from margot.contacts where id = c), 'Opt-out records once and suppresses');
  perform pg_temp.expect_error(format('insert into margot.send_intents(id, contact_id, kind, envelope, authorization_note) values (gen_random_uuid(), %L, ''reply'', %L, ''test'')', c, envelope), 'suppressed');
  perform margot.record_inbound(c, 'maggie@example.com', 'reply-2', 'thread-a', now(), 'reply', inbound);
  perform pg_temp.assert_true((select status = 'do_not_contact' from margot.contacts where id = c), 'Later reply never clears opt-out');
  update margot.contacts set status = 'active' where id = c;
  perform pg_temp.assert_true(not exists(select 1 from margot.due_followups(now(), 5, 7)), 'Inbound history prevents re-enrollment');

  perform pg_temp.expect_error('update margot.messages set kind = ''imported''', 'History is retained');
  perform pg_temp.expect_error('delete from margot.messages', 'History is retained');
  perform pg_temp.expect_error('truncate margot.events', 'History is retained');
  perform pg_temp.expect_error(format('delete from margot.contacts where id = %L', c), 'History is retained');
  perform pg_temp.assert_true((select count(*) > 8 from margot.events where contact_id = c), 'Changes preserve audit trail');
end $$;

-- A reply/opt-out can arrive after preparation but before send recording.
do $$
declare c uuid; i uuid := gen_random_uuid(); e jsonb; inbound jsonb;
begin
  insert into margot.contacts(email, first_name) values ('racer@example.com', 'Race') returning id into c;
  e := jsonb_build_object('sender_email', 'maggie@example.com', 'recipient_email', 'racer@example.com',
    'subject', 'Hi', 'body_text', 'Body', 'template_path', 'templates/investor-intro.md', 'template_sha256', repeat('b', 64));
  insert into margot.send_intents(id, contact_id, kind, envelope, authorization_note) values (i, c, 'intro', e, 'test');
  inbound := jsonb_build_object('sender_email', 'racer@example.com', 'recipient_email', 'maggie@example.com', 'subject', '', 'body_text', 'Stop');
  perform margot.record_inbound(c, 'maggie@example.com', 'race-reply', 'race-thread', now(), 'opt_out', inbound);
  perform margot.record_sent(i, 'race-sent', 'race-thread', now(), e);
  perform pg_temp.assert_true((select status = 'do_not_contact' from margot.contacts where id = c)
    and (select state = 'sent' from margot.send_intents where id = i), 'Late send evidence preserved without undoing suppression');
end $$;

-- DST uses elapsed hours rather than local-calendar day arithmetic.
do $$
declare c uuid; e jsonb;
begin
  insert into margot.contacts(email, first_name, status) values ('dst@example.com', 'DST', 'active') returning id into c;
  e := '{"sender_email":"maggie@example.com","recipient_email":"dst@example.com","subject":"Test","body_text":"Test"}';
  insert into margot.messages(contact_id, direction, kind, mailbox_email, gmail_message_id, gmail_thread_id, occurred_at, envelope)
  values (c, 'outbound', 'intro', 'maggie@example.com', 'dst-message', 'dst-thread', '2026-03-06T12:00:00-05:00', e);
  perform pg_temp.assert_true(exists(select 1 from margot.due_followups('2026-03-11T13:00:00-04:00', 5, 7)
    where contact_id = c and due_at = '2026-03-11T13:00:00-04:00'::timestamptz), 'DST preserves exact elapsed-day cadence');
  perform margot.record_inbound(c, 'maggie@example.com', 'auto-reply', 'dst-thread', now(), 'auto_reply', e);
  perform pg_temp.assert_true((select status = 'needs_review' from margot.contacts where id = c)
    and not exists(select 1 from margot.due_followups(now(), 5, 7) where contact_id = c), 'Auto-replies pause standard outreach');
end $$;
rollback;
