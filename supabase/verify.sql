-- Read-only diagnostics; execute on the explicitly selected project.
select current_user, current_database(), version();
select schemaname, tablename, rowsecurity from pg_tables
where schemaname = 'margot' order by tablename;
select role_name, has_schema_privilege(role_name, 'margot', 'USAGE') as schema_access
from (values ('anon'), ('authenticated'), ('service_role')) roles(role_name);
select p.proname, p.prosecdef as security_definer
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'margot' order by p.proname;
select * from pg_policies where schemaname = 'margot';
select count(*) as contacts from margot.contacts;
select count(*) as messages from margot.messages;
