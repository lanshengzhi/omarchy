---
name: fork-sync
description: >
  Sync this Omarchy fork with upstream. Use when asked to fork-sync, /fork-sync,
  rebase local onto upstream/quattro, refresh the quattro mirror, or push the
  fork's local and quattro branches after upstream moved.
---

# Fork Sync

Run the repo script. Do not hand-roll fetch/rebase/push around it.

## Model

- `upstream` → `basecamp/omarchy` (fetch only)
- `origin` → this fork
- `quattro` — pure mirror of `upstream/quattro`; never commit onto it
- `local` — personal work on that tip; only branch that receives commits
- **one-commit stack** — `local` must sit exactly one personal commit above `upstream/quattro` (`git rev-list --count upstream/quattro..local` → `1`)

## Steps

1. Confirm the shell is inside this repository (or `cd` to `$OMARCHY_PATH` / the checkout root).
2. Run exactly:

```bash
bash scripts/fork-sync.sh
```

3. Branch on the exit code:

| Code | Meaning | What to do |
|------|---------|------------|
| `0` | Synced | Report the script's summary lines, then enforce the one-commit stack (next step). |
| `1` | Hard stop | Report the script's reason. Stop. Do not invent a bypass. |
| `2` | Rebase conflict in progress | Resolve with the `resolving-merge-conflicts` skill (never `--abort`). When the rebase finishes, re-run `bash scripts/fork-sync.sh` so the mirror and `local` pushes complete. |

4. After a successful sync, if `local` is not exactly one commit above `upstream/quattro`, squash it:

```bash
git reset --soft upstream/quattro
git commit -m "$(git log -1 --format=%B HEAD@{1})"
git push --force-with-lease origin local
```

Keep a single coherent commit message for the whole personal stack. Do not leave multiple personal commits on `local`.

## Guards

- Personal changes stay on `local` only.
- Keep the one-commit stack: never finish a sync (or a personal change set) with `local` more than one commit ahead of `upstream/quattro`.
- Do not commit to `quattro`, reset it ad hoc, or replace the script with a custom rebase/push sequence unless the user asked to change the script itself.
- Dirty tree, wrong branch, polluted `quattro`, fetch/push failure → surface the script error and stop.
