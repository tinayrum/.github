# Tinayrum Solutions

Tinayrum Solutions の GitHub Organization です。

## 🧭 Notion と GitHub の役割分担

| 道具 | 担当すること |
| :--- | :--- |
| **Notion** | 案件・タスク・作業ログ・文書・ナレッジの管理 |
| **GitHub** | コード、開発タスク（Issue）、リポジトリ内のドキュメント（Docs as Code） |

## 📦 リポジトリ構成

| リポジトリ | 役割 |
| :--- | :--- |
| [`.github`](https://github.com/tinayrum/.github) | 組織共通の Issue / PR テンプレート、再利用ワークフロー（共通 CI）、リポジトリ作成ツール、運用ガイド |
| [`temp`](https://github.com/tinayrum/temp) | テンプレートリポジトリ。新しいリポジトリはここから作る |
| `client-*` / `prod-*` / `int-*` / `poc-*` | 受託 / 自社プロダクト / 社内 / 検証 のリポジトリ |

## 🚀 新しいリポジトリを始める

```bash
# tinayrum/.github をクローンして実行（gh auth login 済みであること）
./tools/new_repo.sh poc-sample
```

テンプレート `temp` から作成し、develop ブランチ・リポジトリ設定・ラベルまで整えます。
詳しくは [管理者ガイド](https://tinayrum.github.io/.github/admin/) を参照してください。

## 📚 運用ガイド

- [運用ガイド（GitHub Pages）](https://tinayrum.github.io/.github/) — 全体像・命名規則・Free プランの制約
- [開発者ガイド](https://tinayrum.github.io/.github/developer/) — Issue 駆動・承認ゲート・ブランチ・コミット
- [管理者ガイド](https://tinayrum.github.io/.github/admin/) — リポジトリの作り方と設定
- [ツール仕様](https://tinayrum.github.io/.github/tools/) — `tools/new_repo`

## 🆘 連絡先

- 管理者：[藤平](https://github.com/tinayla696)
- 問い合わせ：[info@tinayrum.com](mailto:info@tinayrum.com)
- ガイドの改善提案：[tinayrum/.github](https://github.com/tinayrum/.github) への Issue / PR 歓迎
