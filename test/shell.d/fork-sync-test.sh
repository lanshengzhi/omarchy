#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

require_command git

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

UPSTREAM="$TMP/upstream.git"
ORIGIN="$TMP/origin.git"
SEED="$TMP/seed"
FORK="$TMP/fork"

# Build a fake world: bare upstream (branch quattro), bare fork origin, and a
# fork clone with a personal commit on local and the quattro mirror pushed.
setup_fixture() {
  rm -rf "$TMP"
  mkdir -p "$TMP"

  git init --bare -q "$UPSTREAM"
  git init --bare -q "$ORIGIN"
  git init -q "$SEED"
  git -C "$SEED" config user.email seed@example.com
  git -C "$SEED" config user.name seed
  echo base >"$SEED/file"
  git -C "$SEED" add file
  git -C "$SEED" commit -qm base
  git -C "$SEED" branch -M quattro
  git -C "$SEED" remote add origin "$UPSTREAM"
  git -C "$SEED" push -q origin quattro
  git -C "$UPSTREAM" symbolic-ref HEAD refs/heads/quattro

  git clone -q "$UPSTREAM" "$FORK"
  git -C "$FORK" config user.email fork@example.com
  git -C "$FORK" config user.name fork
  git -C "$FORK" branch -M local
  git -C "$FORK" remote rename origin upstream
  git -C "$FORK" remote add origin "$ORIGIN"
  git -C "$FORK" config branch.quattro.remote upstream
  git -C "$FORK" config branch.quattro.merge refs/heads/quattro
  echo personal >"$FORK/personal"
  git -C "$FORK" add personal
  git -C "$FORK" commit -qm personal
  git -C "$FORK" push -q origin local
  git -C "$FORK" push -q origin refs/remotes/upstream/quattro:refs/heads/quattro
}

# Add one commit to upstream's quattro.
upstream_commit() {
  echo "up-$1" >"$SEED/up"
  git -C "$SEED" add up
  git -C "$SEED" commit -qm "upstream $1"
  git -C "$SEED" push -q origin quattro
}

# Run the script inside the fork; capture stdout+stderr, leaving the exit code in $sync_code.
run_sync() {
  set +e
  sync_output=$(cd "$FORK" && bash "$ROOT/scripts/fork-sync.sh" 2>&1)
  sync_code=$?
  set -e
}

# --- clean sync: upstream moves, script rebases and pushes both refs ---
setup_fixture
upstream_commit 1
run_sync
[[ $sync_code -eq 0 ]] || fail "clean sync: expected exit 0, got $sync_code" "$sync_output"
[[ -z $(git -C "$FORK" log --oneline local..upstream/quattro) ]] || fail "clean sync: local is missing upstream commits"
[[ $(git -C "$ORIGIN" rev-parse quattro) == $(git -C "$UPSTREAM" rev-parse quattro) ]] || fail "clean sync: origin/quattro mirror is stale"
[[ $(git -C "$ORIGIN" rev-parse local) == $(git -C "$FORK" rev-parse local) ]] || fail "clean sync: origin/local is stale"
pass "clean sync: rebase, mirror push, local push"

# --- invariant: a commit on quattro must abort the sync ---
setup_fixture
git -C "$FORK" checkout -q -b quattro upstream/quattro
echo rogue >"$FORK/rogue"
git -C "$FORK" add rogue
git -C "$FORK" commit -qm rogue
git -C "$FORK" checkout -q local
run_sync
[[ $sync_code -eq 1 ]] || fail "invariant: expected exit 1, got $sync_code" "$sync_output"
[[ $sync_output == *"quattro"* ]] || fail "invariant: error does not mention quattro" "$sync_output"
[[ $(git -C "$FORK" rev-parse local) == $(git -C "$ORIGIN" rev-parse local) ]] || fail "invariant: local was modified"
pass "invariant: abort when quattro carries local commits"

# --- conflict: upstream and local touch the same file; rebase left in progress ---
setup_fixture
echo up >"$SEED/personal"
git -C "$SEED" add personal
git -C "$SEED" commit -qm "upstream personal change"
git -C "$SEED" push -q origin quattro
echo fork >"$FORK/personal"
git -C "$FORK" add personal
git -C "$FORK" commit -qm "fork personal change"
run_sync
[[ $sync_code -eq 2 ]] || fail "conflict: expected exit 2, got $sync_code" "$sync_output"
[[ -d "$FORK/.git/rebase-merge" || -d "$FORK/.git/rebase-apply" ]] || fail "conflict: rebase not left in progress"
git -C "$FORK" rebase --abort
pass "conflict: exit 2 with rebase left in progress"

# --- dirty tree: abort before touching anything ---
setup_fixture
echo dirty >"$FORK/dirty"
run_sync
[[ $sync_code -eq 1 ]] || fail "dirty tree: expected exit 1, got $sync_code" "$sync_output"
[[ $sync_output == *"not clean"* ]] || fail "dirty tree: error does not mention the dirty tree" "$sync_output"
pass "dirty tree: abort on uncommitted changes"

# --- tracking config: broken branch.quattro tracking is repaired ---
setup_fixture
git -C "$FORK" config --unset branch.quattro.remote
git -C "$FORK" config --unset branch.quattro.merge
upstream_commit 2
run_sync
[[ $sync_code -eq 0 ]] || fail "tracking: expected exit 0, got $sync_code" "$sync_output"
[[ $(git -C "$FORK" config branch.quattro.remote) == "upstream" ]] || fail "tracking: branch.quattro.remote not repaired"
[[ $(git -C "$FORK" config branch.quattro.merge) == "refs/heads/quattro" ]] || fail "tracking: branch.quattro.merge not repaired"
pass "tracking: broken branch.quattro tracking repaired"
