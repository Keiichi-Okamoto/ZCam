# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

**ZCam** は SwiftUI で作るiOSカメラアプリ。「AIとiOSアプリを共同開発するプロセスをZennで記事化する」というコンセプトのプロジェクト。

開発フェーズ:
1. AVFoundation でカメラ映像をキャプチャ、CALayer に描画
2. CoreImage でフィルター処理
3. Metal を使った GPU 処理・リアルタイムエフェクト
4. 撮影・保存機能、UI の仕上げ

## ビルド・実行

```bash
# ビルド（シミュレーター）
xcodebuild -project ZCam.xcodeproj -scheme ZCam -destination 'platform=iOS Simulator,name=iPhone 16' build

# テスト実行
xcodebuild -project ZCam.xcodeproj -scheme ZCam -destination 'platform=iOS Simulator,name=iPhone 16' test

# 単一テストクラスの実行
xcodebuild -project ZCam.xcodeproj -scheme ZCam -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:ZCamTests/ZCamTests
```

> カメラ機能はシミュレーターでは動作しない。カメラ関連の動作確認は実機で行う。

## アーキテクチャ

現在は初期状態（`ContentView.swift` のみ）。今後の実装方針:

- **UI層**: SwiftUI (`ContentView` など)
- **カメラ層**: `AVFoundation` を使った `CameraManager`（今後追加）
- **フィルター層**: `CoreImage` → `Metal` の順に拡張
- **描画**: `CALayer` / `MetalKit` を SwiftUI に `UIViewRepresentable` でブリッジ

## ワークフロー

```
1. FEATURES.md に機能・仕様を追記（岡本さん）
2. Claude Code が実装して GitHub に PR を作成
3. 岡本さんが PR にコメント・レビュー
4. Claude Code がフィードバックを受けて修正
5. マージ → Zennの記事に反映
```

## ブランチ・PRルール

- 実装はFEATURES.mdの番号単位（001, 002...）でブランチを作成する
- ブランチ名: `feature/XXX-説明`（例: `feature/301-swiftlint-setup`）
- 実装依頼を受けたら、まず該当番号のブランチを `main` から作成してから作業を開始する
- 実装完了後は GitHub に PR を作成する。PRタイトルは `[XXX] 説明`（例: `[301] SwiftLint導入`）
- `main` への直接 push は行わない
- PR作成時は `.github/PULL_REQUEST_TEMPLATE.md` のテンプレートに従って記述する
- **`git push` は岡本さんから明示的に指示があるまで絶対に実行しない**（commit のみ行い、push はしない）
- **`git push` は岡本さんから明示的に指示があるまで絶対に実行しない**（commit のみ行い、push はしない）

## ドキュメント方針

- `.md` ファイルはすべて**日本語**で書く（Zenn向け、対象読者は日本人エンジニア）
- コード内コメントは日本語・英語どちらでも可（統一されていればOK）
- 詳細なプロジェクト背景・各セッション間の引き継ぎ情報は `PROJECT_CONTEXT.md` を参照
- `PROJECT_CONTEXT.md` は claude.ai（チャット）/ Cowork / Claude Code CLI など複数の Claude セッション間で文脈を共有するためのハブドキュメント。新しいセッション開始時は必ずこのファイルを読む

## Xcode / Signing

- Bundle ID: `com.example.ZCam`（クローンした人が自分の Apple ID で実機実行できる汎用設定）
- Signing: Automatically manage signing をオン
- Team: クローンした人が自分の Apple ID に変更するだけで動く設計
