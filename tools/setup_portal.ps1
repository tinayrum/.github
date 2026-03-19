# PowerShell版 setup_portal.ps1
# ==========================================
# プロジェクト立ち上げ自動化スクリプト (PowerShell版)
# ==========================================

param(
    [Parameter(Mandatory=$true)][string]$PortalName,
    [Parameter(Mandatory=$true)][string]$AppName
)

$ErrorActionPreference = 'Stop'

# 設定値
$OrgName = "tinayrum"
$TemplatePortal = "template_portal"
$TemplateApp = "template_app"

# gh CLI ログイン確認
if (-not (gh auth status 2>$null)) {
    Write-Host "エラー: GitHub CLI (gh) にログインしていません。" -ForegroundColor Red
    exit 1
}

gh auth setup-git

# PAT取得ロジック (秘密ファイル -> 手動入力)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$PatFile = Join-Path $ScriptDir ".secret_pat"
$AdminToken = $null

if (Test-Path $PatFile) {
    $AdminToken = Get-Content $PatFile -Raw | Out-String
    $AdminToken = $AdminToken.Trim()
    if ($AdminToken) {
        Write-Host "✅ 秘密ファイル(.secret_pat)からPATを自動取得しました。"
    }
}

if (-not $AdminToken) {
    Write-Host "--------------------------------------------------"
    Write-Host "管理者用PAT(Personal Access Token)を入力してください。"
    Write-Host "--------------------------------------------------"
    $AdminToken = Read-Host -AsSecureString "PAT"
    $AdminToken = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($AdminToken))
}

if (-not $AdminToken) {
    Write-Host "エラー: PATが取得できませんでした。処理を中止します。" -ForegroundColor Red
    exit 1
}

# 作業ディレクトリの移動: ワークスペースルートへ
$WorkDir = Resolve-Path (Join-Path $ScriptDir "../..")
Set-Location $WorkDir
Write-Host "作業場所を移動しました: $(Get-Location)"

Write-Host "🚀 プロジェクト立ち上げを開始します..."

# 1. リポジトリ作成
Write-Host "Creating Portal Repository..."
gh repo create "$OrgName/$PortalName" --template "$OrgName/$TemplatePortal" --private --clone

Write-Host "Creating App Repository..."
gh repo create "$OrgName/$AppName" --template "$OrgName/$TemplateApp" --private

# 2. Secret & Variable 設定
Write-Host "Setting Secrets & Variables..."
gh secret set ORG_ADMIN_TOKEN -b "$AdminToken" --repo "$OrgName/$PortalName"
gh secret set ORG_ADMIN_TOKEN -b "$AdminToken" --repo "$OrgName/$AppName"
gh variable set PORTAL_REPO_NAME --body "$PortalName" --repo "$OrgName/$AppName"

# 3. Subtree連携
Write-Host "Configuring Subtree..."
Set-Location $PortalName

git remote add $AppName "https://github.com/$OrgName/$AppName.git"
Write-Host "Fetching app repository..."
git fetch $AppName main

Write-Host "Adding subtree..."
git subtree add --prefix="apps/$AppName" $AppName main --squash -m "init: link $AppName"

git push origin main

Set-Location ..

Write-Host "=========================================="
Write-Host "✅ セットアップ完了！"
Write-Host "  Portal: https://github.com/$OrgName/$PortalName"
Write-Host "  App:    https://github.com/$OrgName/$AppName"
Write-Host "=========================================="