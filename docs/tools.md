# ツール仕様

---

`tools/` には、リポジトリの立ち上げを自動化するスクリプトを置いています。

| スクリプト | 概要 |
| :--- | :--- |
| `tools/new_repo.sh` | テンプレート `tinayrum/temp` から新規リポジトリを作成し、初期設定する（bash） |
| `tools/new_repo.ps1` | 同上（PowerShell。Windows PowerShell 5.1 / PowerShell 7） |
| `tools/tests/new_repo_test.sh` / `.ps1` | 上記の試験（gh をスタブにして呼び出し順序を確認） |

PAT や Secret は使いません。`gh` にログインしたユーザーの権限で動きます。

## new_repo

### 使い方

=== "bash"
    ```bash
    # 新規作成（既定は非公開）
    ./tools/new_repo.sh poc-sample
    # 公開リポジトリとして作成
    ./tools/new_repo.sh prod-sample --public
    # 既存リポジトリに初期設定（手順 3〜5）だけを適用
    ./tools/new_repo.sh --configure-only poc-sample
    ```

=== "PowerShell"
    ```powershell
    .\tools\new_repo.ps1 poc-sample
    .\tools\new_repo.ps1 prod-sample -Public
    .\tools\new_repo.ps1 poc-sample -ConfigureOnly
    ```

### 前提

- `gh`（GitHub CLI）がインストールされ、`gh auth login` 済みであること
- 実行ユーザーが tinayrum でリポジトリを作成できる権限を持っていること
- `tinayrum/temp` がテンプレートリポジトリであること

### 処理の流れ

| # | 処理 | 使う API / コマンド | 失敗したとき |
| :--- | :--- | :--- | :--- |
| 1 | テンプレートから作成 | `gh repo create tinayrum/<name> --template tinayrum/temp --private`（`--public` 指定時は公開） | 停止 |
| 2 | コピー完了を待つ | `GET repos/{repo}/git/ref/heads/main` を、成功するまでリトライ（既定 3 秒 × 20 回） | 停止 |
| 3 | develop を作成 | `GET .../git/ref/heads/develop` で有無を確認し、なければ main の SHA で `POST .../git/refs` | 停止（既にあればスキップ） |
| 4 | リポジトリ設定 | `PATCH repos/{repo}`：`default_branch=develop`、`allow_squash_merge=true`、`squash_merge_commit_title=PR_TITLE`、`squash_merge_commit_message=COMMIT_MESSAGES`、`delete_branch_on_merge=true` | 停止 |
| 5 | ラベル同期 | `gh workflow run sync-labels.yml --ref develop` | 警告して続行（後で Actions タブから手動実行） |
| 6 | クローン | ワークスペース直下に `gh repo clone`、`git checkout develop` | 停止（同名ディレクトリがあればスキップ） |

`--configure-only` / `-ConfigureOnly` では、リポジトリの存在を確認したうえで 3〜5 だけを実行します。何度実行しても結果は同じです。

!!! note "ブランチの自動削除と develop"
    既定ブランチは自動削除の対象外なので、`develop` → `main` の PR をマージしても develop は消えません。
    `release/*`・`hotfix/*` は main へのマージ後に消えるため、develop への戻しの PR は main へのマージ前に作っておきます（消えた場合は PR 画面の「Restore branch」で戻せます）。

### 命名規則のチェック

名前が `^(client|prod|int|poc)-[a-z0-9]+(-[a-z0-9]+)*$` に合わない場合は警告を出します。処理は止めません。
管理用リポジトリ（`.github`・`temp`・`infra`）は対象外です。

| Prefix | 用途 | 例 |
| :--- | :--- | :--- |
| `client-` | 受託開発 | `client-sample-app` |
| `prod-` | 自社プロダクト | `prod-sample` |
| `int-` | 社内ツール | `int-sample-tool` |
| `poc-` | 検証・PoC | `poc-sample` |

### 環境変数（任意）

| 変数 | 既定値 | 用途 |
| :--- | :--- | :--- |
| `NEW_REPO_ORG` | `tinayrum` | Organization 名 |
| `NEW_REPO_TEMPLATE` | `temp` | テンプレートリポジトリ名 |
| `NEW_REPO_WORKSPACE` | スクリプトの 2 つ上のディレクトリ | クローン先 |
| `NEW_REPO_WAIT_RETRIES` | `20` | コピー待ちのリトライ回数 |
| `NEW_REPO_WAIT_INTERVAL` | `3` | コピー待ちの間隔（秒） |

### 試験

```bash
bash tools/tests/new_repo_test.sh
pwsh -NoProfile -File tools/tests/new_repo_test.ps1             # PowerShell 7
powershell -NoProfile -File tools\tests\new_repo_test.ps1       # Windows PowerShell 5.1
```

`gh` と `git` をスタブに差し替え、新規作成・`--public`・後付け設定・命名規則の警告・コピー待ちのタイムアウト・引数の誤りの 6 ケースで、呼び出し順序と終了コードを確認します。
