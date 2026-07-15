<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/assets/logo-dark.png" />
    <img src="docs/assets/logo-light.png" alt="RepoLens Cursor Edition" width="88" height="88" />
  </picture>
</p>

<h1 align="center">RepoLens</h1>

<p align="center">
  <strong>Cursor Edition</strong><br/>
  Multi-lens code audits in <strong><a href="https://cursor.com/referral?code=UW6WJZLB8ECL">Cursor</a> IDE</strong> — findings as local files, without a separate agent CLI.
</p>

<p align="center">
  <a href="https://benjarogit.github.io/RepoLens-Cursor-Edition/"><img src="https://img.shields.io/badge/Documentation-read%20the%20docs-0B3D91?style=for-the-badge" alt="Documentation" /></a>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-Apache_2.0-blue.svg" alt="License" /></a>
  <a href="https://github.com/benjarogit/RepoLens-Cursor-Edition/releases/latest"><img src="https://img.shields.io/github/v/release/benjarogit/RepoLens-Cursor-Edition?label=release" alt="Latest release" /></a>
  <a href="https://github.com/TheMorpheus407/RepoLens"><img src="https://img.shields.io/badge/upstream-RepoLens-informational" alt="Upstream" /></a>
  <a href="https://cursor.com/referral?code=UW6WJZLB8ECL"><img src="https://img.shields.io/badge/Cursor-get%20started-black" alt="Get Cursor" /></a>
</p>

<!-- README-I18N:START -->
<p align="center">
  <strong>English</strong> · <a href="README.de.md">Deutsch</a>
</p>
<!-- README-I18N:END -->

---

## Documentation

**All guides live on the docs site** (sidebar, search, English / Deutsch):

### → [RepoLens Cursor Edition Docs](https://benjarogit.github.io/RepoLens-Cursor-Edition/)

There you get the operator guide, IDE handoff, toolgate tool list, and CLI reference.  
Markdown sources stay in this repo under [`docs/en/`](docs/en/) and [`docs/de/`](docs/de/).

---

## What this is

Fork of [TheMorpheus407/RepoLens](https://github.com/TheMorpheus407/RepoLens) for **[Cursor](https://cursor.com/referral?code=UW6WJZLB8ECL) Composer/Agent**. Each *lens* is one focused review pass.

| | |
|---|---|
| **Agent** | `--agent cursor-ide` |
| **Output** | `logs/<run-id>/` with `--local` |
| **Loop** | `REPOLENS_CTL` → prompt → response → done |

> [!IMPORTANT]
> Agents can run shell commands. Start with one domain (e.g. `--domain security`). Always use `--local`.

## Quick start

```bash
git clone https://github.com/benjarogit/RepoLens-Cursor-Edition.git
cd RepoLens-Cursor-Edition
chmod +x repolens.sh

export REPOLENS_IDE_AUTONOMOUS=1
./repolens.sh \
  --project /path/to/your/repo \
  --agent cursor-ide --local --domain security --yes
```

Need [Cursor](https://cursor.com/referral?code=UW6WJZLB8ECL)? Install it, open chat on this repo, then follow the [IDE handoff](https://benjarogit.github.io/RepoLens-Cursor-Edition/handoff/) when `REPOLENS_CTL` appears.

More: [docs site](https://benjarogit.github.io/RepoLens-Cursor-Edition/) · [upstream sync](UPSTREAM.md) · [changelog](CHANGELOG.md)

## License

[Apache-2.0](LICENSE). Upstream © Bootstrap Academy / TheMorpheus407; Cursor Edition under the same terms where applicable.
