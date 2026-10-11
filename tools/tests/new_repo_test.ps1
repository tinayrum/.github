# new_repo.ps1 の試験。gh と git を関数のスタブに差し替え、呼び出す API の順序を確認する。
# 実際の GitHub には接続しない。Windows PowerShell 5.1 / PowerShell 7 のどちらでも動く。
#
#   powershell -NoProfile -File tools\tests\new_repo_test.ps1
#   pwsh -NoProfile -File tools/tests/new_repo_test.ps1

$ErrorActionPreference = "Stop"
$ROOT = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$SCRIPT = Join-Path (Join-Path $ROOT "tools") "new_repo.ps1"
$WORK = Join-Path ([IO.Path]::GetTempPath()) ("new_repo_test_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $WORK | Out-Null

# ---------- スタブ（関数は外部コマンドより優先される） ----------
$global:Calls = New-Object System.Collections.Generic.List[string]
$global:Stub = @{}

function global:gh {
    $line = "gh " + ($args -join " ")
    $global:Calls.Add($line)
    $global:LASTEXITCODE = 0
    $a = $args -join " "
    switch -Regex ($a) {
        '^auth status$' { return }
        '^repo create ' { return }
        '^repo view ' { $global:LASTEXITCODE = $global:Stub.RepoMissing; return }
        '^repo clone ' { New-Item -ItemType Directory -Path $args[3] -Force | Out-Null; return }
        '^api repos/.*/git/ref/heads/main --silent$' {
            $global:Stub.MainCount++
            if ($global:Stub.MainCount -le $global:Stub.MainDelay) { $global:LASTEXITCODE = 1 }
            return
        }
        '^api repos/.*/git/ref/heads/main --jq \.object\.sha$' { "abc123"; return }
        '^api repos/.*/git/ref/heads/develop --silent$' { $global:LASTEXITCODE = $global:Stub.DevelopMissing; return }
        '^api -X (POST|PATCH) ' { return }
        '^workflow run ' { $global:LASTEXITCODE = $global:Stub.WorkflowFail; return }
    }
    throw "unexpected gh call: $a"
}
function global:git { $global:Calls.Add("git " + ($args -join " ")); $global:LASTEXITCODE = 0 }

$env:NEW_REPO_WORKSPACE = Join-Path $WORK "ws"
$env:NEW_REPO_WAIT_INTERVAL = "0"
$failed = $false

function Invoke-Case {
    param([string]$Title, [int]$WantCode, [string[]]$WantCalls, [string]$WantOutput, [hashtable]$ScriptArgs, [hashtable]$StubOptions = @{})
    $global:Calls.Clear()
    $global:Stub = @{ MainCount = 0; MainDelay = 0; DevelopMissing = 1; WorkflowFail = 0; RepoMissing = 0 }
    foreach ($k in $StubOptions.Keys) { $global:Stub[$k] = $StubOptions[$k] }
    if (Test-Path $env:NEW_REPO_WORKSPACE) { Remove-Item -Recurse -Force $env:NEW_REPO_WORKSPACE }
    New-Item -ItemType Directory -Path $env:NEW_REPO_WORKSPACE | Out-Null

    $here = Get-Location
    $global:LASTEXITCODE = 0
    $output = & $SCRIPT @ScriptArgs *>&1 | Out-String
    $code = $LASTEXITCODE
    Set-Location $here

    $problems = @()
    if ($code -ne $WantCode) { $problems += "終了コード: 期待 $WantCode / 実際 $code" }
    $got = @($global:Calls)
    if (($got -join "`n") -ne ($WantCalls -join "`n")) {
        $problems += "呼び出し順序が違います:`n  期待:`n    " + ($WantCalls -join "`n    ") + "`n  実際:`n    " + ($got -join "`n    ")
    }
    if ($WantOutput -and -not $output.Contains($WantOutput)) { $problems += "出力に '$WantOutput' がありません:`n$output" }

    if ($problems.Count -eq 0) {
        Write-Host "✅ $Title"
    } else {
        Write-Host "❌ $Title"
        $problems | ForEach-Object { Write-Host "  $_" }
        $script:failed = $true
    }
}

$R = "repos/tinayrum/poc-sample"
$PATCH = "gh api -X PATCH $R -f default_branch=develop -F allow_squash_merge=true -f squash_merge_commit_title=PR_TITLE -f squash_merge_commit_message=COMMIT_MESSAGES -F delete_branch_on_merge=true --silent"

try {
    Invoke-Case "新規作成: 手順 1〜6 を順に呼ぶ" 0 @(
        "gh auth status",
        "gh repo create tinayrum/poc-sample --template tinayrum/temp --private",
        "gh api $R/git/ref/heads/main --silent",
        "gh api $R/git/ref/heads/main --silent",
        "gh api $R/git/ref/heads/main --silent",
        "gh api $R/git/ref/heads/develop --silent",
        "gh api $R/git/ref/heads/main --jq .object.sha",
        "gh api -X POST $R/git/refs -f ref=refs/heads/develop -f sha=abc123 --silent",
        $PATCH,
        "gh workflow run sync-labels.yml --repo tinayrum/poc-sample --ref develop",
        "gh repo clone tinayrum/poc-sample poc-sample",
        "git -C poc-sample checkout develop"
    ) "完了" @{ Name = "poc-sample" } @{ MainDelay = 2 }

    Invoke-Case "新規作成: -Public を渡す" 0 @(
        "gh auth status",
        "gh repo create tinayrum/poc-sample --template tinayrum/temp --public",
        "gh api $R/git/ref/heads/main --silent",
        "gh api $R/git/ref/heads/develop --silent",
        "gh api $R/git/ref/heads/main --jq .object.sha",
        "gh api -X POST $R/git/refs -f ref=refs/heads/develop -f sha=abc123 --silent",
        $PATCH,
        "gh workflow run sync-labels.yml --repo tinayrum/poc-sample --ref develop",
        "gh repo clone tinayrum/poc-sample poc-sample",
        "git -C poc-sample checkout develop"
    ) "完了" @{ Name = "poc-sample"; Public = $true }

    Invoke-Case "後付け設定: 手順 3〜5 のみ・ラベル同期の失敗は警告" 0 @(
        "gh auth status",
        "gh repo view tinayrum/poc-sample --json name",
        "gh api $R/git/ref/heads/develop --silent",
        $PATCH,
        "gh workflow run sync-labels.yml --repo tinayrum/poc-sample --ref develop"
    ) "Sync Labels を起動できませんでした" @{ Name = "poc-sample"; ConfigureOnly = $true } @{ DevelopMissing = 0; WorkflowFail = 1 }

    Invoke-Case "命名規則違反: 警告して続行" 0 @(
        "gh auth status",
        "gh repo view tinayrum/MyApp --json name",
        "gh api repos/tinayrum/MyApp/git/ref/heads/develop --silent",
        "gh api -X PATCH repos/tinayrum/MyApp -f default_branch=develop -F allow_squash_merge=true -f squash_merge_commit_title=PR_TITLE -f squash_merge_commit_message=COMMIT_MESSAGES -F delete_branch_on_merge=true --silent",
        "gh workflow run sync-labels.yml --repo tinayrum/MyApp --ref develop"
    ) "命名規則" @{ Name = "MyApp"; ConfigureOnly = $true } @{ DevelopMissing = 0 }

    $env:NEW_REPO_WAIT_RETRIES = "2"
    Invoke-Case "コピー待ちのタイムアウトで停止" 1 @(
        "gh auth status",
        "gh repo create tinayrum/poc-sample --template tinayrum/temp --private",
        "gh api $R/git/ref/heads/main --silent",
        "gh api $R/git/ref/heads/main --silent"
    ) "main ブランチが作成されませんでした" @{ Name = "poc-sample" } @{ MainDelay = 9 }
    Remove-Item Env:\NEW_REPO_WAIT_RETRIES

    Invoke-Case "-ConfigureOnly と -Public の併用は拒否" 1 @() "-Public は新規作成のときだけ" @{ Name = "poc-sample"; ConfigureOnly = $true; Public = $true }
} finally {
    Remove-Item -Recurse -Force $WORK
}

if ($failed) { exit 1 }
exit 0
