# Backup and recovery

**Magnolia's Supabase project has not been created during repo preparation. These
are procedures for after her handoff and setup. Nothing here creates a connection,
exports data, or runs automatically.** She can say, "Margot, help me back up my
records and local settings using docs/RECOVERY.md." Margot should inspect the
selected project and explain the specific source and destination before running
the requested operation.

## What needs protecting

| What | Where it lives | How to preserve it |
| --- | --- | --- |
| Templates, skills, schema and shared instructions | Git repo | Commit reviewed changes; keep a remote copy or Git bundle |
| Maggie's local profile and connection-check notes | Ignored `config/local.json` and selected `.local/` files | Copy to private backup storage outside the repo |
| Contacts, sources, notes, promises, sends and history | Supabase's private `margot` schema | Full schema-and-data database archive |
| Original email and attachments | Gmail | Remain in Gmail; a Margot database export is not a mailbox backup |
| Plugin authentication | Account sign-ins | Reconnect normally; do not export tokens into the repo or backup instructions |

Take a backup before a schema change or recovery operation, and after important
sessions according to Maggie's chosen routine. GitHub does not back up Supabase or
ignored local files. Do not assume a Supabase plan has a usable hosted backup;
check the actual project's backup page. Supabase recommends off-site exports for
Free projects. [Supabase backup guidance](https://supabase.com/docs/guides/platform/backups)

## Preserve repo changes and local settings

First use [the update workflow](UPDATING.md) to review and commit intended code,
template and instruction changes. A bundle includes committed Git history, not
uncommitted changes, new untracked files, or ignored settings. Resolve that distinction
before relying on it as a backup.

Choose a private folder **outside this checkout** on protected storage, preferably
with an additional encrypted copy on a separate device or trusted backup service.
The example path is a placeholder to replace. These shell examples suit macOS/Linux;
on Windows use the equivalent private folder/copy operations and PostgreSQL tools.

```sh
umask 077
MARGOT_BACKUP_DIR='/absolute/private/path/margot-backup-YYYYMMDD-HHMM'
mkdir -p "$MARGOT_BACKUP_DIR"
git bundle create "$MARGOT_BACKUP_DIR/repo.bundle" --all
git rev-parse HEAD > "$MARGOT_BACKUP_DIR/repo-commit.txt"
git status --short > "$MARGOT_BACKUP_DIR/repo-status.txt"
if test -f config/local.json; then
  cp config/local.json "$MARGOT_BACKUP_DIR/local.json"
fi
```

Review any pending `.local/` send evidence or connection-check notes and copy the
specific files that need preservation. They can contain personal information. Never
commit them or whole database exports to Git. A copied connection check is historical
evidence, not proof that access still works after recovery.

## Export the database after setup

For this manual procedure install PostgreSQL client tools matching the server's
major version (at least 17 for this repo). Maggie does not need them for daily
plugin use. From the selected project's **Connect** panel obtain the direct or
session-pooler connection details and use its database-owner connection. Do not use
the transaction pooler for this procedure. This is the database password, separate
from plugin authentication. [Connection options](https://supabase.com/docs/guides/database/connecting-to-postgres)

Keep passwords out of commands, chat and Git. Set a password-free connection string
using the verified host, port, database and user from that panel. `-W` prompts in
Maggie's terminal; Margot must not ask her to paste the password into chat. Remove
unrelated inherited `PG*` settings before using these commands, especially passwords
and default connection overrides.

```sh
MARGOT_SOURCE='host=SOURCE_HOST port=SOURCE_PORT dbname=postgres user=SOURCE_USER sslmode=require'
psql -X -W --dbname="$MARGOT_SOURCE" -c 'select version(), current_user;'
```

Pause requested CRM writes and sending while taking the archive and inventory, so
the recorded row counts describe the same state. There is no background Margot
worker to stop. Record this private manifest in the backup folder:

- Source project reference, UTC backup time and PostgreSQL version.
- Repo commit, local migration filenames and hashes at the time of backup.
- The source project's actual applied migration versions/names, obtained from its
  migration listing. Map them to the local files; plugin-generated remote version
  numbers can differ from local filenames. Record any unapplied local migrations.
- Any known unresolved sends, discrepancies, or uncommitted repo work.

Use a full custom archive of the `margot` schema:

```sh
pg_dump -W --dbname="$MARGOT_SOURCE" --schema=margot --format=custom \
  --file="$MARGOT_BACKUP_DIR/margot.dump"
pg_restore --list "$MARGOT_BACKUP_DIR/margot.dump" > "$MARGOT_BACKUP_DIR/archive-contents.txt"
psql -X -W --dbname="$MARGOT_SOURCE" -v ON_ERROR_STOP=1 --csv \
  -f supabase/backup_inventory.sql > "$MARGOT_BACKUP_DIR/row-counts.csv"
shasum -a 256 "$MARGOT_BACKUP_DIR/margot.dump" > "$MARGOT_BACKUP_DIR/margot.dump.sha256"
shasum -a 256 supabase/migrations/*.sql > "$MARGOT_BACKUP_DIR/local-migrations.sha256"
```

Check that every command succeeded and the archive contains the eight tables,
data, functions, constraints, triggers and sequence. The dump has a consistent
database snapshot. The separate inventory requires the pause above for matching
counts. It includes the private schema, not Supabase Auth, Storage, unrelated schemas
or `supabase_migrations` metadata. If future migrations add dependencies outside
`margot`, expand and test this procedure before relying on it.
[PostgreSQL pg_dump](https://www.postgresql.org/docs/17/app-pgdump.html)

Keep archive, manifest, counts and matching code together. `.gitignore` excludes
common backup files as a second safeguard, not a substitute for private storage.

## Restore to an empty replacement project

Prefer a **new, explicitly selected replacement project** so the original remains
available for comparison. Provision the normal Supabase roles and use the target's
database-owner connection (`postgres`); the repo depends on Supabase's existing
`anon`, `authenticated` and `service_role` roles. Use the same PostgreSQL major
version for this tested recovery path. Do not point these commands at an arbitrary
connected project.

1. Review the archive source, checksum, backup time and matching repo commit. Only
   restore a trusted archive: it contains executable SQL.
2. Confirm the target project reference independently and verify that the `margot`
   schema is absent. **Do not apply the repo migrations first.** The archive already
   contains the schema, seeded statuses and data. If the schema exists, stop and
   choose an empty replacement; don't delete history to make room.
3. Restore with one transaction, retaining permissions and failing on errors:

```sh
MARGOT_TARGET='host=TARGET_HOST port=TARGET_PORT dbname=postgres user=TARGET_USER sslmode=require'
psql -X -W --dbname="$MARGOT_TARGET" -v ON_ERROR_STOP=1 \
  -c "select current_user, to_regnamespace('margot') as must_be_null;"
pg_restore -W --dbname="$MARGOT_TARGET" --no-owner --single-transaction \
  --exit-on-error "$MARGOT_BACKUP_DIR/margot.dump"
```

Proceed only when `must_be_null` is NULL and the selected target/owner are correct.
`--no-owner` makes the target owner own restored objects; ACLs remain in the archive.
Do not add `--no-acl`, `--clean`, `--data-only`, or disable history triggers.
A data-only import into an initialized Margot database can collide with seeded rows,
fire audit triggers and alter history. A full archive into an empty schema restores
data before triggers and constraints. [PostgreSQL pg_restore](https://www.postgresql.org/docs/17/app-pgrestore.html)

4. Compare row counts and inspect actual history and unresolved intents using the
   repo revision matching the archive:

```sh
psql -X -W --dbname="$MARGOT_TARGET" -v ON_ERROR_STOP=1 --csv \
  -f supabase/backup_inventory.sql > "$MARGOT_BACKUP_DIR/restored-row-counts.csv"
diff "$MARGOT_BACKUP_DIR/row-counts.csv" "$MARGOT_BACKUP_DIR/restored-row-counts.csv"
psql -X -W --dbname="$MARGOT_TARGET" -v ON_ERROR_STOP=1 -f supabase/verify.sql
```

The verification results must show RLS enabled, no client schema access/policies
and no publicly executable or security-definer functions. Check representative
notes, exact message bodies, IDs, dates and pending send states against the source
or saved evidence. Do not insert fictional fixtures into the restored project.

5. Reconcile migration tracking **before any future migration push**. The archive
   restores schema objects but not Supabase's migration ledger. Compare the manifest,
   local files and restored definitions to identify exactly which local migrations
   the archive already represents. After explicitly linking the CLI to this verified
   replacement project, inspect `supabase migration list` and `supabase migration
   repair --help`. Mark only those represented local versions applied:

```sh
supabase migration repair EXACT_REPRESENTED_VERSION --status applied
supabase migration list
```

This updates migration bookkeeping; it does not run their SQL. Do not mark every
current file applied blindly, replay the initial migration over the restored schema,
or reuse an unverified CLI link. If the mapping is uncertain, pause migration work
and resolve it from the backup manifest and schema definitions. Any migrations
newer than the backup remain pending and need their own review and local tests.

6. Restore `local.json` to ignored `config/local.json`, preserving any newer copy
   first. When using a replacement project, update its project reference in that
   profile and reconnect the plugin to the selected project. Recheck the Gmail
   identity, available actions, database access and template/profile values via
   [setup](SETUP.md). Do not restore authentication tokens.
7. **Reconcile Gmail before any new send.** Gmail may contain messages or replies
   newer than the restored snapshot, including sends whose intents were not yet in
   the backup. Search all relevant sent/received mail since the backup, import
   missing evidence, honor newer opt-outs, and reconcile every unresolved intent
   using [the outreach recovery procedure](OUTREACH.md#recovery). A restored
   reservation never authorizes resending. Report recovery complete only after
   this comparison and the remaining limitations are clear.

## Restore the repo or test the procedure

For a lost checkout, clone the private GitHub repo or use
`git clone /absolute/private/path/repo.bundle Margot-recovered`. A bundle clone's
origin points at that local bundle; inspect `git remote -v` and reconnect origin to
the verified `sitchhh/Margot` repository before fetching shared updates. Restore the
private profile separately as above. Preserve newer work before switching revisions.

`python3 scripts/test_database.py` rehearses this archive/restore approach entirely
in a disposable local PostgreSQL cluster. It checks exact contents of all eight
tables, sequence state, history protections, permissions and unresolved-send
reconciliation. It deletes that cluster afterward and never contacts Supabase.
