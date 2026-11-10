# Change Log and Documentation

In an AI-assisted project, documentation is **executable context**: the next
session (human or AI) starts from it. Treat stale docs as bugs.

## The document set

| Document | Purpose | Update when |
|---|---|---|
| `CLAUDE.md` / `AGENTS.md` | project rules, layout, build commands, invariants | architecture, build or workflow changes |
| Protocol doc | wire format, commands, ACK fields, timing | any protocol change |
| `README.md` (firmware) | operator-facing behavior, HIL results, gotchas | behavior or procedure changes |
| Change log (inside `CLAUDE.md`) | dated, append-only history | every change |

Keep a single source of truth for each fact and link instead of duplicating.

## Change-log bullet format

Append one bullet per change, newest near the related topic or at the end:

```markdown
- <Short title> <YYYY-MM-DD> (`files/dirs`): 用户要求 / 现象 / 原因.
  <What changed, at the level of behavior and interfaces.>
  <Test evidence: host tests N/N, build size, PC tests N/N.>
  <HIL evidence with numbers: frames, timing, SWD reads.>
  <Known limits or follow-ups.>
```

Guidelines:

- Use **absolute dates** (convert "today"/"last week").
- Name the files or modules touched.
- State the *why*, not just the *what*. "42 ms → 1.2 s" beats "improved".
- Record test counts and HIL measurements; these are the evidence trail.
- Mention what was **not** verified.
- Never rewrite old bullets to look right; append corrections.

## Writing for agents

- Put hard constraints at the top: active tree, frozen trees, forbidden
  operations, credential rules.
- Use explicit commands that can be copy-pasted.
- List invariants (pin ownership, init order, protocol epochs) as short rules.
- Mark legacy/stale documents clearly so an agent doesn't follow them.
- Prefer tables for interfaces and checklists for procedures.
- Keep the file navigable: headings, short paragraphs, no walls of prose.

## Protocol documentation checklist

- Every field: offset, type, endianness, units, valid range.
- Every command: request fields, ACK fields, persistence, error codes.
- Timing: cadence, timeouts, retry/backoff, keep-alive.
- Versioning: record versions, migration behavior, invalidation rules.
- Examples: one real captured frame per message type.

## PR / commit notes

- Subject: what changed and why, in one line.
- Body: evidence (tests, build size, HIL), risks, rollback.
- Never include credentials or customer identifiers in commit messages.
- When publishing, sanitize: internal hosts, project IDs, customer names,
  proprietary protocol details, screenshots with live data.
