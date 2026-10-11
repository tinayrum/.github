# 管理者ガイド

---

## 1. 新しいリポジトリを作る

!!! warning "リポジトリは new_repo で作る"
    GitHub の画面から手で作ると、develop の作成・既定ブランチ・squash 設定・ラベル同期が漏れます。必ず `tools/new_repo` を使ってください。

1. `gh auth login` 済みであることを確認する。
2. 命名規則（[Home](index.md#naming)）に沿った名前を決める。
3. `.github` リポジトリのクローンで実行する。

=== "bash"
    ```bash
    ./tools/new_repo.sh poc-sample            # 非公開（既定）
    ./tools/new_repo.sh prod-sample --public  # 公開
    ```

=== "PowerShell"
    ```powershell
    .\tools\new_repo.ps1 poc-sample
    .\tools\new_repo.ps1 prod-sample -Public
    ```

スクリプトは「作成 → コピー待ち → develop 作成 → 設定 → ラベル同期 → クローン」を行います。詳細は[ツール仕様](tools.md)を参照してください。

作成後は、新しいリポジトリの `README.md` にある「テンプレートから作成した直後にやること」を進めます。

## 2. 既存リポジトリに後から設定する

テンプレート以外から作ったリポジトリや、設定が漏れているリポジトリには、次を実行します。

```bash
./tools/new_repo.sh --configure-only <repo-name>
```

develop の作成（既にあればスキップ）・リポジトリ設定・ラベル同期だけを行います。何度実行しても結果は同じです。

ワークフローを共通 CI に揃える場合は、temp の `.github/workflows/` にある呼び出し側のワークフロー（`ci.yml`・`check_branch.yml`・`release-drafter.yml`）をコピーします。
temp に無くなったワークフローが残っている場合は削除します。

## 3. テンプレート（temp）の更新

- 開発ルールを変えるときは、temp の `docs/development.md`（正本）を先に更新します。
- CI の中身を変えるときは、`.github` の再利用ワークフローを更新します。呼び出し側は `@main` を参照しているため、マージした時点で全リポジトリに反映されます。互換性のない変更（入力の削除・意味の変更）は避け、必要なら入力を追加して既定値で従来の動きを保ちます。
- Issue / PR テンプレートとラベル（`labels.yml`）は temp と `.github` の両方を揃えます。`.github` 側は、独自テンプレートを持たないリポジトリの既定値になります。

## 4. Organization 設定で人がやること

画面操作が必要な設定です。変更する場合は、Issue で承認を得てから行います。

| 設定 | 場所 | 内容 |
| :--- | :--- | :--- |
| 既定ラベル | Organization Settings → Repository → Repository labels | `labels.yml` と同じラベルを登録しておく（new_repo のラベル同期が失敗したときの保険） |
| Actions の許可 | Organization Settings → Actions → General | 「Allow all actions and reusable workflows」、または `tinayrum/*` と使用中の action を許可する |
| ワークフローの権限 | Organization Settings → Actions → General → Workflow permissions | 既定は「Read repository contents」のままにする。書き込みが必要なワークフローは `permissions:` で個別に付与している |
| ブランチ保護（公開リポジトリ） | 各リポジトリの Settings → Branches | 設定済み。内容と変更手順は次の「5. ブランチ保護」を参照 |
| テンプレート指定 | temp の Settings → General | 「Template repository」が有効であることを確認する |

## 5. ブランチ保護 { #branch-protection }

Free プランでも公開リポジトリならブランチ保護を使えます。次の 3 本に設定しています。

| リポジトリ / ブランチ | 必須チェック |
| :--- | :--- |
| `.github` / main | `check / Branch name and merge target`、`ci / Docs build (mkdocs --strict)`、`ci / Commit message (type(scope): subject)`、`ci / PR title (type(scope): subject)`、`tools/new_repo test` |
| `temp` / main・develop | `check / Branch name and merge target`、`ci / Docs build (mkdocs --strict)`、`ci / Commit message (type(scope): subject)`、`ci / PR title (type(scope): subject)`、`ci / Docs as Code (src/ changes need docs/)` |

共通の設定：PR 必須（承認数 0。承認は Issue の G2 で記録する）、force push 禁止、削除禁止、**管理者も例外にしない**（Do not allow bypassing / `enforce_admins`）。

```bash
# 現在の設定を確認する
gh api repos/tinayrum/<repo>/branches/<branch>/protection \
  --jq '{admins: .enforce_admins.enabled, checks: .required_status_checks.contexts}'
```

### 緊急時に管理者が直接 push する

管理者も保護の対象なので、直接 push が必要なときは一時的に解除します。解除も Issue で承認を得てから行い、作業後すぐに戻します。

```bash
gh api -X DELETE repos/tinayrum/<repo>/branches/<branch>/protection/enforce_admins  # 解除
# …作業…
gh api -X POST repos/tinayrum/<repo>/branches/<branch>/protection/enforce_admins    # 戻す
```

### 必須チェックが「待機中（Expected）」のまま止まらないために

必須チェックは、その名前のチェックが報告されないと待機中のままになり、マージできません。

- **job 名を変えるとき**：呼び出し側 job 名（`ci`・`check`）と再利用ワークフロー側の job 名（`name:`）を合わせたものがチェック名になります（例：`ci / Docs build (mkdocs --strict)`）。どちらかを変える場合は、
    1. 変更を入れた PR で新しい名前のチェックが 1 回実行されるのを待つ
    2. 必須チェックを新しい名前に更新する（`gh api -X PATCH …/protection/required_status_checks -F 'contexts[]=…'`）
    3. それから PR をマージする

    再利用ワークフローの job 名を変えると、呼び出している保護付きのリポジトリ（temp）すべてに影響します。
- **`paths` / `paths-ignore` を付けないこと**：必須チェックを出すワークフロー（`ci.yml`・`check_branch.yml`）に付けると、該当しない PR ではワークフロー自体が起動せず、待機中のまま止まります。対象を絞りたい場合は、ワークフローは毎回起動させ、job の中で変更ファイルを調べて早期に成功終了させます。
- `if:` で job ごとスキップする（例：develop → main の PR での commit-lint）のは問題ありません。スキップされた job は成功として扱われます。

## 6. Free プランの制約

非公開リポジトリでは、ブランチ保護・Organization Secret・GitHub Pages が使えません。対策は [Home の「Free プランの制約と対策」](index.md#free-plan) にまとめています。

## トラブルシューティング

!!! warning "認証エラー"
    `gh auth status` で状態を確認し、必要なら `gh auth login` をやり直してください。リポジトリ作成には Organization でのリポジトリ作成権限が必要です。

!!! warning "Sync Labels が起動できない"
    作成直後は Actions の準備が終わっておらず失敗することがあります。リポジトリの Actions タブから「Sync Labels」を手動実行してください。

!!! warning "main ブランチが作成されませんでした"
    テンプレートのコピーに時間がかかっています。GitHub 上でリポジトリを確認し、main ができていれば `--configure-only` で続きの設定を行ってください。
