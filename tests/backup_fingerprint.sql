-- Whole-row comparisons include every ID, timestamp, email body and audit record.
select 'contacts', count(*), md5(coalesce(jsonb_agg(to_jsonb(t) order by id)::text, '[]')) from margot.contacts t
union all select 'contact_statuses', count(*), md5(coalesce(jsonb_agg(to_jsonb(t) order by code)::text, '[]')) from margot.contact_statuses t
union all select 'lead_sources', count(*), md5(coalesce(jsonb_agg(to_jsonb(t) order by id)::text, '[]')) from margot.lead_sources t
union all select 'notes', count(*), md5(coalesce(jsonb_agg(to_jsonb(t) order by id)::text, '[]')) from margot.notes t
union all select 'commitments', count(*), md5(coalesce(jsonb_agg(to_jsonb(t) order by id)::text, '[]')) from margot.commitments t
union all select 'send_intents', count(*), md5(coalesce(jsonb_agg(to_jsonb(t) order by id)::text, '[]')) from margot.send_intents t
union all select 'messages', count(*), md5(coalesce(jsonb_agg(to_jsonb(t) order by id)::text, '[]')) from margot.messages t
union all select 'events', count(*), md5(coalesce(jsonb_agg(to_jsonb(t) order by id)::text, '[]')) from margot.events t
union all select 'events_sequence', last_value, is_called::text from margot.events_id_seq;
