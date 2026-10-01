-- Read-only inventory to save with an export while no Margot writes are in flight.
select 'contact_statuses' as table_name, count(*) as row_count from margot.contact_statuses
union all select 'contacts', count(*) from margot.contacts
union all select 'lead_sources', count(*) from margot.lead_sources
union all select 'notes', count(*) from margot.notes
union all select 'commitments', count(*) from margot.commitments
union all select 'send_intents', count(*) from margot.send_intents
union all select 'messages', count(*) from margot.messages
union all select 'events', count(*) from margot.events
order by table_name;
