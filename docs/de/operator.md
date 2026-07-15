# Operator-Guide

<p align="right">
  <a href="../en/operator.md">English</a> · <strong>Deutsch</strong>
  · <a href="index.md">Docs-Index</a>
  · <a href="../../README.de.md">README</a>
</p>

Praxis-Hinweise für **RepoLens Cursor Edition**.  
Empfohlener Weg: `--agent cursor-ide --local`.

## Erster Lauf (klein halten)

1. Mit einer Domain starten — einem Themenbereich wie Security:

   ```bash
   export REPOLENS_IDE_AUTONOMOUS=1
   ./repolens.sh \
     --project /pfad/zum/projekt \
     --agent cursor-ide \
     --local \
     --domain security \
     --yes
   ```

2. Cursor-Chat auf **diesem** RepoLens-Repo offen lassen, damit Handoffs fertig werden ([Handoff](handoff.md)).
3. Findings (gemeldete Punkte) unter `logs/<run-id>/issues/` öffnen.
4. Im **Zielprojekt** beheben, dieselbe Domain erneut laufen lassen.
5. Erst danach weitere Domains oder ein volles `--mode audit` (lang und aufwendig).

## Sinnvolle Domains

| Domain | Gut für |
|--------|---------|
| `security` | Auth, Injection, Secrets, typische App-Risiken |
| `toolgate` | Echte Linter / SAST (statische Security-Scanner), falls installiert — z. B. Biome, PHPStan, ruff |
| `architecture` | Grenzen, Coupling, Struktur |
| `code-quality` | Komplexität, Smells, Konsistenz |
| `llm-security` | Prompt-Injection und Agent-Tool-Risiken |
| `devops` / `iac` | CI und Infrastructure-as-Code |

Eine Lens (ein gezielter Durchlauf): `--domain security --focus injection` (Beispiel).

## Wo die Ergebnisse liegen

| Pfad | Inhalt |
|------|--------|
| `logs/<run-id>/issues/` | Markdown-Findings (Hauptoutput bei `--local`) |
| `logs/<run-id>/summary.json` | Status, Outcomes, Timing |
| `logs/<run-id>/final/` | Maschinen-Index / Triage, falls erzeugt |
| `logs/<run-id>/attempts.json` | Historie, wenn der Lauf fortgesetzt wurde |

Nützliche Flags: `--yes`, `--human-review`, `--resume`.

## Wenn ein Lauf stoppt

Cursor-Kontingent oder ein fehlgeschlagener Handoff kann eine Lens pausieren. **Denselben Run fortsetzen** — keine neue Run-ID, außer du willst bewusst neu starten:

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

`toolgate`-Lenses versuchen, **Tools auf deinem Rechner** zu starten (ESLint/Biome, PHPCS, PHPStan/Psalm, ruff und Ähnliches).  
Fehlt ein Tool, kommt oft ein `[SETUP]`-Finding statt eines stillen „alles in Ordnung“.

Volle Liste (statisch + DAST): **[Toolgate-Tools](toolgate-tools.md)**.

```bash
./repolens.sh ... --domain toolgate --yes
# oder: --domain toolgate --focus lint
```

## Was du nicht als Default auditieren solltest

Volle Multi-Lens-Läufe gegen **Vendor- oder Interpreter-Spiegel** (z. B. `php-src`, beliebige Dependency-Forks) lohnen selten. Besser die **Anwendung**, die sie nutzt — oder ein schmales Diff zum Upstream-Parent.

## Mehr Details

- [Toolgate-Tools](toolgate-tools.md)
- [IDE-Handoff](handoff.md)
- [CLI- & Modes-Referenz](../en/full-reference.md) (EN)
- [Audit-Pipeline-Skill](https://github.com/benjarogit/RepoLens-Cursor-Edition/blob/master/.cursor/skills/audit-pipeline/SKILL.md)
