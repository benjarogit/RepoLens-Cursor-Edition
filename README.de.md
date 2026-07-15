<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/assets/logo-dark.png" />
    <img src="docs/assets/logo-light.png" alt="RepoLens Cursor Edition" width="88" height="88" />
  </picture>
</p>

<h1 align="center">RepoLens</h1>

<p align="center">
  <strong>Cursor Edition</strong><br/>
  Multi-Lens-Audits in der <strong><a href="https://cursor.com/referral?code=UW6WJZLB8ECL">Cursor</a>-IDE</strong> — Findings als lokale Dateien, ohne separate Agent-CLI.
</p>

<p align="center">
  <a href="https://benjarogit.github.io/RepoLens-Cursor-Edition/de/"><img src="https://img.shields.io/badge/Dokumentation-Docs%20lesen-0B3D91?style=for-the-badge" alt="Dokumentation" /></a>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-Apache_2.0-blue.svg" alt="Lizenz" /></a>
  <a href="https://github.com/benjarogit/RepoLens-Cursor-Edition/releases/latest"><img src="https://img.shields.io/github/v/release/benjarogit/RepoLens-Cursor-Edition?label=release" alt="Latest Release" /></a>
  <a href="https://github.com/TheMorpheus407/RepoLens"><img src="https://img.shields.io/badge/upstream-RepoLens-informational" alt="Upstream" /></a>
  <a href="https://cursor.com/referral?code=UW6WJZLB8ECL"><img src="https://img.shields.io/badge/Cursor-starten-black" alt="Cursor starten" /></a>
</p>

<!-- README-I18N:START -->
<p align="center">
  <a href="README.md">English</a> · <strong>Deutsch</strong>
</p>
<!-- README-I18N:END -->

---

## Dokumentation

**Alle Guides stehen auf der Docs-Site** (Sidebar, Suche, English / Deutsch):

### → [RepoLens Cursor Edition Doku](https://benjarogit.github.io/RepoLens-Cursor-Edition/de/)

Dort: Operator-Guide, IDE-Handoff, Toolgate-Tool-Liste und CLI-Referenz.  
Markdown-Quellen im Repo: [`docs/de/`](docs/de/) und [`docs/en/`](docs/en/).

---

## Was das ist

Fork von [TheMorpheus407/RepoLens](https://github.com/TheMorpheus407/RepoLens) für **[Cursor](https://cursor.com/referral?code=UW6WJZLB8ECL) Composer/Agent**. Jede *Lens* ist ein gezielter Prüfdurchlauf.

| | |
|---|---|
| **Agent** | `--agent cursor-ide` |
| **Output** | `logs/<run-id>/` mit `--local` |
| **Schleife** | `REPOLENS_CTL` → Prompt → Antwort → Done |

> [!IMPORTANT]
> Agenten können Shell-Befehle ausführen. Starte mit einer Domain (z. B. `--domain security`). Immer `--local`.

## Schnellstart

```bash
git clone https://github.com/benjarogit/RepoLens-Cursor-Edition.git
cd RepoLens-Cursor-Edition
chmod +x repolens.sh

export REPOLENS_IDE_AUTONOMOUS=1
./repolens.sh \
  --project /pfad/zum/projekt \
  --agent cursor-ide --local --domain security --yes
```

Brauchst du [Cursor](https://cursor.com/referral?code=UW6WJZLB8ECL)? Installieren, Chat auf diesem Repo öffnen, bei `REPOLENS_CTL` dem [IDE-Handoff](https://benjarogit.github.io/RepoLens-Cursor-Edition/de/handoff/) folgen.

Mehr: [Docs-Site](https://benjarogit.github.io/RepoLens-Cursor-Edition/de/) · [Upstream-Sync](UPSTREAM.md) · [Changelog](CHANGELOG.md)

Setze `REPOLENS_TEST_DOCKER=1`, um auch Integrationstests mit Docker zu laufen.

## Lizenz

[Apache-2.0](LICENSE). Upstream © Bootstrap Academy / TheMorpheus407; Cursor-Edition unter denselben Bedingungen, soweit anwendbar.
