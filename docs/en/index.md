---
title: Home
description: RepoLens Cursor Edition documentation — operator guide, IDE handoff, and CLI reference
hide:
  - navigation
  - toc
---

<div class="rl-hero" markdown="0">
  <img class="rl-hero__logo" src="assets/logo-light.png" alt="" width="72" height="72" />
  <div class="rl-hero__copy">
    <h1>RepoLens Cursor Edition</h1>
    <p>Multi-lens code audits <strong>inside Cursor IDE</strong> — findings as local files, without a separate agent CLI.</p>
  </div>
</div>

Start here, then dig into reference when you need flags and schemas.

<div class="grid cards" markdown>

-   :material-rocket-launch: __Operator guide__

    ---

    First runs, full audits, findings, resume, and domains.

    [:octicons-arrow-right-24: Open guide](operator.md)

-   :material-transit-connection-variant: __IDE handoff__

    ---

    How Cursor finishes each lens: prompt → response → done.

    [:octicons-arrow-right-24: Handoff protocol](handoff.md)

-   :material-shield-search: __Toolgate tools__

    ---

    Real scanners and linters that may run under the toolgate domain.

    [:octicons-arrow-right-24: Tool inventory](toolgate-tools.md)

-   :material-console: __CLI & modes__

    ---

    Flags, modes, environment variables, and longer reference.

    [:octicons-arrow-right-24: Full reference](full-reference.md)

</div>

## Commands

**Small start** (one domain):

```bash
export REPOLENS_IDE_AUTONOMOUS=1
./repolens.sh \
  --project /path/to/repo \
  --agent cursor-ide --local --domain security --yes
```

**Full audit** (all default audit domains — long run):

```bash
export REPOLENS_IDE_AUTONOMOUS=1
./repolens.sh \
  --project /path/to/repo \
  --agent cursor-ide --local --mode audit --parallel --yes
```

Details: [Operator guide → Full audit](operator.md#full-audit-all-default-domains).

!!! tip "Always `--local`"
    Cursor Edition is built around local markdown findings and IDE handoff. Prefer `--agent cursor-ide --local`.

## Also useful

| Doc | When |
|-----|------|
| [Finding registry](finding-registry-schema.md) | Shape of `findings.jsonl` / CSV |
| [Releasing](releasing.md) | Cut a Cursor Edition GitHub Release |
| [Upstream sync](https://github.com/benjarogit/RepoLens-Cursor-Edition/blob/master/UPSTREAM.md) | Merge from TheMorpheus407/RepoLens |
| [Changelog](https://github.com/benjarogit/RepoLens-Cursor-Edition/blob/master/CHANGELOG.md) | What changed |
| [Contributing](https://github.com/benjarogit/RepoLens-Cursor-Edition/blob/master/CONTRIBUTING.md) | Lenses and pull requests |

Repository README: [English](https://github.com/benjarogit/RepoLens-Cursor-Edition/blob/master/README.md) · [Deutsch](https://github.com/benjarogit/RepoLens-Cursor-Edition/blob/master/README.de.md)
