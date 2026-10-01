-- Run after restoring the fictional archive to a new empty test database.
do $$
declare c uuid; prior_event bigint; i margot.send_intents;
begin
  if exists(select 1 from pg_tables where schemaname = 'margot' and not rowsecurity) or
     has_schema_privilege('anon', 'margot', 'USAGE') or
     has_schema_privilege('authenticated', 'margot', 'USAGE') or
     has_schema_privilege('service_role', 'margot', 'USAGE') or
     exists(select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'margot' and (p.prosecdef or has_function_privilege('anon', p.oid, 'EXECUTE'))) then
    raise exception 'Restore lost database access restrictions';
  end if;
  select id into strict c from margot.contacts where email is null;
  select max(id) into prior_event from margot.events;
  insert into margot.notes(contact_id, body) values (c, 'Restore verified');
  if not exists(select 1 from margot.events where id > prior_event and contact_id = c) then
    raise exception 'Audit trigger or identity sequence not restored';
  end if;
  begin
    delete from margot.messages;
    raise exception 'Restored history was deletable';
  exception when raise_exception then
    if position('History is retained' in sqlerrm) = 0 then raise; end if;
  end;
  select * into strict i from margot.send_intents where state = 'uncertain';
  perform margot.record_sent(i.id, 'reconciled-after-restore', 'reconciled-thread', now(), i.envelope);
  if (select state from margot.send_intents where id = i.id) <> 'sent' then
    raise exception 'Restored unresolved send cannot be reconciled';
  end if;
  raise notice 'PASS: restored history, sequence, permissions and unresolved-send reconciliation';
end $$;
