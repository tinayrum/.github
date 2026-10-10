#!/usr/bin/env bash
# new_repo.sh の試験。gh と git をスタブに差し替え、呼び出す API の順序を確認する。
# 実際の GitHub には接続しない。
#
#   bash tools/tests/new_repo_test.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/tools/new_repo.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ---------- スタブ ----------
mkdir -p "$WORK/bin"
cat > "$WORK/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "gh $*" >> "$STUB_LOG"
case "$*" in
    "auth status") exit 0 ;;
    "repo create "*) exit 0 ;;
    "repo view "*) exit "${STUB_REPO_MISSING:-0}" ;;
    "repo clone "*) mkdir -p "$4"; exit 0 ;;
    "api repos/"*"/git/ref/heads/main --silent")
        # STUB_MAIN_DELAY 回目までは「まだない」を返す
        n=$(( $(cat "$STUB_COUNTER" 2>/dev/null || echo 0) + 1 ))
        echo "$n" > "$STUB_COUNTER"
        [[ $n -gt ${STUB_MAIN_DELAY:-0} ]] && exit 0 || exit 1 ;;
    "api repos/"*"/git/ref/heads/main --jq .object.sha") echo "abc123"; exit 0 ;;
    "api repos/"*"/git/ref/heads/develop --silent") exit "${STUB_DEVELOP_MISSING:-1}" ;;
    "api -X POST "*|"api -X PATCH "*) exit 0 ;;
    "workflow run "*) exit "${STUB_WORKFLOW_FAIL:-0}" ;;
esac
echo "unexpected gh call: $*" >&2
exit 99
EOF
cat > "$WORK/bin/git" <<'EOF'
#!/usr/bin/env bash
echo "git $*" >> "$STUB_LOG"
EOF
chmod +x "$WORK/bin/gh" "$WORK/bin/git"

export PATH="$WORK/bin:$PATH"
export NEW_REPO_WORKSPACE="$WORK/ws"
export NEW_REPO_WAIT_INTERVAL=0
export STUB_LOG="$WORK/calls.log"
export STUB_COUNTER="$WORK/counter"

FAILED=0
run_case() {
    # run_case <名前> <期待する終了コード> <期待する呼び出し> <stderr に含まれるべき文字列|-> -- <引数...>
    local name="$1" want_code="$2" want_calls="$3" want_err="$4"
    shift 5
    rm -rf "$NEW_REPO_WORKSPACE" "$STUB_COUNTER"
    mkdir -p "$NEW_REPO_WORKSPACE"
    : > "$STUB_LOG"
    local code=0
    bash "$SCRIPT" "$@" > "$WORK/out" 2> "$WORK/err" || code=$?
    local ok=1
    [[ "$code" == "$want_code" ]] || { echo "  終了コード: 期待 $want_code / 実際 $code"; ok=0; }
    if ! diff -u <([[ -n "$want_calls" ]] && printf '%s\n' "$want_calls") "$STUB_LOG" > "$WORK/diff"; then
        echo "  呼び出し順序が違います:"; sed 's/^/    /' "$WORK/diff"; ok=0
    fi
    if [[ "$want_err" != "-" ]] && ! grep -qF -- "$want_err" "$WORK/err"; then
        echo "  stderr に '$want_err' がありません:"; sed 's/^/    /' "$WORK/err"; ok=0
    fi
    if [[ "$want_err" == "-" && -s "$WORK/err" ]]; then
        echo "  stderr が空ではありません:"; sed 's/^/    /' "$WORK/err"; ok=0
    fi
    if [[ $ok -eq 1 ]]; then echo "✅ $name"; else echo "❌ $name"; FAILED=1; fi
}

R="repos/tinayrum/poc-sample"
PATCH="gh api -X PATCH $R -f default_branch=develop -F allow_squash_merge=true -f squash_merge_commit_title=PR_TITLE -f squash_merge_commit_message=COMMIT_MESSAGES -F delete_branch_on_merge=true --silent"

# 1. 新規作成（非公開）。main のコピー待ちを 2 回リトライする
STUB_MAIN_DELAY=2 run_case "新規作成: 手順 1〜6 を順に呼ぶ" 0 "gh auth status
gh repo create tinayrum/poc-sample --template tinayrum/temp --private
gh api $R/git/ref/heads/main --silent
gh api $R/git/ref/heads/main --silent
gh api $R/git/ref/heads/main --silent
gh api $R/git/ref/heads/develop --silent
gh api $R/git/ref/heads/main --jq .object.sha
gh api -X POST $R/git/refs -f ref=refs/heads/develop -f sha=abc123 --silent
$PATCH
gh workflow run sync-labels.yml --repo tinayrum/poc-sample --ref develop
gh repo clone tinayrum/poc-sample poc-sample
git -C poc-sample checkout develop" - -- poc-sample

# 2. --public
run_case "新規作成: --public を渡す" 0 "gh auth status
gh repo create tinayrum/poc-sample --template tinayrum/temp --public
gh api $R/git/ref/heads/main --silent
gh api $R/git/ref/heads/develop --silent
gh api $R/git/ref/heads/main --jq .object.sha
gh api -X POST $R/git/refs -f ref=refs/heads/develop -f sha=abc123 --silent
$PATCH
gh workflow run sync-labels.yml --repo tinayrum/poc-sample --ref develop
gh repo clone tinayrum/poc-sample poc-sample
git -C poc-sample checkout develop" - -- poc-sample --public

# 3. 後付け設定。develop は既にあり、Sync Labels は失敗する（警告して続行）
STUB_DEVELOP_MISSING=0 STUB_WORKFLOW_FAIL=1 run_case "後付け設定: 手順 3〜5 のみ・ラベル同期の失敗は警告" 0 "gh auth status
gh repo view tinayrum/poc-sample --json name
gh api $R/git/ref/heads/develop --silent
$PATCH
gh workflow run sync-labels.yml --repo tinayrum/poc-sample --ref develop" "Sync Labels を起動できませんでした" -- --configure-only poc-sample

# 4. 命名規則に合わない名前は警告のみ
R="repos/tinayrum/MyApp"
STUB_DEVELOP_MISSING=0 run_case "命名規則違反: 警告して続行" 0 "gh auth status
gh repo view tinayrum/MyApp --json name
gh api $R/git/ref/heads/develop --silent
gh api -X PATCH $R -f default_branch=develop -F allow_squash_merge=true -f squash_merge_commit_title=PR_TITLE -f squash_merge_commit_message=COMMIT_MESSAGES -F delete_branch_on_merge=true --silent
gh workflow run sync-labels.yml --repo tinayrum/MyApp --ref develop" "命名規則" -- --configure-only MyApp

# 5. コピーが終わらない場合は止まる
NEW_REPO_WAIT_RETRIES=2 STUB_MAIN_DELAY=9 run_case "コピー待ちのタイムアウトで停止" 1 "gh auth status
gh repo create tinayrum/poc-sample --template tinayrum/temp --private
gh api repos/tinayrum/poc-sample/git/ref/heads/main --silent
gh api repos/tinayrum/poc-sample/git/ref/heads/main --silent" "main ブランチが作成されませんでした" -- poc-sample

# 6. 引数の誤り
run_case "--configure-only と --public の併用は拒否" 1 "" "--public は新規作成のときだけ" -- --configure-only poc-sample --public

exit $FAILED
