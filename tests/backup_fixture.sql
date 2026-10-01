-- Fictional data, only in the disposable database used by the test suite.
insert into margot.contact_statuses(code, label) values ('waiting_on_sarah', 'Waiting for Sarah');
do $$
declare p uuid; c uuid; pending uuid; n uuid; i uuid; e jsonb;
begin
  insert into margot.contacts(first_name, firm, status) values ('Backup Prospect', 'Example Firm', 'waiting_on_sarah') returning id into p;
  insert into margot.lead_sources(contact_id, description, introduced_by)
    values (p, 'Fictional introduction path', 'Sarah');
  insert into margot.notes(contact_id, body) values (p, 'Keep the prospect even without an email.');
  insert into margot.contacts(email, first_name) values ('sent.backup@example.com', 'Sent') returning id into c;
  insert into margot.commitments(contact_id, description, due_at)
    values (c, 'Maggie promised an overview', now() + interval '1 day');
  e := jsonb_build_object('sender_email', 'maggie@example.com', 'recipient_email', 'sent.backup@example.com',
    'subject', 'Backup test', 'body_text', E'Exact copy: O''Brien\nUnicode: café.',
    'template_path', 'templates/investor-intro.md', 'template_sha256', repeat('d', 64));
  i := gen_random_uuid();
  insert into margot.send_intents(id, contact_id, kind, envelope, authorization_note) values (i, c, 'intro', e, 'Fictional test instruction');
  perform margot.record_sent(i, 'backup-sent', 'backup-thread', now(), e);
  insert into margot.contacts(email, first_name) values ('pending.backup@example.com', 'Pending') returning id into pending;
  insert into margot.notes(contact_id, body) values (pending, 'Fictional offline meeting; awaiting Gmail evidence.') returning id into n;
  e := e || jsonb_build_object('recipient_email', 'pending.backup@example.com', 'offline_note_id', n);
  i := gen_random_uuid();
  insert into margot.send_intents(id, contact_id, kind, envelope, authorization_note) values (i, pending, 'offline_follow_up', e, 'Fictional test instruction');
  update margot.send_intents set state = 'uncertain' where id = i;
end $$;
