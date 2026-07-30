---
name: batch-grilling
description: >-
  Post-audit (and other multi-decision) interviews in frontier rounds: ask every
  currently answerable question at once, wait, recompute. Use after RepoLens
  run_complete, when Plan mode has many independent findings decisions, or when
  the user says batch-grill / batch-grill-me. Prefer over one-at-a-time grilling
  when more than ~3 independent decisions are open.
---

Interview the user until shared understanding — but work a **decision tree in rounds**, not one question per turn.

Adapted from [mattpocock/skills `batch-grill-me`](https://github.com/mattpocock/skills) for **RepoLens post-audit plans**: many findings produce many independent decisions (accept vs defer, fix order, security trade-offs). Asking them one-by-one burns the chat; a frontier round fits AskQuestion / Plan mode.

## When to use

- After `REPOLENS_CTL` `kind: run_complete` (default for audit wrap-up)
- Plan mode with **more than ~3** independent open decisions
- User says `batch-grill` / `batch-grill-me`

Use one-at-a-time `grilling` instead for a single irreversible design fork (API shape, new abstraction) before coding outside an audit.

## Frontier rounds

1. Map findings and open points as a **decision tree**. Facts (paths, severity, what the code does) come from `files.findings_dir` / `files.summary` / the repo — look them up, never ask.
2. The **frontier** is every decision whose prerequisites are already settled — questions you can ask *now* without guessing at answers you have not heard.
3. Ask the **whole frontier in one round** (AskQuestion / numbered list). Wait for answers before the next round.
4. Answers reshuffle the tree: settled nodes unlock dependents. Recompute the frontier; ask the next round.
5. A question that depends on another still open **this** round belongs to a *later* round — do not ask it yet.
6. Done when the frontier is empty: every branch visited, nothing silently assumed. Confirm shared understanding, then implement.

Do **not** start coding mid-round.

## Question shape (audit)

- Group by theme when the frontier is large: Severity / Security trade-off / Scope / False-positive / Fix order / Optional polish.
- Each item: one idea, short stem, 2–4 options.
- **Option A / 1 is always the Best-Practice recommendation** — the usual, defensible route, not necessarily the theoretically best. Label it `(Empfohlen)`.
- Point at concrete finding paths (`domain/lens`, `path:line`) so the user knows what is at stake.
- Skip noise: do not ask about findings that are already unambiguous and non-optional unless the user asked for a full walkthrough.

## Cap

If the frontier still has more than ~8 items, ask the highest-impact 8 this round (critical/high, security, contradictions first) and say how many remain for the next round. Do not dump dozens of questions in one message.
