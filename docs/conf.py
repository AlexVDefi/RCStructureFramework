# Configuration file for the Sphinx documentation builder.
# https://www.sphinx-doc.org/en/master/usage/configuration.html
#
# Build locally:  sphinx-build -b html docs docs/_build/html
# (the repo ships a .venv-docs you can use, or `pip install -r docs/requirements.txt`)

# -- Project information -----------------------------------------------------

project = "RC Structure Framework"
author = "RedChili"
copyright = "2026, RedChili"
release = "1.1"
version = "1.1"

# Public repository the docs are served from (Furo's source links + GitHub button).
repo_url = "https://github.com/AlexVDefi/RCStructureFramework"

# -- General configuration ---------------------------------------------------

extensions = [
    "myst_parser",        # Markdown (MyST) source
    "sphinx_copybutton",  # copy button on code blocks
    "sphinx_design",      # cards / grids / tabs for the landing page + tabbed examples
]

# MyST (Markdown) features used across the docs.
myst_enable_extensions = [
    "colon_fence",    # ::: fenced directives (admonitions, cards)
    "deflist",        # definition lists
    "fieldlist",      # field lists
    "attrs_inline",   # inline attributes
    "substitution",   # |variables|
    "tasklist",       # - [ ] checkboxes
]
myst_heading_anchors = 4  # auto-anchor headings up to h4 so cross-page #links resolve

templates_path = ["_templates"]
exclude_patterns = [
    "_build", "Thumbs.db", ".DS_Store", "requirements.txt", "README.md",
    # Capture feature parked until properly tested - hidden from the built docs.
    "how-to/capture.md", "tutorials/spawn-and-capture.md",
]

# Lua is the language of every unmarked code block.
highlight_language = "lua"
pygments_style = "friendly"
pygments_dark_style = "monokai"

# -- HTML output -------------------------------------------------------------

html_theme = "furo"
html_title = "RC Structure Framework"
html_baseurl = "https://alexvdefi.github.io/RCStructureFramework/"
html_static_path = ["_static"]
html_css_files = ["custom.css"]
html_copy_source = False
html_show_sphinx = False

html_theme_options = {
    "source_repository": repo_url,
    "source_branch": "main",
    "source_directory": "docs/",
    "navigation_with_keys": True,
}
