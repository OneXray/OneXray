# Domain Docs

This is a single-context repository.

## Before exploring

- Read `CONTEXT.md` at the repository root when it exists.
- Read ADRs under `docs/adr/` that affect the area being changed.

If these files do not exist, proceed silently. The `/domain-modeling` skill creates them only when terminology or decisions need recording.

## Layout

```text
/
├── CONTEXT.md
├── docs/adr/
└── lib/
```

## Vocabulary

Use domain terms as defined in `CONTEXT.md`. Avoid synonyms that its glossary explicitly rejects.

If a needed concept is absent, reconsider whether it is project terminology or note the gap for `/domain-modeling`.

## ADR conflicts

Explicitly flag output that contradicts an existing ADR rather than silently overriding it.
