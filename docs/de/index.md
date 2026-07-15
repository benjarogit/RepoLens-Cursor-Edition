---
title: Start
description: Dokumentation zu RepoLens Cursor Edition — Operator-Guide, IDE-Handoff und CLI-Referenz
hide:
  - navigation
  - toc
---

<div class="rl-hero" markdown="0">
  <img class="rl-hero__logo" src="assets/logo-light.png" alt="" width="72" height="72" />
  <div class="rl-hero__copy">
    <h1>RepoLens Cursor Edition</h1>
    <p>Multi-Lens-Audits <strong>in der Cursor-IDE</strong> — Findings als lokale Dateien, ohne separate Agent-CLI.</p>
  </div>
</div>

Hier starten, Referenz nutzen wenn Flags und Schemas gebraucht werden.

<div class="grid cards" markdown>

-   :material-rocket-launch: __Operator-Guide__

    ---

    Erste Läufe, vollständiger Audit, Findings, Resume und Domains.

    [:octicons-arrow-right-24: Guide öffnen](operator.md)

-   :material-transit-connection-variant: __IDE-Handoff__

    ---

    Wie Cursor jede Lens abschließt: Prompt → Antwort → Done.

    [:octicons-arrow-right-24: Handoff-Protokoll](handoff.md)

-   :material-shield-search: __Toolgate-Tools__

    ---

    Scanner und Linter, die unter der Toolgate-Domain laufen können.

    [:octicons-arrow-right-24: Tool-Inventar](toolgate-tools.md)

-   :material-console: __CLI & Modes__

    ---

    Flags, Modes, Umgebungsvariablen und längere Referenz (EN-Fallback).

    [:octicons-arrow-right-24: Vollständige Referenz](full-reference.md)

</div>

## Befehle

**Klein starten** (eine Domain):

```bash
export REPOLENS_IDE_AUTONOMOUS=1
./repolens.sh \
  --project /pfad/zum/projekt \
  --agent cursor-ide --local --domain security --yes
```

**Vollständiger Audit** (alle Standard-Audit-Domains — langer Lauf):

```bash
export REPOLENS_IDE_AUTONOMOUS=1
./repolens.sh \
  --project /pfad/zum/projekt \
  --agent cursor-ide --local --mode audit --parallel --yes
```

Details: [Operator-Guide → Vollständiger Audit](operator.md#vollstandiger-audit-alle-standard-domains).

!!! tip "Immer `--local`"
    Die Cursor Edition ist auf lokale Markdown-Findings und IDE-Handoff ausgelegt. Bevorzuge `--agent cursor-ide --local`.

## Außerdem nützlich

| Doc | Wann |
|-----|------|
| [Finding-Registry](finding-registry-schema.md) | Aufbau von `findings.jsonl` / CSV (EN) |
| [Releases](releasing.md) | Cursor-Edition GitHub Release schneiden |
| [Upstream-Sync](https://github.com/benjarogit/RepoLens-Cursor-Edition/blob/master/UPSTREAM.md) | Merge von TheMorpheus407/RepoLens |
| [Changelog](https://github.com/benjarogit/RepoLens-Cursor-Edition/blob/master/CHANGELOG.md) | Änderungen |
| [Contributing](https://github.com/benjarogit/RepoLens-Cursor-Edition/blob/master/CONTRIBUTING.md) | Lenses und Pull Requests |

Repository-README: [Deutsch](https://github.com/benjarogit/RepoLens-Cursor-Edition/blob/master/README.de.md) · [English](https://github.com/benjarogit/RepoLens-Cursor-Edition/blob/master/README.md)
