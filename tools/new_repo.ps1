# ==========================================
# tinayrum のリポジトリ立ち上げスクリプト（PowerShell 版）
# ==========================================
#
# 使い方:
#   .\tools\new_repo.ps1 <repo-name> [-Public]     テンプレート(temp)から新規作成して初期設定する
#   .\tools\new_repo.ps1 <repo-name> -ConfigureOnly
#                                                  既存リポジトリに初期設定（手順 3〜5）だけを適用する
#
# 手順・環境変数は new_repo.sh と同じ（docs/tools.md を参照）。
# Windows PowerShell 5.1 / PowerShell 7 のどちらでも動く。Secret は使わない。

param(
    [Parameter(Position = 0)][string]$Name,
    [switch]$Public,
    [switch]$ConfigureOnly
)

$ErrorActionPreference = "Stop"

function Get-EnvOrDefault([string]$Key, [string]$Default) {
    $value = [Environment]::GetEnvironmentVariable($Key)
    if ([string]::IsNullOrEmpty($value)) { return $Default }
    return $value
}

$ORG = Get-EnvOrDefault "NEW_REPO_ORG" "tinayrum"
$TEMPLATE = Get-EnvOrDefault "NEW_REPO_TEMPLATE" "temp"
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$WORKSPACE = Get-EnvOrDefault "NEW_REPO_WORKSPACE" (Split-Path -Parent (Split-Path -Parent $SCRIPT_DIR))
$WAIT_RETRIES = [int](Get-EnvOrDefault "NEW_REPO_WAIT_RETRIES" "20")
$WAIT_INTERVAL = [int](Get-EnvOrDefault "NEW_REPO_WAIT_INTERVAL" "3")

# 命名規則（client- 受託 / prod- 自社プロダクト / int- 社内 / poc- 検証）。管理用リポジトリは対象外
$NAME_PATTERN = '^(client|prod|int|poc)-[a-z0-9]+(-[a-z0-9]+)*$'
$NAME_EXEMPT = @(".github", "temp", "infra")

function Write-Warn([string]$Message) { Write-Host "⚠️  $Message" -ForegroundColor Yellow }
function Stop-WithError([string]$Message) {
    Write-Host "❌ $Message" -ForegroundColor Red
    exit 1
}

# gh / git を実行し、終了コードを返す。Windows PowerShell 5.1 で stderr が例外にならないよう
# 一時的に ErrorActionPreference を Continue にする。
function Invoke-Native {
    param([string]$Command, [string[]]$Arguments, [switch]$Quiet)
    $ErrorActionPreference = "Continue"
    if ($Quiet) {
        & $Command @Arguments *> $null
    } else {
        # 出力を戻り値に混ぜない（戻り値は終了コードだけにする）
        & $Command @Arguments | Out-Host
    }
    return $LASTEXITCODE
}

function Invoke-Checked([string]$Command, [string[]]$Arguments) {
    $code = Invoke-Native $Command $Arguments
    if ($code -ne 0) { Stop-WithError "$Command $($Arguments -join ' ') が失敗しました（終了コード $code）。" }
}

if ([string]::IsNullOrEmpty($Name)) {
    Write-Host "使い方:" -ForegroundColor Yellow
    Write-Host "  .\tools\new_repo.ps1 <repo-name> [-Public]"
    Write-Host "  .\tools\new_repo.ps1 <repo-name> -ConfigureOnly"
    exit 1
}
if ($ConfigureOnly -and $Public) { Stop-WithError "-Public は新規作成のときだけ指定できます。" }
$REPO = "$ORG/$Name"

# ---------- 手順 ----------
function Test-Name {
    if ($NAME_EXEMPT -contains $Name) { return }
    if ($Name -cnotmatch $NAME_PATTERN) {
        Write-Warn "'$Name' は命名規則（client- / prod- / int- / poc- + 小文字英数字とハイフン）に合っていません。処理は続行します。"
    }
}

function New-Repo {
    $visibility = if ($Public) { "--public" } else { "--private" }
    Write-Host "🚀 [1/6] $REPO を $ORG/$TEMPLATE から作成します（$($visibility.TrimStart('-'))）" -ForegroundColor Cyan
    Invoke-Checked "gh" @("repo", "create", $REPO, "--template", "$ORG/$TEMPLATE", $visibility)
}

function Wait-ForMain {
    Write-Host "⏳ [2/6] テンプレートのコピー完了を待ちます" -ForegroundColor Cyan
    for ($i = 1; $i -le $WAIT_RETRIES; $i++) {
        if ((Invoke-Native "gh" @("api", "repos/$REPO/git/ref/heads/main", "--silent") -Quiet) -eq 0) {
            Write-Host "   main を確認しました"
            return
        }
        Write-Host "   main がまだありません（$i/$WAIT_RETRIES）"
        Start-Sleep -Seconds $WAIT_INTERVAL
    }
    Stop-WithError "main ブランチが作成されませんでした。GitHub 上で $REPO を確認してください。"
}

function New-Develop {
    Write-Host "🌿 [3/6] main から develop を作成します" -ForegroundColor Cyan
    if ((Invoke-Native "gh" @("api", "repos/$REPO/git/ref/heads/develop", "--silent") -Quiet) -eq 0) {
        Write-Host "   develop は既にあります。スキップします"
        return
    }
    $sha = (& gh api "repos/$REPO/git/ref/heads/main" --jq ".object.sha" | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($sha)) { Stop-WithError "main の SHA を取得できませんでした。" }
    Invoke-Checked "gh" @("api", "-X", "POST", "repos/$REPO/git/refs", "-f", "ref=refs/heads/develop", "-f", "sha=$sha", "--silent")
    Write-Host "   develop を作成しました（$sha）"
}

function Set-RepoSettings {
    Write-Host "⚙️  [4/6] リポジトリを設定します（既定ブランチ develop / squash = PR タイトル / ブランチ自動削除）" -ForegroundColor Cyan
    Invoke-Checked "gh" @("api", "-X", "PATCH", "repos/$REPO",
        "-f", "default_branch=develop",
        "-F", "allow_squash_merge=true",
        "-f", "squash_merge_commit_title=PR_TITLE",
        "-f", "squash_merge_commit_message=COMMIT_MESSAGES",
        "-F", "delete_branch_on_merge=true",
        "--silent")
}

function Start-SyncLabels {
    Write-Host "🏷  [5/6] Sync Labels を起動します" -ForegroundColor Cyan
    if ((Invoke-Native "gh" @("workflow", "run", "sync-labels.yml", "--repo", $REPO, "--ref", "develop")) -eq 0) {
        Write-Host "   起動しました（結果は Actions タブで確認）"
    } else {
        Write-Warn "Sync Labels を起動できませんでした。後で Actions タブから手動実行してください。"
    }
}

function Copy-RepoToWorkspace {
    Write-Host "📥 [6/6] $WORKSPACE にクローンします" -ForegroundColor Cyan
    Set-Location $WORKSPACE
    if (Test-Path $Name) {
        Write-Warn "$(Join-Path $WORKSPACE $Name) は既にあります。クローンをスキップします。"
        return
    }
    Invoke-Checked "gh" @("repo", "clone", $REPO, $Name)
    Invoke-Checked "git" @("-C", $Name, "checkout", "develop")
}

# ---------- 実行 ----------
if (!(Get-Command gh -ErrorAction SilentlyContinue)) { Stop-WithError "GitHub CLI (gh) がインストールされていません。" }
if ((Invoke-Native "gh" @("auth", "status") -Quiet) -ne 0) {
    Stop-WithError "GitHub CLI (gh) にログインしていません。gh auth login を実行してください。"
}
Test-Name

if ($ConfigureOnly) {
    Write-Host "🔧 既存リポジトリ $REPO に初期設定を適用します" -ForegroundColor Cyan
    if ((Invoke-Native "gh" @("repo", "view", $REPO, "--json", "name") -Quiet) -ne 0) { Stop-WithError "$REPO が見つかりません。" }
} else {
    New-Repo
    Wait-ForMain
}
New-Develop
Set-RepoSettings
Start-SyncLabels
if (-not $ConfigureOnly) { Copy-RepoToWorkspace }

Write-Host "=========================================="
Write-Host "✅ 完了: https://github.com/$REPO" -ForegroundColor Green
Write-Host "=========================================="
exit 0
