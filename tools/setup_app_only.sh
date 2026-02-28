git commit -m "Initial commit for app-only repository"
git push origin main

#!/bin/bash
# app単体リポジトリ作成スクリプト (テンプレート・PAT・Secret対応)

set -e

# 設定値
ORG_NAME="tinayrum"
TEMPLATE_APP="template_app"

if [ $# -ne 1 ]; then
  echo "Usage: $0 <AppName>"
  exit 1
fi

APP_NAME="$1"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PAT_FILE="$SCRIPT_DIR/.secret_pat"

# GitHub CLI ログイン確認
if ! gh auth status >/dev/null 2>&1; then
    echo "エラー: GitHub CLI (gh) にログインしていません。"
    exit 1
fi

gh auth setup-git

# PAT取得
if [ -f "$PAT_FILE" ]; then
    ADMIN_TOKEN=$(cat "$PAT_FILE" | tr -d '\r\n')
    if [ -n "$ADMIN_TOKEN" ]; then
        echo "✅ .secret_patからPATを取得しました。"
    fi
fi

if [ -z "$ADMIN_TOKEN" ]; then
    echo "--------------------------------------------------"
    echo "管理者用PAT(Personal Access Token)を入力してください。"
    echo "--------------------------------------------------"
    read -sp "PAT: " ADMIN_TOKEN
    echo ""
fi

if [ -z "$ADMIN_TOKEN" ]; then
    echo "エラー: PATが取得できませんでした。"
    exit 1
fi

# Appリポジトリ作成 (テンプレートから)
echo "Creating App Repository: $APP_NAME..."
gh repo create "$ORG_NAME/$APP_NAME" --template "$ORG_NAME/$TEMPLATE_APP" --private --confirm

# Secret登録 (workflow用)
echo "Setting Secrets..."
gh secret set ORG_ADMIN_TOKEN -b "$ADMIN_TOKEN" --repo "$ORG_NAME/$APP_NAME"

# クローンして初期ファイル追加
gh repo clone "$ORG_NAME/$APP_NAME"
cd "$APP_NAME"
mkdir -p docs tools
echo "# $APP_NAME" > README.md
echo "## App単体リポジトリ" >> README.md
touch docs/admin.md docs/developer.md docs/tools.md
cp "$SCRIPT_DIR/setup_project.sh" tools/
echo "$ADMIN_TOKEN" > tools/.secret_pat

git add .
git commit -m "Initial commit for app-only repository"
git push origin main

echo "=========================================="
echo "✅ App-only repository '$APP_NAME' created and initialized."
echo "  App: https://github.com/$ORG_NAME/$APP_NAME"
echo "=========================================="
