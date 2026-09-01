# Issue tracker: GitHub

Issues and PRDs for this repo live in GitHub Issues at `lanshengzhi/omarchy`. Use the `gh` CLI with `--repo lanshengzhi/omarchy` for all operations.

## Conventions

- **Create an issue**: `gh issue create --repo lanshengzhi/omarchy --title "..." --body "..."`. Use a heredoc for multi-line bodies.
- **Read an issue**: `gh issue view <number> --repo lanshengzhi/omarchy --comments`, filtering comments by `jq` and also fetching labels.
- **List issues**: `gh issue list --repo lanshengzhi/omarchy --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'` with appropriate `--label` and `--state` filters.
- **Comment on an issue**: `gh issue comment <number> --repo lanshengzhi/omarchy --body "..."`
- **Apply / remove labels**: `gh issue edit <number> --repo lanshengzhi/omarchy --add-label "..."` / `--remove-label "..."`
- **Close**: `gh issue close <number> --repo lanshengzhi/omarchy --comment "..."`

Do not infer the issue repository from the current Git remote. The configured issue repository is always `lanshengzhi/omarchy`.

## Pull requests as a triage surface

**PRs as a request surface: no.**

When set to `yes`, PRs run through the same labels and states as issues, using the `gh pr` equivalents.

GitHub shares one number space across issues and PRs, so a bare `#42` may be either. Resolve it with `gh pr view 42 --repo lanshengzhi/omarchy` and fall back to `gh issue view 42 --repo lanshengzhi/omarchy`.

## When a skill says "publish to the issue tracker"

Create an issue in `lanshengzhi/omarchy`.

## When a skill says "fetch the relevant ticket"

Run `gh issue view <number> --repo lanshengzhi/omarchy --comments`.

## Wayfinding operations

Used by `/wayfinder`. The **map** is a single issue with **child** issues as tickets.

- **Map**: a single issue labelled `wayfinder:map`, holding the Notes / Decisions-so-far / Fog body.
- **Child ticket**: an issue linked to the map as a GitHub sub-issue. Where sub-issues aren't enabled, add the child to a task list in the map body and put `Part of #<map>` at the top of the child body.
- **Blocking**: use GitHub's native issue dependencies. Where dependencies aren't available, fall back to a `Blocked by: #<n>, #<n>` line.
- **Frontier query**: list the map's open children, dropping tickets with open blockers or an assignee; first in map order wins.
- **Claim**: `gh issue edit <n> --repo lanshengzhi/omarchy --add-assignee @me`
- **Resolve**: comment with the answer, close the issue, then append a context pointer to the map's Decisions-so-far.
