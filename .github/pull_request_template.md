## 概要

<!-- ここにPRの概要を記載してください -->

## 関連Issue
Closes #

## マージ先
<!-- check_branch.yml が組み合わせを検証します -->
- [ ] `develop`（feature / bugfix / docs / chore、release・hotfix の戻し）
- [ ] `main`（develop / release / hotfix のみ = リリース）

## 変更の種類
- [ ] ✨ 新機能 (feature) - Minor
- [ ] 🐛 バグ修正 (bugfix) - Patch
- [ ] 📝 ドキュメント更新 (docs) - Patch
- [ ] ♻️ リファクタリング (chore)
- [ ] 🚀 リリース準備 (release)

## レビューチェックリスト
- [ ] **Docs as Code:** 修正対応あり
    - [ ] **Docs as Code:** コード修正に合わせて `docs/` 配下も修正されていますか？
    - [ ] **Build:** `mkdocs build --strict` が通りますか？
- [ ] **Code Quality:** コード品質
    - [ ] **Lint:** Lintエラーはありませんか？
    - [ ] **Type Check:** 型エラーはありませんか？
    - [ ] **Test:** テストコードは十分にカバーされていますか？
- [ ] **CI:** CIが正常に通っていますか？

## 作業報告
<!-- Issue に投稿した作業報告と同じ内容。形式は docs/development.md の「作業報告」 -->
- 変更したファイル:
- 実行したコマンドと結果:
  - `mkdocs build --strict`:
- 確認できていないこと:

## 承認記録
<!-- 選択肢方式で得た承認（G1 着手 / G2 マージ / G3 リリース）。Issue の質疑記録へのリンクでも可 -->
- G1 着手承認:
- G2 マージ承認:

## 備考

<!-- 制約事項・注意事項などはこちらに記載してください -->