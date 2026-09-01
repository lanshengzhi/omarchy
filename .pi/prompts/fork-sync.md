---
description: Sync this fork with upstream — rebase local, update the quattro mirror, push both
---

Sync this fork with upstream. From the repository root, run:

```bash
bash scripts/fork-sync.sh
```

This repo is a fork: `origin` is `lanshengzhi/omarchy`, `upstream` is `basecamp/omarchy` (push disabled). Two branches matter:

- **quattro** — a pure mirror of `upstream/quattro`. Never commit to it directly; it only ever moves by fast-forward. Personal changes live on `local` only.
- **local** — personal changes, stacked on the latest `upstream/quattro`.

The script enforces this workflow: preconditions (on `local`, clean tree, quattro mirror invariant, tracking config), fetch upstream, rebase, `--force-with-lease` pushes of `origin/quattro` and `origin/local`, then verification and a summary.

Exit codes:

- `0` — synced. Report the summary.
- `1` — error. Report the reason; do not improvise past it.
- `2` — rebase conflict in progress. Invoke the `resolving-merge-conflicts` skill and follow it (it never uses `--abort`). When the rebase is finished, re-run `bash scripts/fork-sync.sh` to complete the mirror and local pushes.
