
# ようこそ

このリポジトリは「Portal+App」構成または「App単体」構成の管理・運用を目的としたOrganizationsトップページ兼リポジトリ管理ツールです。



## 📖 運用ガイドライン

プロジェクトの運用ルール、アーキテクチャ、開発フローは以下のGitHub Pagesで公開しています。
👉 **[エンジニアリング・ガイドライン (GitHub Pages)](https://tinayrum.github.io/.github/)**
(※ URLはSettings > Pagesの設定後に確定します)

### 構成パターン
- **Portal + App**: ポータルサイトとアプリケーションがセットで管理される構成
- **Appのみ**: アプリケーション単体で管理される構成

それぞれの運用例・ガイドラインは `docs/` 以下にまとめています。


## 🛠 管理者用ツール (Admin Tools)

プロジェクトの立ち上げ・構成変更を行う自動化スクリプトです。
詳細は [管理者ガイド](https://tinayrum.github.io/.github/admin/) を参照してください。

### コマンド一覧
| 目的 | スクリプト | コマンド例 |
| :--- | :--- | :--- |
| **新規PJ立ち上げ (Portal+App)** | `setup_project.sh` | `./tools/setup_project.sh PortalName AppName` |
| **アプリ追加 (Portal+App)** | `add_app.sh` | `./tools/add_app.sh PortalName AppName` |
| **新規PJ立ち上げ (Appのみ)** | `setup_project.sh` | `./tools/setup_project.sh AppName` |

### 前提条件
* `tools/.secret_pat` に管理者権限を持つPATが保存されていること。
* `gh` (GitHub CLI) がインストールされていること。


## ディレクトリ構成例

### Portal+App構成
```tree
.
├── README.md
├── docs
│   ├── admin.md
│   ├── developer.md
│   ├── index.md
│   └── tools.md
├── mkdocs.yml
├── profile
│   └── README.md
├── requirements.txt
└── tools
    ├── .secret_pat    # (Git管理外: ここにPATを保存)
    ├── add_app.sh
    └── setup_project.sh
```

### App単体構成
```tree
.
├── README.md
├── docs
│   ├── admin.md
│   ├── developer.md
│   └── tools.md
├── mkdocs.yml
├── requirements.txt
└── tools
    ├── .secret_pat
    └── setup_project.sh
```


## Clone後の初期設定

1. `.secret_pat` ファイルを `tools` ディレクトリ内に作成し、管理者用PATを保存してください。

    ```bash
    echo "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" > tools/.secret_pat
    ```

2. `setup_project.sh` と `add_app.sh` に実行権限を付与します（App単体の場合は `setup_project.sh` のみ）。

    ```bash
    chmod +x tools/setup_project.sh tools/add_app.sh
    ```


## README.mdについて

このREADMEは、Portal+App構成またはApp単体構成のいずれにも対応した運用・管理ガイドです。
詳細な運用ルールやリソースは `docs/` および `profile/README.md` を参照してください。