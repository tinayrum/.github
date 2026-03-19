# ==========================================
# プロジェクト立ち上げ自動化スクリプト (PowerShell版)
# ==========================================
$ErrorActionPreference = "Stop"

# 設定値
$ORG_NAME = "tinayrum"
$TEMPLATE_PORTAL = "template_portal"
$TEMPLATE_APP = "template_app"

# 引数チェック
if ($args.Count -ne 2) {
    Write-Host "使用法: .\setup_portal.ps1 <新規ポータル名> <新規アプリ名>" -ForegroundColor Yellow
    Write-Host "例: .\setup_portal.ps1 ProjectA_portal ProjectA_app"
    exit 1
}

$PORTAL_NAME = $args[0]
$APP_NAME = $args[1]

# GitHub CLI ログイン確認
if (!(Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error "GitHub CLI (gh) がインストールされていません。"
    exit 1
}

gh auth setup-git

# ========================================================
# PAT取得ロジック
# ========================================================
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PAT_FILE = Join-Path $SCRIPT_DIR ".secret_pat"
$ADMIN_TOKEN = ""

if (Test-Path $PAT_FILE) {
    $ADMIN_TOKEN = (Get-Content $PAT_FILE -Raw).Trim()
    if ($ADMIN_TOKEN) {
        Write-Host "✅ 秘密ファイルからPATを自動取得しました。" -ForegroundColor Green
    }
}

if (-not $ADMIN_TOKEN) {
    Write-Host "--------------------------------------------------" -ForegroundColor Cyan
    Write-Host "管理者用PAT(Personal Access Token)を入力してください。"
    Write-Host "--------------------------------------------------"
    $ADMIN_TOKEN = Read-Host "PATを入力"
}

if (-not $ADMIN_TOKEN) {
    Write-Error "エラー: PATが取得できませんでした。"
    exit 1
}

# ========================================================
# 作業ディレクトリの移動
# ========================================================
$WORK_DIR = (Get-Item $SCRIPT_DIR).Parent.Parent.FullName
Set-Location $WORK_DIR
Write-Host "作業場所: $(Get-Location)" -ForegroundColor Gray

Write-Host "🚀 プロジェクト立ち上げを開始します..." -ForegroundColor Cyan

# 1. リポジトリ作成
Write-Host "Creating Portal Repository..."
gh repo create "$ORG_NAME/$PORTAL_NAME" --template "$ORG_NAME/$TEMPLATE_PORTAL" --private --clone

Write-Host "Creating App Repository..."
gh repo create "$ORG_NAME/$APP_NAME" --template "$ORG_NAME/$TEMPLATE_APP" --private

# 2. Secret & Variable 設定
Write-Host "Setting Secrets & Variables..."
$ADMIN_TOKEN | gh secret set ORG_ADMIN_TOKEN --repo "$ORG_NAME/$PORTAL_NAME"
$ADMIN_TOKEN | gh secret set ORG_ADMIN_TOKEN --repo "$ORG_NAME/$APP_NAME"
gh variable set PORTAL_REPO_NAME --body "$PORTAL_NAME" --repo "$ORG_NAME/$APP_NAME"

# 3. Subtree連携
Write-Host "Configuring Subtree..."
Set-Location $PORTAL_NAME

# リモート追加 & Fetch
git remote add "$APP_NAME" "https://github.com/$ORG_NAME/$APP_NAME.git"
Write-Host "Fetching app repository..."
git fetch "$APP_NAME" main

# Subtree追加
Write-Host "Adding subtree..."
git subtree add --prefix="apps/$APP_NAME" "$APP_NAME" main --squash -m "init: link $APP_NAME"

# Push
git push origin main

Set-Location ..

Write-Host "==========================================" -ForegroundColor Green
Write-Host "✅ セットアップ完了！"
Write-Host "  Portal: https://github.com/$ORG_NAME/$PORTAL_NAME"
Write-Host "  App:    https://github.com/$ORG_NAME/$APP_NAME"
Write-Host "=========================================="