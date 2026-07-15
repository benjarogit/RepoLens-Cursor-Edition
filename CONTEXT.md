# RepoLens Cursor Edition — shared language

Concise domain vocabulary for agents and humans. Prefer these terms over paraphrases.

## Product

| Term | Meaning |
|------|---------|
| **RepoLens** | Multi-lens audit orchestrator (`repolens.sh` + `lib/`). Runs analysis agents against a git project and emits findings. |
| **Cursor Edition** | This fork (`benjarogit/RepoLens-Cursor-Edition`): IDE handoff only; not the upstream Claude/Codex-first product. |
| **Upstream** | `TheMorpheus407/RepoLens` — keep behavior compatible where intentional; Cursor Edition diverges on agent path and docs. |

## Agent / Handoff

| Term | Meaning |
|------|---------|
| **cursor-ide** | Only supported `--agent` here. Chat reads prompt files and writes response + done markers. |
| **CTL** | Control channel: `REPOLENS_CTL` stderr JSON / `logs/<run-id>/repolens-ctl.ndjson` with `kind: ide_handoff`. |
| **Handoff** | Per-lens cycle: read `files.prompt` → write `files.response` (≥ min bytes) → `touch files.done`. |
| **Ambient agent** | A real CLI (`claude`, `codex`, …) on PATH. Tests must not require one; CI strips them. |

Do **not** use `--agent claude|codex|opencode|cursor` (CLI) in this edition without an explicit human exception.

## Run topology

| Term | Meaning |
|------|---------|
| **Lens** | One expert prompt (`prompts/lenses/…`) executed as a unit of work. |
| **Domain** | Named group of lenses in `config/domains.json` (e.g. `security`, `toolgate`). |
| **Mode** | Run profile (`audit`, `bugreport`, `discover`, …) that filters domains/lenses and defaults. |
| **Toolgate** | Domain of *real* tools (linters, SAST, DAST helpers) — not LLM-only lenses. |
| **Round** | Cross-lens pass. Most modes: `rounds_total == 1`. Multi-round is primarily **bugreport**. |
| **Depth** | DONE-streak length per lens before that lens stops. |
| **Finalize** | End-of-run: summary, optional synthesizer/triage/human-review, local filing. |

## Findings / output

| Term | Meaning |
|------|---------|
| **Finding** | One issue record (severity, type, evidence). |
| **Local mode** | `--local`: write markdown under the run dir instead of opening forge issues. |
| **Forge** | Remote tracker CLI layer (`gh` / `tea` / `fj`). |
| **Human review** | `--human-review` / `REPOLENS_HUMAN_REVIEW`: curated `HUMAN_REVIEW.md` digest at finalize (noise budget). |
| **Summary** | `logs/<run-id>/summary.json` — authoritative run result for tests and status. |

## Docs surface

| Term | Meaning |
|------|---------|
| **Landing README** | Short `README.md` / `README.de.md` — entry + docs CTA, not the full operator contract. |
| **Operator doc** | `docs/en/full-reference.md` (and DE twin) — CLI/env/mode contracts that CI asserts. |
| **MkDocs site** | GitHub Pages from `mkdocs.yml` — published docs for humans. |

## ADRs (Cursor Edition)

1. **IDE-only agent path** — Avoid external CLI auth; keep the Cursor chat handoff protocol.
2. **MkDocs over GitHub Wiki** — Versioned docs in-repo; README stays thin.
3. **Doc contracts in MkDocs sources** — Tests bind to operator docs, not the landing README body.

When introducing a new durable term or decision, update this file in the same change.
