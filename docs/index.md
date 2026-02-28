
# 運用ガイドライン Home

本ガイドは「Portal+App構成」および「App単体構成」の両方に対応しています。
どちらのリポジトリでも、Docs as Codeの運用を推奨します。

## 🎯 目的

本組織では、「**Docs as Code (ドキュメントもコードである)**」を掲げ、  
ソースコードとドキュメントの完全一致を目指します。  
GitHub Actions と Git Subtree を活用した自動連携システムにより、属人化を排除し、常に最新のナレッジが共有される状態を保ちます。  


## 🏗 システムアーキテクチャ

プロジェクトは以下のいずれかの構成をとります。

| 構成 | 命名規則 | 役割 |
| :--- | :--- | :--- |
| **Portal+App** | `<Project>_portal` / `<SpecificApp>_<Language>` | Portal: ドキュメント統合・進捗管理 / App: ソースコード・仕様書 |
| **App単体** | `<AppName>` | アプリケーション単体のソースコード・仕様書 |


### 自動連携フロー（Portal+App構成の場合）
1. **開発**: Appリポジトリでコードと `docs/` を修正してPush。
2. **通知**: GitHub Actions でPortalリポジトリへ更新を通知。
3. **同期**: Portalリポジトリが自動で `git subtree pull` を実行。
4. **統合**: Portalリポジトリに統合PRが作成される。

App単体構成の場合は、各Appリポジトリ内で完結します。

## 🚀 最新プロジェクト: MobilityOps

*coming soon...*