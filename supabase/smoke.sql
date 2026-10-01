-- Run as one operation. All fictional data is rolled back.
begin;
insert into margot.contacts(email, first_name)
values ('margot-setup-' || gen_random_uuid()::text || '@example.invalid', 'Setup check')
returning id, email, status;
select count(*) as status_count from margot.contact_statuses;
rollback;
