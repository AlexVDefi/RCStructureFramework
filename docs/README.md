# Documentation

This folder is the source for the RC Structure Framework documentation site, a Sphinx
project written in Markdown (via MyST) with the Furo theme. The rendered site is published
to GitHub Pages.

## Preview it locally (live reload)

From the repo root:

```powershell
pwsh docs/serve.ps1
```

This builds the site, opens <http://127.0.0.1:8000>, and rebuilds + refreshes the browser
every time you save a file. Press Ctrl-C to stop. The first run sets up a local
`.venv-docs` (gitignored) and installs the toolchain, so it works on a fresh clone with
only Python 3.10+ installed.

## One-off build

```powershell
python -m venv .venv-docs
.venv-docs/Scripts/python -m pip install -r docs/requirements.txt
.venv-docs/Scripts/python -m sphinx -b html docs docs/_build/html
```

Then open `docs/_build/html/index.html`. Add `-W` to treat warnings as errors (what CI does).

## Structure

- `index.md` - landing page
- `getting-started.md` - the 5-minute build
- `tutorials/` - build-along lessons
- `how-to/` - task recipes
- `concepts/` - background / architecture
- `reference/` - API, structure definition, data contracts, events, roadmap
- `conf.py` - Sphinx config (update `repo_url` if the public repo moves)
- `requirements.txt` - the toolchain (pinned; used by the GitHub Pages build)

## Hosting

- **GitHub Pages:** builds + deploys on push to `main` via `../.github/workflows/docs.yml`
  (set Settings -> Pages -> Source = "GitHub Actions" on the public repo).
