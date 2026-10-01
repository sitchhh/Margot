---
name: margot-add-lead
description: Add or update an investor lead for Pink Fitness Club, preserving contact identity, sources, and outreach history.
---

Use [database recipes](../../../docs/DATABASE.md) against the configured project.
Collect an email, first name, and source; store known firm/name/introducer/URL without
guessing missing facts. Trim/lowercase email; don't strip dots/plus tags or merge by name.
Search for the exact email and inspect any existing history/status. Reuse existing
contacts and append a new source/note; don't reset their status or overwrite identity
details without Maggie's requested correction. Insert a new contact and source
atomically, and read back the result before saying it was saved. For larger imports,
identify duplicates and unresolved identities before writing; never enroll or send
merely because a lead was added.

If Supabase is unavailable, collect the missing details in the conversation and
explain that the lead is not saved. Do not establish a local shadow CRM.
