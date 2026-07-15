# Toolgate tools

<p align="right">
  <strong>English</strong> · <a href="../de/toolgate-tools.md">Deutsch</a>
  · <a href="index.md">Docs index</a>
  · <a href="../../README.md">README</a>
</p>

Most RepoLens domains (`security`, `architecture`, `code-quality`, …) are **agent review lenses**: the Cursor agent reads code and writes findings. They do **not** require a fixed scanner install.

The **`toolgate`** domain is different: lenses try to **run real tools** on your machine (or via Docker / `--hosted`). If a tool is missing, you usually get a `[SETUP]` finding — not a silent pass.

```bash
./repolens.sh --project /path/to/repo --agent cursor-ide --local \
  --domain toolgate --yes
```

Source of truth per lens: [`prompts/lenses/toolgate/`](https://github.com/benjarogit/RepoLens-Cursor-Edition/tree/master/prompts/lenses/toolgate/).

## Static analysis & quality

| Lens (`--focus`) | Typical tools | Notes |
|------------------|---------------|--------|
| `lint` | Biome, ESLint, ruff / flake8 / pylint, cargo clippy, golangci-lint, PHPCS, clang-tidy / cppcheck | First matching tool per language; style auto-fixers belong elsewhere |
| `typecheck` | `tsc`, mypy, pyright, PHPStan, Psalm, Flow, Dart analyzer | Prefers project config (`tsconfig`, `phpstan.neon*`, `psalm.xml*`, …) |
| `security-sast` | Bandit, Semgrep, gosec, Brakeman; PHPStan / Psalm when security-relevant | PHPCS is **not** treated as SAST |
| `security-deps` | npm / pnpm / yarn audit, pip-audit, safety, cargo audit, govulncheck, bundler-audit, Trivy | One issue per CVE when possible |
| `quality-gates` | Project / CI scripts (`lint`, `test`, `typecheck`, `check`, …) | Runs what the repo already defines |
| `test-suite` | pytest, Jest / Vitest / `npm test`, cargo test, `go test`, Flutter / Dart test | Skips suites that need infra unless `--hosted` |

## Dynamic testing (DAST / load)

These lenses need a **live target** — usually `--hosted` (Docker Compose) so scanners can reach services on the Compose network.

| Lens | Typical tools | Notes |
|------|---------------|--------|
| `dast-web` | OWASP ZAP baseline | Hosted web surface |
| `dast-api` | ZAP / API-oriented checks | OpenAPI-aware where possible |
| `dast-injection` | Injection-focused dynamic checks | Hosted |
| `dast-headers` | Header / TLS posture checks | Hosted |
| `dast-scanner` | Nuclei (community templates) | Hosted |
| `session-zap` | OWASP ZAP (daemon session) | Deeper spider + active scan |
| `session-zap-api` | OWASP ZAP + OpenAPI | API session |
| `session-sqlmap` | sqlmap API | Targeted SQLi; non-destructive defaults |
| `session-nuclei` | Nuclei (+ optional custom templates) | Baseline then project-specific |
| `session-lighthouse` | Google Lighthouse | Perf / a11y / best-practices / SEO |
| `session-k6` | Grafana k6 | Load / breaking points |
| `session-schemathesis` | Schemathesis | OpenAPI property / stateful fuzz |

## How to read this list

- **Availability:** tools are used only if installed (or pullable via Docker) **and** the project looks like a match (lockfiles, configs, Compose services).
- **Not a guarantee:** RepoLens does not ship these scanners as a bundled toolchain; it orchestrates whatever is already useful for that repo.
- **LLM lenses elsewhere:** domains outside `toolgate` may *mention* tools in prompts, but they primarily reason over source — see [operator guide](operator.md).

## Related

- [Operator guide — toolgate](operator.md#toolgate-real-scanners)
- [CLI & modes reference](full-reference.md) (Tool Gate domain summary)
- [IDE handoff](handoff.md)
