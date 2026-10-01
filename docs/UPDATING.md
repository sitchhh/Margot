# Save changes and receive updates

Maggie can say, "Margot, save my template changes and bring in the latest repo
updates without losing my edits." Margot should inspect the checkout first, preserve
her work, show meaningful conflicts, and run the checks appropriate to the result.
This works before Supabase exists; changing Git never applies a database migration.

## Save Maggie's edits

Use the current checkout and branch; don't assume every change belongs to this
task. Inspect both tracked changes and new files:

```sh
git status --short
git branch --show-current
git diff
git diff --cached
```

Check that no real contact data, rendered emails, credentials or exports are being
included. `config/local.json` and `.local/` are intentionally ignored and won't be
saved by a commit. Preserve them privately using [backup and recovery](RECOVERY.md),
especially before changing machines or doing substantial updates.

Review each changed template/instruction and preview templates with fictional
examples. For helper changes run `python3 -m unittest discover -s tests -v`; for
schema changes also run `python3 scripts/test_database.py` (requires local PostgreSQL
17+). New migrations stay unapplied until Maggie requests setup or a live change
against her selected project.

Stage **only named files** belonging to the intended change, inspect the staged
diff, then commit. For example, after editing the first follow-up:

```sh
git add -- templates/follow-up-1.md
git diff --cached
git commit -m "Make the first follow-up warmer"
```

Use the actual changed paths and an accurate commit message. Review/stage newly
created files as well. Do not use a blanket `git add .` that might scoop up unrelated
work. A local commit is saved on this machine; a private remote push or Git bundle
provides another copy. When Maggie requests sharing or remote backup, verify the
remote and push her chosen branch. Never force-push over someone else's work.

## Bring in shared updates

Start with committed work and a clean tracked working tree. Preserve ignored local
settings separately; stop if Git reports an untracked file that would be overwritten.
Don't delete it to make the update proceed. Verify `git remote -v` points at the
intended `sitchhh/Margot` repo, then fetch:

```sh
git fetch origin
git log --oneline --left-right HEAD...origin/main
```

If on `main` with no local commits diverging from `origin/main`, a fast-forward
preserves history:

```sh
git merge --ff-only origin/main
```

If it refuses, the work has diverged; use the preservation path below instead of
resetting local files. `git pull --ff-only` combines fetch and this check for a
branch already tracking the correct remote. [Git pull behavior](https://git-scm.com/docs/git-pull)

## Combine updates with Maggie's own commits

Create a uniquely named work branch at her committed changes (substitute the date
and a distinct name), plus a safety branch at the same commit. If already on a
deliberate work branch, keep it and create only the safety branch.

```sh
git switch -c maggie/template-edits-YYYYMMDD
git branch backup/before-update-YYYYMMDD
git fetch origin
git merge origin/main
```

This brings shared updates into her branch while retaining her edits and their
history. Continue using that branch until she chooses how to share/integrate it;
there is no need to overwrite `main` to use Margot locally.

If there are conflicts, read both versions and combine their intended behavior.
Show Maggie any real wording or behavior choice that needs her preference; don't
blindly choose all of one side. After resolving each file, stage the named files,
review the diff and finish with `git commit`. Re-run the affected previews/tests.
If the merge cannot be resolved yet, `git merge --abort` returns to the pre-merge
state when started from the clean committed tree above. Keep the safety branch.
Never use `reset --hard`, `clean -fd`, or discard local changes as an update shortcut.
[Git merge and abort](https://git-scm.com/docs/git-merge)

Once the combined branch is ready and Maggie requests sharing it, push that branch
and open a pull request for review. For example, while on the branch created above:

```sh
git push -u origin maggie/template-edits-YYYYMMDD
```

## Check the result

- Confirm Maggie's intended edits remain and relevant previews/tests pass.
- Run `python3 scripts/margot.py doctor` to inspect local configuration; incomplete
  setup correctly reports missing values and does not contact live services.
- Compare `config/local.example.json` with her ignored profile. Add newly required
  settings without overwriting her identity, facts or chosen project reference.
- Review new migration files. A repo update does not migrate Supabase, change
  template approval, authorize an email or start background work. Follow
  [database evolution](DATABASE.md#schema-changes) when Maggie requests applying
  the change, after a backup and verification of the selected project.

Keep applied migration files unchanged. After a database restore, reconcile the
migration ledger with [the recovery guide](RECOVERY.md) before applying later files.
