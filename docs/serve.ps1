#requires -Version 5.1
<#
.SYNOPSIS
  Live-preview the documentation site locally, with auto-rebuild + browser refresh.
.DESCRIPTION
  Builds the Sphinx site, opens http://127.0.0.1:8000, and rebuilds + reloads the page
  every time you save a source file. Ctrl-C to stop.

  First run bootstraps a local .venv-docs (gitignored) and installs the toolchain from
  docs/requirements.txt + sphinx-autobuild, so this works on a fresh clone with nothing
  but Python 3.10+ installed.
.EXAMPLE
  pwsh docs/serve.ps1
.EXAMPLE
  pwsh docs/serve.ps1 -Port 9000
#>
param(
    [int]$Port = 8000,
    [switch]$NoOpen
)

$ErrorActionPreference = 'Stop'
$docs = $PSScriptRoot
$repo = Split-Path -Parent $docs
$venv = Join-Path $repo '.venv-docs'
$py   = Join-Path $venv 'Scripts\python.exe'

if (-not (Test-Path $py)) {
    Write-Host "Setting up the docs toolchain in $venv ..." -ForegroundColor Cyan
    python -m venv $venv
    & $py -m pip install --quiet --upgrade pip
    & $py -m pip install --quiet -r (Join-Path $docs 'requirements.txt')
}

# sphinx-autobuild is a dev-only tool (not in requirements.txt, which CI uses).
& $py -m pip show sphinx-autobuild *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Installing sphinx-autobuild ..." -ForegroundColor Cyan
    & $py -m pip install --quiet sphinx-autobuild
}

$open = if ($NoOpen) { @() } else { @('--open-browser') }
Write-Host "Live docs at http://127.0.0.1:$Port  (Ctrl-C to stop)" -ForegroundColor Green
& $py -m sphinx_autobuild @open --port $Port $docs (Join-Path $docs '_build\html')
