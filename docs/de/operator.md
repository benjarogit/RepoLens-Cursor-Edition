# Operator-Guide

<p align="right">
  <a href="../en/operator.md">English</a> · <strong>Deutsch</strong>
  · <a href="README.md">Docs-Index</a>
  · <a href="../../README.de.md">README</a>
</p>

Praxis-Hinweise für **RepoLens Cursor Edition**.  
Standardweg: `--agent cursor-ide --local`.

## Erster Lauf (klein halten)

1. Eine Domain starten, z. B. Security:

   ```bash
   export REPOLENS_IDE_AUTONOMOUS=1
   ./repolens.sh \
     --project /pfad/zum/projekt \
     --agent cursor-ide \
     --local \
     --domain security \
     --yes
   ```

2. Cursor-Chat auf **diesem** RepoLens-Repo offen lassen, damit Handoffs laufen ([Handoff](handoff.md)).
3. Findings unter `logs/<run-id>/issues/` lesen.
4. Im **Zielprojekt** fixen, dieselbe Domain erneut laufen lassen.
5. Erst danach weitere Domains oder ein volles `--mode audit` (lang und schwer).

## Sinnvolle Domains

| Domain | Gut für |
|--------|---------|
| `security` | Auth, Injection, Secrets, typische App-Risiken |
| `toolgate` | Echte Linter/SAST, falls installiert (Biome, PHPStan, ruff, …) |
| `architecture` | Grenzen, Coupling, Struktur |
| `code-quality` | Komplexität, Smells, Konsistenz |
| `llm-security` | Prompt-Injection / Agent-Tool-Risiken |
| `devops` / `iac` | CI und Infrastructure-as-Code |

Eine Lens: `--domain security --focus injection` (Beispiel).

## Wo die Ergebnisse liegen

| Pfad | Inhalt |
|------|--------|
| `logs/<run-id>/issues/` | Markdown-Findings (Hauptoutput bei `--local`) |
| `logs/<run-id>/summary.json` | Status, Outcomes, Timing |
| `logs/<run-id>/final/` | Maschinen-Index / Triage falls erzeugt |
| `logs/<run-id>/attempts.json` | Historie bei Resume |

Nützliche Flags: `--yes`, `--human-review`, `--resume`.

## Wenn ein Lauf stoppt

Cursor-Quota oder fehlgeschlagener Handoff kann eine Lens pausieren. **Denselben Run fortsetzen** — keine neue Run-ID, außer du willst neu starten:

```bash
./repolens.sh --resume <run-id> \
  --project /pfad/zum/projekt \
  --agent cursor-ide --local --yes

# oder automatisch den letzten unterbrochenen Run:
./repolens.sh --resume \
  --project /pfad/zum/projekt \
  --agent cursor-ide --local --yes
```

Hilfsskripte: `repolens_until_done.sh`, `repolens_agent_or_ide.sh`.

## Toolgate (echte Scanner)

`toolgate`-Lenses starten **Tools auf deinem Rechner** (ESLint/Biome, PHPCS, PHPStan/Psalm, ruff, …).  
Fehlt ein Tool, kommt oft ein `[SETUP]`-Finding statt „alles grün“.

```bash
./repolens.sh ... --domain toolgate --yes
# oder: --domain toolgate --focus lint
```

## Was du nicht als Default auditieren solltest

Volle Multi-Lens-Läufe gegen **Vendor-/Interpreter-Mirrors** (z. B. `php-src`, beliebige Dependency-Forks) lohnen selten. Besser die **Anwendung**, die sie nutzt — oder ein schmales Diff zum Upstream-Parent.

## Mehr Details

- [IDE-Handoff](handoff.md)
- [CLI- & Modes-Referenz](../en/full-reference.md) (EN)
- [Audit-Pipeline-Skill](../../.cursor/skills/audit-pipeline/SKILL.md)
