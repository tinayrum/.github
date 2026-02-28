
# 開発者向けガイド (Developer Handbook)

本ガイドは「Portal+App構成」および「App単体構成」の両方に対応しています。
どちらのリポジトリでも、基本的な開発ルール・フローは共通です。

## 📝 ゴールデンルール
1. **Docs as Code**: コードを修正したら、同じPRで必ずドキュメント (`docs/`) も修正する。
2. **Naming**: ブランチ名のPrefix (`feature/`, `bugfix/`) を守る。
3. **No Direct Push**: `main` ブランチへの直接Pushは禁止。必ずPRを経由する。

## 🔄 日々の開発フロー

### 1. ブランチ作成
```bash
git checkout -b feature/login-screen
```

### 2. 実装 & ドキュメント更新

ソースコードの修正に合わせて、`docs/index.md` や仕様書を更新します。

```bash
# コードとドキュメントはセットでコミット
git add src/login.ts docs/specs.md
git commit -m "feat: login implementation and docs update"
```

### 3. PR作成 & マージ

GitHub上でPRを作成します。

- CI(Lint/Test) が通っていることを確認。
- Portal+App構成の場合は、マージ後に自動的にPortalへ同期されます。
- App単体構成の場合は、マージ後にAppリポジトリのみが更新されます。


## 📂 ディレクトリ構成例

### Portal+App構成
```tree
RepoRoot/
├── .github/      # CI設定 (触らない)
├── src/          # ソースコード
├── docs/         # ★ここにドキュメントを書く
│   ├── index.md
│   └── images/
└── mkdocs.yml    # ドキュメント設定
```

### App単体構成
```tree
RepoRoot/
├── src/          # ソースコード
├── docs/         # ドキュメント
│   ├── index.md
│   └── images/
└── mkdocs.yml    # ドキュメント設定
```

## 📌 注意点

### 🏷 ブランチ命名規則

自動化ツールがバージョンアップの種類を判別できるよう、以下のPrefixを厳守してください。  
マージ完了後のブランチは、GitHubの設定により、**即時削除**されます。

| Prefix | 用途 | SemVer影響 | 例 |
| :--- | :--- | :--- | :--- |
| `feature/` | 新機能追加 | Minor | `feature/add-login-function` |
| `bugfix/` | バグ修正 | Patch | `bugfix/fix-crash-on-startup` |
| `hotfix/` | 緊急修正 | Patch | `hotfix/fix-security-vulnerability` |
| `release/` | リリース準備 | Patch/Minor | `release/v1.2.0-prep` |
| `docs/` | ドキュメント更新のみ | Patch | `docs/update-api-docs` |
| `chore/` | その他メンテナンス | Patch | `chore/update-dependencies` |

### 🚫 直接Push禁止

`main` ブランチへの直接Pushは禁止されています。必ずPRを経由してください。

### ソースコード内のコメントについて

- コード内のコメントは、**英語 or 日本語**で記述してください。
- コメントには、必ず接頭辞をつけてください。

| Prefix | 用途 | 例 |
| :--- | :--- | :--- |
| TODO | 今後のタスク | `// TODO: Refactor this function` |
| BUG | バグの説明 | `// BUG: This causes a memory leak` |
| HACK | 一時的な対処 | `// HACK: This is a temporary workaround` |
| NOTE | 補足説明 | `// NOTE: This is an important detail` |
| WARN | 注意点 | `// WARN: This is a risky operation` |
| PERF | パフォーマンス関連 | `// PERF: This is a performance bottleneck` |
| SEC | セキュリティ関連 | `// SEC: This is a potential security vulnerability` |
| DEV | 開発者向けの情報 | `// DEV: This is for developers only` |