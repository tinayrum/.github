$ErrorActionPreference = "Stop"

$ORG_NAME = "tinayrum"
$TEMPLATE_APP = "template_app"

if ($args.Count -ne 1) {
    Write-Host "Usage: .\setup_app.ps1 <app_name>" -ForegroundColor Yellow
    exit 1
}

$APP_NAME = $args[0]

if (!(Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error "GitHub CLI (gh) is not installed."
    exit 1
}

gh auth setup-git

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PAT_FILE = Join-Path $SCRIPT_DIR ".secret_pat"
$ADMIN_TOKEN = ""

if (Test-Path $PAT_FILE) {
    $ADMIN_TOKEN = (Get-Content $PAT_FILE -Raw).Trim()
}

if (-not $ADMIN_TOKEN) {
    $ADMIN_TOKEN = Read-Host "Enter GitHub PAT"
}

$rootPath = (Get-Item $SCRIPT_DIR).Parent.Parent.FullName
Set-Location $rootPath

Write-Host "🚀 Creating: $APP_NAME" -ForegroundColor Cyan
gh repo create "$ORG_NAME/$APP_NAME" --template "$ORG_NAME/$TEMPLATE_APP" --private --clone

$ADMIN_TOKEN | gh secret set ORG_ADMIN_TOKEN --repo "$ORG_NAME/$APP_NAME"

Set-Location $APP_NAME
git add .
git commit -m "Initial commit"
git push origin main

Write-Host "✅ Done!" -ForegroundColor Green