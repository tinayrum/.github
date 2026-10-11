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
| ブランチ保護（公開リポジトリ） | 各リポジトリの Settings → Branches | `.github` と `temp` の main に「PR 必須」「force push 禁止」「CI 必須」を設定する |
| テンプレート指定 | temp の Settings → General | 「Template repository」が有効であることを確認する |

## 5. Free プランの制約

非公開リポジトリでは、ブランチ保護・Organization Secret・GitHub Pages が使えません。対策は [Home の「Free プランの制約と対策」](index.md#free-plan) にまとめています。

## トラブルシューティング

!!! warning "認証エラー"
    `gh auth status` で状態を確認し、必要なら `gh auth login` をやり直してください。リポジトリ作成には Organization でのリポジトリ作成権限が必要です。

!!! warning "Sync Labels が起動できない"
    作成直後は Actions の準備が終わっておらず失敗することがあります。リポジトリの Actions タブから「Sync Labels」を手動実行してください。

!!! warning "main ブランチが作成されませんでした"
    テンプレートのコピーに時間がかかっています。GitHub 上でリポジトリを確認し、main ができていれば `--configure-only` で続きの設定を行ってください。
