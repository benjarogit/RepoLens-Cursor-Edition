# Toolgate-Tools

<p align="right">
  <a href="../en/toolgate-tools.md">English</a> · <strong>Deutsch</strong>
  · <a href="index.md">Docs-Index</a>
  · <a href="../../README.de.md">README</a>
</p>

Die meisten RepoLens-Domains (`security`, `architecture`, `code-quality`, …) sind **Agent-Review-Lenses**: Cursor liest Code und schreibt Findings. Dafür brauchst du **keinen** festen Scanner-Stack.

Die Domain **`toolgate`** ist anders: Lenses versuchen, **echte Tools** auf deinem Rechner (oder per Docker / `--hosted`) zu starten. Fehlt ein Tool, kommt meist ein `[SETUP]`-Finding — kein stilles „alles ok“.

```bash
./repolens.sh --project /pfad/zum/projekt --agent cursor-ide --local \
  --domain toolgate --yes
```

Quelle pro Lens: [`prompts/lenses/toolgate/`](https://github.com/benjarogit/RepoLens-Cursor-Edition/tree/master/prompts/lenses/toolgate/).

## Statische Analyse & Qualität

| Lens (`--focus`) | Typische Tools | Hinweise |
|------------------|----------------|----------|
| `lint` | Biome, ESLint, ruff / flake8 / pylint, cargo clippy, golangci-lint, PHPCS, clang-tidy / cppcheck | Pro Sprache das erste passende Tool; reine Auto-Formatter gehören woanders hin |
| `typecheck` | `tsc`, mypy, pyright, PHPStan, Psalm, Flow, Dart-Analyzer | Bevorzugt Projekt-Config (`tsconfig`, `phpstan.neon*`, `psalm.xml*`, …) |
| `security-sast` | Bandit, Semgrep, gosec, Brakeman; PHPStan / Psalm wenn security-relevant | PHPCS gilt **nicht** als SAST |
| `security-deps` | npm / pnpm / yarn audit, pip-audit, safety, cargo audit, govulncheck, bundler-audit, Trivy | Nach Möglichkeit ein Finding pro CVE |
| `quality-gates` | Projekt- / CI-Scripts (`lint`, `test`, `typecheck`, `check`, …) | Führt aus, was das Repo schon definiert |
| `test-suite` | pytest, Jest / Vitest / `npm test`, cargo test, `go test`, Flutter / Dart test | Suites mit Infra nur mit `--hosted` |

## Dynamische Tests (DAST / Last)

Diese Lenses brauchen ein **laufendes Ziel** — üblicherweise `--hosted` (Docker Compose), damit Scanner die Services im Compose-Netz erreichen.

| Lens | Typische Tools | Hinweise |
|------|----------------|----------|
| `dast-web` | OWASP ZAP Baseline | Gehostete Web-Oberfläche |
| `dast-api` | ZAP / API-Checks | OpenAPI-aware, wo möglich |
| `dast-injection` | Injection-fokussierte Dynamic Checks | Hosted |
| `dast-headers` | Header- / TLS-Lage | Hosted |
| `dast-scanner` | Nuclei (Community-Templates) | Hosted |
| `session-zap` | OWASP ZAP (Daemon-Session) | Spider + Active Scan |
| `session-zap-api` | OWASP ZAP + OpenAPI | API-Session |
| `session-sqlmap` | sqlmap API | Gezieltes SQLi; nicht-destruktive Defaults |
| `session-nuclei` | Nuclei (+ optionale Custom-Templates) | Baseline, dann projektspezifisch |
| `session-lighthouse` | Google Lighthouse | Perf / A11y / Best Practices / SEO |
| `session-k6` | Grafana k6 | Last / Breaking Points |
| `session-schemathesis` | Schemathesis | OpenAPI Property- / Stateful-Fuzz |

## So ist die Liste zu lesen

- **Verfügbarkeit:** Tools laufen nur, wenn sie installiert (oder per Docker pullbar) sind **und** das Projekt passt (Lockfiles, Configs, Compose-Services).
- **Kein Bundle:** RepoLens liefert diese Scanner nicht als festes Toolchain mit; es orchestriert, was für das Repo sinnvoll ist.
- **LLM-Lenses anderswo:** Domains außerhalb von `toolgate` können Tools in Prompts erwähnen, arbeiten aber vor allem am Quellcode — siehe [Operator-Guide](operator.md).

## Verwandt

- [Operator-Guide — Toolgate](operator.md#toolgate-echte-scanner)
- [CLI- & Modes-Referenz](../en/full-reference.md) (Tool-Gate-Domain, EN)
- [IDE-Handoff](handoff.md)
