# tinayrum/.github

tinayrum Organization の共通設定リポジトリです。

- **組織プロフィール**：`profile/README.md`（Organization のトップページに表示）
- **共通テンプレート**：`.github/ISSUE_TEMPLATE/`・`.github/pull_request_template.md`・`.github/labels.yml`（独自テンプレートを持たないリポジトリの既定値）
- **再利用ワークフロー（共通 CI）**：`.github/workflows/reusable-*.yml`
- **リポジトリ作成ツール**：`tools/new_repo.sh` / `tools/new_repo.ps1`
- **運用ガイド**：`docs/`（[GitHub Pages](https://tinayrum.github.io/.github/) で公開）

## 📖 運用ガイド

| ページ | 内容 |
| :--- | :--- |
| [Home](https://tinayrum.github.io/.github/) | Notion と GitHub の役割分担、全体像、リポジトリ構成、命名規則、Free プランの制約 |
| [管理者ガイド](https://tinayrum.github.io/.github/admin/) | 新規リポジトリの作り方、既存リポジトリへの後付け設定、Organization 設定 |
| [開発者ガイド](https://tinayrum.github.io/.github/developer/) | 開発ルールの要約（正本は [temp の docs/development.md](https://github.com/tinayrum/temp/blob/main/docs/development.md)） |
| [ツール仕様](https://tinayrum.github.io/.github/tools/) | `tools/new_repo` の仕様 |

## 🛠 新しいリポジトリを作る

```bash
./tools/new_repo.sh <repo-name> [--public]        # 新規作成（テンプレート tinayrum/temp から）
./tools/new_repo.sh --configure-only <repo-name>  # 既存リポジトリに初期設定だけを適用
```

PowerShell では `.\tools\new_repo.ps1 <repo-name> [-Public] [-ConfigureOnly]`。
前提は `gh`（GitHub CLI）のインストールと `gh auth login` だけです。Secret の登録は不要です。

命名規則：`client-`（受託）/ `prod-`（自社プロダクト）/ `int-`（社内）/ `poc-`（検証）。

## 🔁 共通 CI を使う

```yaml
# 各リポジトリの .github/workflows/ci.yml
jobs:
  ci:
    uses: tinayrum/.github/.github/workflows/reusable-ci.yml@main
```

| ワークフロー | 内容 |
| :--- | :--- |
| `reusable-ci.yml` | `mkdocs build --strict`、コミットメッセージ・PR タイトル検査、Docs as Code 検査 |
| `reusable-check-branch.yml` | ブランチ名 prefix とマージ先の組み合わせ検査 |
| `reusable-release-drafter.yml` | リリースノート・タグの作成（`GITHUB_TOKEN`） |

## 🚀 このリポジトリの開発

- ブランチは main のみ（develop は作らない）。`feature/`・`docs/`・`chore/` などの作業ブランチから main へ PR を出します。
- コミットと PR タイトルは `type(scope): subject`。マージは squash。
- Issue 駆動・承認ゲート・作業報告の進め方は [開発者ガイド](https://tinayrum.github.io/.github/developer/) を参照してください。

```bash
pip install -r requirements.txt
mkdocs serve                       # ガイドのプレビュー
mkdocs build --strict              # CI と同じ検査
bash tools/tests/new_repo_test.sh  # new_repo の試験
```

## ディレクトリ構成

```text
.github/
├── .github/
│   ├── ISSUE_TEMPLATE/      # 組織共通の Issue テンプレート
│   ├── workflows/           # 再利用ワークフロー（reusable-*.yml）と、このリポジトリ自身の CI
│   ├── labels.yml           # ラベル定義（Sync Labels で同期）
│   └── pull_request_template.md
├── docs/                    # 運用ガイド（MkDocs）
├── profile/README.md        # 組織トップページ
├── tools/
│   ├── new_repo.sh / .ps1   # リポジトリ作成・初期設定
│   └── tests/               # new_repo の試験
└── mkdocs.yml
```
