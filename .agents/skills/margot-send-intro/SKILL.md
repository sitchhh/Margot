---
name: margot-send-intro
description: Draft or send a first investor introduction for Maggie and Pink Fitness Club using the canonical intro template.
---

Read [the sending procedure](../../../docs/OUTREACH.md). A draft request stops after
presenting copy; a send request follows reservation, Gmail evidence, and bookkeeping.
Use templates/investor-intro.md and the local profile.
Read [brand voice](../margot-brand-voice/SKILL.md) for professional investor tone
and any requested customization; keep approved template copy intact otherwise.
Require actual first name, email, source, and truthful personalization. Review
full Supabase/Gmail history; existing correspondence uses
[conversation follow-up](../margot-conversation-follow-up/SKILL.md), not another first intro.

Render with `python3 scripts/margot.py render investor-intro --data .local/lead.json
--output .local/intro.json` (one command). The helper never sends. Inspect unresolved
fields and recipient before any send. Don't interpret template approval as permission
to contact someone. Honor clear existing send authorization without asking twice.
