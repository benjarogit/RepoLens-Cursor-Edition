---
title: Start
description: Dokumentation zu RepoLens Cursor Edition — Operator-Guide, IDE-Handoff und CLI-Referenz
hide:
  - navigation
  - toc
---

<div class="rl-hero" markdown>

<div class="rl-hero__mark" markdown>
![RepoLens](assets/logo-light.png){ width="88" }
</div>

<div class="rl-hero__copy" markdown>

# RepoLens Cursor Edition

Multi-Lens-Audits **in der Cursor-IDE** — Findings als lokale Dateien, ohne separate Agent-CLI.

</div>

</div>

Hier starten, Referenz nutzen wenn Flags und Schemas gebraucht werden.

<div class="grid cards" markdown>

-   :material-rocket-launch: __Operator-Guide__

    ---

    Erste Läufe, Findings-Layout, Resume und sinnvolle Domains.

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

## Ein Befehl

```bash
export REPOLENS_IDE_AUTONOMOUS=1
./repolens.sh \
  --project /pfad/zum/projekt \
  --agent cursor-ide --local --domain security --yes
```

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
