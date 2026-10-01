---
name: margot-add-lead
description: Add or update an investor lead for Pink Fitness Club, preserving contact identity, sources, and outreach history.
---

Use [database recipes](../../../docs/DATABASE.md) against the configured project.
Collect a first name and enough context to identify the person, plus a source.
An email is optional: "Jane at this firm, possible introduction through Sarah" can
be saved with email NULL. Store known firm/name/introducer/URL and distinguish a
possible introduction from an offered one. Never invent an address or other facts.

Use an existing contact ID when known. If an email is supplied, trim/lowercase it
and search for that exact address; don't strip dots or plus tags. Also inspect
possible existing email-less prospects using name, firm, source and Maggie's context.
Name matches are candidates for review, never proof that two people are the same.
Resolve material ambiguity before associating history or creating a duplicate.
Reuse the selected contact and append sources/notes without resetting its status.

Generate contact/source UUIDs once, insert atomically, and reuse those UUIDs after
an ambiguous result; read back and compare before saying the save succeeded.
Later, add a verified email to the same contact ID, preserving all notes and sources.
If it belongs to another record, stop and resolve the identity collision with Maggie;
don't overwrite, silently merge, or move history. Reconcile pending sends before
changing a reserved email. Email-less prospects cannot prepare a send and are
excluded from email follow-up candidates.

For imports, identify duplicates and unresolved identities before writing. Saving
a lead never enrolls them in outreach or authorizes a message.

If Supabase is unavailable, collect the missing details in the conversation and
explain that the lead is not saved. Do not establish a local shadow CRM.
