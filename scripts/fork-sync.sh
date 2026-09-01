#!/bin/bash

# Sync this fork with upstream: rebase local onto upstream/quattro, update the
# origin/quattro mirror, push local. Exit codes:
#   0 - sync complete
#   1 - error (precondition failed, fetch/push failure); reason printed
#   2 - rebase conflict; rebase left in progress for resolving-merge-conflicts

set -euo pipefail

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  printf 'fork-sync: not inside a git repository\n' >&2
  exit 1
}
cd "$ROOT"

fail() {
  printf 'fork-sync: %s\n' "$*" >&2
  exit 1
}

# --- preconditions ---
branch=$(git branch --show-current)
[[ $branch == "local" ]] || fail "must be on the local branch (currently: ${branch:-detached HEAD})"
[[ -z $(git status --porcelain) ]] || fail "working tree is not clean; commit or stash first"
git remote get-url upstream >/dev/null 2>&1 || fail "no upstream remote configured"

# --- tracking config: quattro must track upstream/quattro ---
if [[ $(git config branch.quattro.remote) != "upstream" || $(git config branch.quattro.merge) != "refs/heads/quattro" ]]; then
  git config branch.quattro.remote upstream
  git config branch.quattro.merge refs/heads/quattro
  printf 'fork-sync: fixed branch.quattro tracking to upstream/quattro\n'
fi

# --- fetch upstream ---
git fetch upstream || fail "fetch upstream failed"
git rev-parse -q --verify upstream/quattro >/dev/null || fail "upstream has no quattro branch"

# --- invariant: quattro must be a pure mirror (rule 1) ---
if [[ -n $(git log --oneline upstream/quattro..quattro) ]]; then
  printf 'fork-sync: quattro has commits upstream does not; move them to local and reset quattro (rule 1)\n' >&2
  git log --oneline upstream/quattro..quattro >&2
  exit 1
fi

# --- rebase local onto upstream ---
if ! git rebase upstream/quattro; then
  if [[ -d .git/rebase-merge || -d .git/rebase-apply ]]; then
    printf 'fork-sync: rebase conflict; resolve it (resolving-merge-conflicts skill) then re-run fork-sync\n' >&2
    exit 2
  fi
  fail "rebase failed"
fi

# --- push mirror and local ---
git push --force-with-lease origin refs/remotes/upstream/quattro:refs/heads/quattro || fail "push of quattro mirror failed"
git push --force-with-lease origin local || fail "push of local failed"

# --- verify and summarize ---
[[ -z $(git log --oneline local..upstream/quattro) ]] || fail "post-sync verification failed: local is missing upstream commits"

printf 'fork-sync: local synced to upstream/quattro (%s), %s personal commit(s) on top\n' \
  "$(git rev-parse --short upstream/quattro)" \
  "$(git log --oneline upstream/quattro..local | wc -l | tr -d ' ')"
printf 'fork-sync: origin/quattro and origin/local pushed\n'
