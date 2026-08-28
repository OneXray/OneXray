# Issue tracker: GitHub

Issues and specs live in GitHub Issues for `OneXray/OneXray`. Use the `gh` CLI for all operations.

Because this clone's `origin` points to `yiguo.dev`, include `--repo OneXray/OneXray` in every `gh issue` and `gh pr` command.

## Conventions

- **Create an issue**: `gh issue create --repo OneXray/OneXray --title "..." --body "..."`
- **Read an issue**: `gh issue view <number> --repo OneXray/OneXray --comments`
- **List issues**: `gh issue list --repo OneXray/OneXray --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'`
- **Comment**: `gh issue comment <number> --repo OneXray/OneXray --body "..."`
- **Apply or remove labels**: `gh issue edit <number> --repo OneXray/OneXray --add-label "..."` or `--remove-label "..."`
- **Close**: `gh issue close <number> --repo OneXray/OneXray --comment "..."`

Use a heredoc for multiline bodies.

## Pull requests as a triage surface

**PRs as a request surface: no.** _(Set to `yes` if this repo treats external PRs as feature requests; `/triage` reads this flag.)_

When set to `yes`, PRs use the same labels and states as issues:

- **Read**: `gh pr view <number> --repo OneXray/OneXray --comments` and `gh pr diff <number> --repo OneXray/OneXray`
- **List external PRs**: `gh pr list --repo OneXray/OneXray --state open --json number,title,body,labels,author,authorAssociation,comments`, keeping only `CONTRIBUTOR`, `FIRST_TIME_CONTRIBUTOR`, or `NONE`
- **Comment, label, or close**: use the corresponding `gh pr` command with `--repo OneXray/OneXray`

GitHub shares one number space across issues and PRs. Resolve a bare `#42` with `gh pr view 42 --repo OneXray/OneXray`, falling back to `gh issue view 42 --repo OneXray/OneXray`.

## Skill operations

- **Publish to the issue tracker**: create a GitHub issue.
- **Fetch the relevant ticket**: run `gh issue view <number> --repo OneXray/OneXray --comments`.

## Wayfinding operations

Used by `/wayfinder`. The map is one issue with child issues as tickets.

- **Map**: label it `wayfinder:map`.
- **Child ticket**: link it as a GitHub sub-issue. If unavailable, add it to the map's task list and put `Part of #<map>` at the top of the child body.
- **Child labels**: `wayfinder:research`, `wayfinder:prototype`, `wayfinder:grilling`, or `wayfinder:task`.
- **Blocking**: use GitHub issue dependencies. If unavailable, put `Blocked by: #<n>` at the top of the child body.
- **Frontier**: choose the first open, unassigned child without an open blocker.
- **Claim**: `gh issue edit <number> --repo OneXray/OneXray --add-assignee @me`
- **Resolve**: comment with the answer, close the child, then add a context pointer to the map's Decisions-so-far.
