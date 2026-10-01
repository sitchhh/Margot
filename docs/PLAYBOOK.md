# Investor outreach playbook

Use this guidance when Maggie asks Margot to find prospects, prepare a conversation,
or review what happened. Start from [the project brief](PROJECT.md) for the business
story and confirmed facts; its provisional funding estimate is not an approved ask.
The repo holds reusable instructions and business context; Supabase holds the
actual people, sources, notes, statuses, and outreach history. Gmail is Maggie's
mailbox. Work happens in her active Codex conversation, at her request.

## Find a reason to talk

- Start with Maggie's actual business plan and confirmed facts. Explain why a
  prospect might fit this business, what supports that view, and what is unknown.
  A title, apparent wealth, shared identity, or an "angel investor" label is not
  enough. Don't invent check sizes, interest, connections, or expansion plans.
- Work through her existing circles: former coworkers, fitness contacts, business
  owners, advisers, and people who have offered to help. Someone may be an investor,
  an introducer, both, or neither; record what Maggie knows rather than guessing.
- Look for relevant experience in comparable businesses. Company announcements,
  portfolio pages, and founders' own accounts can suggest useful conversations.
  Verify who actually funded a business; a funding announcement or filing alone
  does not identify every investor.
- For each candidate, distinguish a confirmed relationship, an offered introduction,
  and a possible connection that still needs checking. Record the source and date.
- Treat organization and event details as dated research. Recheck the organizer's
  own page for fit, eligibility, date, price, and contact route before recommending
  one. Use free public research; don't assume subscriptions or paid events.

Research or an introduction does not establish permission to pitch an investment.
Follow Maggie's confirmed outreach restrictions; resolve unclear permission before
sending. This playbook does not choose a fundraising route or supply legal terms.

## Make a useful, specific request

Use [the brand voice skill](../.agents/skills/margot-brand-voice/SKILL.md) when drafting
or revising copy. It provides professional investor and casual community profiles,
with sourced Kickstarter observations and examples of the same message in both
tones. Maggie's direction and the existing relationship guide the choice.

Match the request to the person's role and what Maggie actually wants:

| Conversation | Useful first request |
| --- | --- |
| Potential investor | A conversation about the business, with a supported reason it may be relevant |
| Introducer | An introduction to someone with relevant experience, plus a short forwardable description |
| Experienced operator or adviser | One concrete question they are well placed to answer |

Ask for advice when Maggie wants advice; don't disguise an investment pitch as an
advice call. Ask for introductions when appropriate, without a fixed quota. Respect
a decline. Make forwarding easy, thank the introducer, and close the loop with an
update when Maggie asks. Do not request confidential client lists.

For email, use a short, accurate subject, a personal reason for reaching out, a few
relevant facts, and one clear request. Use the approved canonical copy and the
[sending procedure](OUTREACH.md); these are writing principles, not new templates
or permission to send. Tailor emphasis to the person's stated interests and
experience. Do not assume motivations from demographics or change the business
story to match a prospect.

Use confirmed Kickstarter results or other traction as evidence, with their limits.
Backers are not automatically future members, investors, or consenting recipients;
past support alone does not prove the gym's future economics.

## Keep the next step concrete

After a conversation, capture what was asked, what concerned the person, any
materials or introductions promised, and the next action with a date if known.
"Send the requested financials on Friday" is useful; "interested" alone is not a
next action. Resolve relative dates against Maggie's timezone when recording them.

For "not now," preserve the person's actual reason and any agreed condition for
revisiting it. "Once the location is chosen" is a milestone, not a recurring email.
A review date means check whether the condition is met. Do not invent a date,
promise, or invitation to follow up, or reinterpret a refusal as an opportunity.

A due date, saved task, status change, or completed milestone never sends an email.
Opening the repo also does not start a review. Maggie asks for the review or task;
she must explicitly request a send in the active conversation for a particular
recipient and message. Apply existing authorization without asking twice.

## Record results with the current CRM

Use [the database guide](DATABASE.md) and the selected Supabase project for saves.
Read existing records first. Save within Maggie's request, verify the write, and
report what was saved. A brainstorming or research request alone is not an instruction
to add everyone mentioned. A clear request to save does not need another approval.

| Information | Current place |
| --- | --- |
| Identity and Maggie's chosen status | `margot.contacts`; preserve suppression and existing history |
| How the person was found, supporting URL, introducer | `margot.lead_sources`; append distinct evidence |
| Role, relationship in Maggie's words, fit, unknowns, meeting summary, objections, milestone condition | Append a dated `margot.notes` entry, distinguishing evidence from interpretation |
| Next action and review date | `contacts.next_action` and `next_action_at` |
| A promised task, who will do it, and its due date | `margot.commitments.description` and `due_at` |
| Exact sent or received mail | `margot.messages`, using the outreach procedure and Gmail evidence |

The current `commitments` table is a task tracker. It has no investment amount,
currency, soft/firm classification, or receipt ledger. Record an investment
discussion's exact amount, currency, conditions, and tentative/confirmed wording in
a note when provided. Never treat completing a task or setting status to `committed`
as evidence that funds arrived. Do not calculate money raised from these fields.

Contacts currently require an email and first name; notes and sources belong to a
contact. Never fabricate an email, contact, or table to save an incomplete hunch.
Explain the missing information and leave the draft in the conversation, explicitly
not saved to the CRM. Apply the same distinction while Supabase is unconnected.
Do not create a local prospect list or personal notes file as a substitute.

## Learn during reviews Maggie requests

Use the daily-review skill for existing queues. For a broader pipeline review,
look for active contacts with no next action, overdue promises, unresolved questions,
and milestone conditions worth checking. Preserve opt-outs and paused statuses.

Compare sources and approaches by the relevant contacts, conversations, and meetings
they produced, as supported by recorded evidence. Separate a source from an
introducer and an activity count from an outcome. State missing data rather than
inventing conversion rates or financial totals. Record experience with the relevant
contact; generalize only non-identifying, reusable lessons into repo guidance when
Maggie requests that change.
