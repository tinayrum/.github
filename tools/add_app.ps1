# PowerShell版 add_app.ps1
# ==========================================
# 既存プロジェクトへのアプリ追加スクリプト (PowerShell版)
# ==========================================

param(
    [Parameter(Mandatory=$true)][string]$PortalName,
    [Parameter(Mandatory=$true)][string]$AppName
)

$ErrorActionPreference = 'Stop'

# 設定値
$OrgName = "tinayrum"
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
    Write-Host "エラー: PATが取得できませんでした。" -ForegroundColor Red
    exit 1
}

# 作業ディレクトリの移動: ワークスペースルートへ
$WorkDir = Resolve-Path (Join-Path $ScriptDir "../..")
Set-Location $WorkDir
Write-Host "作業場所を移動しました: $(Get-Location)"

Write-Host "🚀 アプリケーション追加プロセスを開始します..."

# 1. アプリリポジトリの作成
Write-Host "Creating App Repository: $AppName..."
gh repo create "$OrgName/$AppName" --template "$OrgName/$TemplateApp" --private

# 2. アプリ側にSecretと変数を設定
Write-Host "Setting Secrets & Variables..."
gh secret set ORG_ADMIN_TOKEN -b "$AdminToken" --repo "$OrgName/$AppName"
gh variable set PORTAL_REPO_NAME --body "$PortalName" --repo "$OrgName/$AppName"

# 3. 親リポジトリにSubtreeとして登録
Write-Host "Configuring Subtree in Portal..."

# ポータルをクローン（既にある場合はPull）
if (Test-Path $PortalName) {
    Set-Location $PortalName
    git pull origin main
} else {
    gh repo clone "$OrgName/$PortalName"
    Set-Location $PortalName
}

git remote add $AppName "https://github.com/$OrgName/$AppName.git"
Write-Host "Fetching app repository..."
git fetch $AppName main

git subtree add --prefix="apps/$AppName" $AppName main --squash -m "init: add new app $AppName"

git push origin main

Set-Location ..

Write-Host "=========================================="
Write-Host "✅ アプリ追加完了！"
Write-Host "  Portal: https://github.com/$OrgName/$PortalName"
Write-Host "  New App: https://github.com/$OrgName/$AppName"
Write-Host "=========================================="