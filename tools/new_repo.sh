#!/usr/bin/env bash
# ==========================================
# tinayrum のリポジトリ立ち上げスクリプト
# ==========================================
#
# 使い方:
#   ./tools/new_repo.sh <repo-name> [--public]   テンプレート(temp)から新規作成して初期設定する
#   ./tools/new_repo.sh --configure-only <repo-name>
#                                                既存リポジトリに初期設定（手順 3〜5）だけを適用する
#
# 手順:
#   1. gh repo create tinayrum/<name> --template tinayrum/temp（既定は非公開）
#   2. テンプレートのコピー完了を待つ（main ができるまでリトライ）
#   3. main から develop を作成
#   4. 既定ブランチ develop / squash 許可（コミット名 = PR タイトル）/ マージ後にブランチを自動削除
#   5. Sync Labels を起動（失敗しても続行して警告）
#   6. ワークスペース直下にクローンし、develop をチェックアウト
#
# 環境変数（任意）:
#   NEW_REPO_ORG            Organization 名（既定: tinayrum）
#   NEW_REPO_TEMPLATE       テンプレートリポジトリ名（既定: temp）
#   NEW_REPO_WORKSPACE      クローン先（既定: このスクリプトの 2 つ上のディレクトリ）
#   NEW_REPO_WAIT_RETRIES   コピー待ちのリトライ回数（既定: 20）
#   NEW_REPO_WAIT_INTERVAL  コピー待ちの間隔・秒（既定: 3）
#
# PAT・Secret は使わない。gh にログインしたユーザーの権限で実行する。

set -euo pipefail

ORG="${NEW_REPO_ORG:-tinayrum}"
TEMPLATE="${NEW_REPO_TEMPLATE:-temp}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="${NEW_REPO_WORKSPACE:-$SCRIPT_DIR/../..}"
WAIT_RETRIES="${NEW_REPO_WAIT_RETRIES:-20}"
WAIT_INTERVAL="${NEW_REPO_WAIT_INTERVAL:-3}"

# 命名規則（client- 受託 / prod- 自社プロダクト / int- 社内 / poc- 検証）。管理用リポジトリは対象外
NAME_PATTERN='^(client|prod|int|poc)-[a-z0-9]+(-[a-z0-9]+)*$'
NAME_EXEMPT=(".github" "temp" "infra")

usage() {
    cat <<EOF
使い方:
  $0 <repo-name> [--public]
  $0 --configure-only <repo-name>
EOF
    exit 1
}

warn() { echo "⚠️  $*" >&2; }
die() { echo "❌ $*" >&2; exit 1; }

# ---------- 引数 ----------
MODE="create"
VISIBILITY="--private"
NAME=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --public) VISIBILITY="--public" ;;
        --configure-only) MODE="configure" ;;
        -h|--help) usage ;;
        -*) echo "不明なオプション: $1" >&2; usage ;;
        *)
            [[ -n "$NAME" ]] && usage
            NAME="$1"
            ;;
    esac
    shift
done
[[ -z "$NAME" ]] && usage
if [[ "$MODE" == "configure" && "$VISIBILITY" == "--public" ]]; then
    die "--public は新規作成のときだけ指定できます。"
fi
REPO="$ORG/$NAME"

check_name() {
    local exempt
    for exempt in "${NAME_EXEMPT[@]}"; do
        [[ "$NAME" == "$exempt" ]] && return 0
    done
    if [[ ! "$NAME" =~ $NAME_PATTERN ]]; then
        warn "'$NAME' は命名規則（client- / prod- / int- / poc- + 小文字英数字とハイフン）に合っていません。処理は続行します。"
    fi
}

# ---------- 手順 ----------
create_repo() {
    echo "🚀 [1/6] $REPO を $ORG/$TEMPLATE から作成します（${VISIBILITY#--}）"
    gh repo create "$REPO" --template "$ORG/$TEMPLATE" "$VISIBILITY"
}

wait_for_main() {
    echo "⏳ [2/6] テンプレートのコピー完了を待ちます"
    local i
    for ((i = 1; i <= WAIT_RETRIES; i++)); do
        if gh api "repos/$REPO/git/ref/heads/main" --silent >/dev/null 2>&1; then
            echo "   main を確認しました"
            return 0
        fi
        echo "   main がまだありません（$i/$WAIT_RETRIES）"
        sleep "$WAIT_INTERVAL"
    done
    die "main ブランチが作成されませんでした。GitHub 上で $REPO を確認してください。"
}

create_develop() {
    echo "🌿 [3/6] main から develop を作成します"
    if gh api "repos/$REPO/git/ref/heads/develop" --silent >/dev/null 2>&1; then
        echo "   develop は既にあります。スキップします"
        return 0
    fi
    local sha
    sha="$(gh api "repos/$REPO/git/ref/heads/main" --jq '.object.sha')"
    gh api -X POST "repos/$REPO/git/refs" -f ref="refs/heads/develop" -f sha="$sha" --silent
    echo "   develop を作成しました（$sha）"
}

configure_repo() {
    echo "⚙️  [4/6] リポジトリを設定します（既定ブランチ develop / squash = PR タイトル / ブランチ自動削除）"
    gh api -X PATCH "repos/$REPO" \
        -f default_branch=develop \
        -F allow_squash_merge=true \
        -f squash_merge_commit_title=PR_TITLE \
        -f squash_merge_commit_message=COMMIT_MESSAGES \
        -F delete_branch_on_merge=true \
        --silent
}

sync_labels() {
    echo "🏷  [5/6] Sync Labels を起動します"
    if gh workflow run sync-labels.yml --repo "$REPO" --ref develop; then
        echo "   起動しました（結果は Actions タブで確認）"
    else
        warn "Sync Labels を起動できませんでした。後で Actions タブから手動実行してください。"
    fi
}

clone_repo() {
    echo "📥 [6/6] $WORKSPACE にクローンします"
    cd "$WORKSPACE"
    if [[ -e "$NAME" ]]; then
        warn "$(pwd)/$NAME は既にあります。クローンをスキップします。"
        return 0
    fi
    gh repo clone "$REPO" "$NAME"
    git -C "$NAME" checkout develop
}

# ---------- 実行 ----------
gh auth status >/dev/null 2>&1 || die "GitHub CLI (gh) にログインしていません。gh auth login を実行してください。"
check_name

if [[ "$MODE" == "create" ]]; then
    create_repo
    wait_for_main
else
    echo "🔧 既存リポジトリ $REPO に初期設定を適用します"
    gh repo view "$REPO" --json name >/dev/null || die "$REPO が見つかりません。"
fi
create_develop
configure_repo
sync_labels
[[ "$MODE" == "create" ]] && clone_repo

echo "=========================================="
echo "✅ 完了: https://github.com/$REPO"
echo "=========================================="
