# Domain Docs

This repository uses a single-context layout: domain terminology lives in
`CONTEXT.md` at the repository root, and architecture decisions live in
`docs/adr/`.

## Reading rules

- Before exploring the codebase, read the root `CONTEXT.md` when it exists.
- Before changing an implementation, read ADRs under `docs/adr/` that affect
  the area being changed.
- If these files do not exist, proceed silently without creating setup
  placeholders. The `/domain-modeling` skill creates them when terminology
  or decisions actually need recording.

## Vocabulary and decisions

- Use terms defined in `CONTEXT.md`; avoid synonyms the glossary explicitly
  rejects.
- If a needed concept is missing, first check whether it is existing project
  terminology. Leave genuine gaps for `/domain-modeling` to resolve.
- When a proposal contradicts an existing ADR, explicitly identify the
  conflict and the reasoning instead of silently overriding the decision.
