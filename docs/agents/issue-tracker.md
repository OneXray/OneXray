# Issue tracker: GitHub

Issues and specs live in GitHub Issues for `OneXray/OneXray`.

Use the `gh` CLI. Because this clone's `origin` uses `yiguo.dev`,
include `--repo OneXray/OneXray` in every `gh issue` and `gh pr` command.
For `gh api`, use explicit `repos/OneXray/OneXray/...` endpoints.

## Conventions

- Use English for issue and PR titles, descriptions, and GitHub comments.
- Keep PR titles, descriptions, and comments self-contained. Do not mention
  or link to another repository's PR, including companion, dependency, or
  merge-order references. Describe required interface or build behavior directly.
- Use [triage-labels.md](triage-labels.md) for canonical triage roles.
- Use a quoted heredoc for multiline bodies to preserve literal shell characters.

## Reviews and authorization

- For PR reviews, resolve the actual remote base/head and record the commit IDs
  without switching the checkout. Unpushed local changes are not the PR diff.
- For local reviews, use the user's requested fixed point. Follow `code-review`
  for separate Standards and Spec findings with severity, location, impact and evidence.
- Analysis and review are read-only unless the user also authorizes changes or
  publication. They do not authorize code edits, GitHub comments, label changes,
  closure or pushes. Check actual labels before an authorized label operation.

## Issue operations

- Publish a ticket: `gh issue create --repo OneXray/OneXray --title "..." --body "..."`
- Fetch a ticket: `gh issue view <number> --repo OneXray/OneXray --comments`; include its labels when assessing state.
- List tickets: `gh issue list --repo OneXray/OneXray --state open --json number,title,body,labels,comments`
- Comment: `gh issue comment <number> --repo OneXray/OneXray --body "..."`
- Add or remove labels: `gh issue edit <number> --repo OneXray/OneXray --add-label "..."` or `--remove-label "..."`
- Close: `gh issue close <number> --repo OneXray/OneXray --comment "..."`

GitHub shares one number space across issues and PRs. Resolve an ambiguous
number with `gh pr view <number> --repo OneXray/OneXray`, falling back to
`gh issue view <number> --repo OneXray/OneXray`.

## Pull requests as a triage surface

**PRs as a request surface: no.**

## Wayfinding operations

Used by `/wayfinder`. The map is one issue with child issues as tickets.

- Map: label it `wayfinder:map`.
- Child ticket: link it as a GitHub sub-issue. If unavailable, add it to the
  map's task list and put `Part of #<map>` at the top of the child body.
- Child labels: `wayfinder:research`, `wayfinder:prototype`,
  `wayfinder:grilling`, or `wayfinder:task`.
- Blocking: use GitHub issue dependencies. If unavailable, put
  `Blocked by: #<n>` at the top of the child body.
- Frontier: choose the first open, unassigned child in map order without
  an open blocker.
- Claim: `gh issue edit <number> --repo OneXray/OneXray --add-assignee @me`
- Resolve: comment with the answer, close the child, then add a context
  pointer to the map's Decisions-so-far.
