# Documentation source

Published site (search, sidebar, EN/DE):

**https://benjarogit.github.io/RepoLens-Cursor-Edition/**

| Locale | Path |
|--------|------|
| English | [`en/`](en/) |
| Deutsch | [`de/`](de/) |

Build locally:

```bash
python3 -m venv .venv-docs
source .venv-docs/bin/activate   # use a real system Python, not a Cursor-wrapped interpreter
pip install -r requirements-docs.txt
mkdocs serve
```

Config: [`../mkdocs.yml`](https://github.com/benjarogit/RepoLens-Cursor-Edition/blob/master/mkdocs.yml) (Material theme).
