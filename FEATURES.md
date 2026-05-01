#  FEATURES

## Chapter 3
- [x] 301 SwiftLintの導入 (約30分)
    - SPMでの設定は人が行った方が安全なので人が行う。
    - `.swiftlint.yml`の設定はルールを人が定義しAIが作成する。
    - Build Phase -> Run Scriptでのスクリプトの作成はAIが実装する。
    - **無効化するルール（disabled_rules）**
        - `line_length` — SwiftUIのコードは長くなりがちなため無効化
        - `function_body_length` — SwiftUIのbodyが長くなるため無効化
        - `type_body_length` — 同上
        - `trailing_whitespace` — エディタ設定で対処するため無効化
        - `todo` — 開発中のTODOコメントを許容するため無効化
        - `multiple_closures_with_trailing_closure` — SwiftUIの複数クロージャ記法と競合するため無効化
    - **追加するルール（opt_in_rules）**
        - `sorted_imports` — importを整列
        - `vertical_whitespace_closing_braces` — 閉じ括弧前の空行を禁止
        - `vertical_whitespace_opening_braces` — 開き括弧後の空行を禁止
        - `operator_usage_whitespace` — 演算子前後のスペースを統一
        - `overridden_super_call` — super呼び出し忘れを防止
        - `closure_spacing` — クロージャの`{ }`内スペースを統一
        - `unneeded_parentheses_in_closure_argument` — クロージャ引数の不要な括弧を排除
    - **追加の作業**
        - SPMで追加したSwiftLintがFrameworksにリンクされてしまうためビルドエラーが発生する。ターゲットのFrameworks, Libraries, and Embedded ContentからSwiftLintFrameworkとswiftlintを削除する（AIが実装）。
        - `ENABLE_USER_SCRIPT_SANDBOXING`を`NO`に設定する（AIが実装）。Run ScriptのサンドボックスがSwiftLintのソースファイルアクセスを制限するため。
    - **Settings.jsonへの追加項目**
        - `.claude/settings.json`（プロジェクト設定）に`xcodebuild`のビルド・テスト系コマンドを`allowedTools`に追加する（AIが実装）。確認なしでビルドを繰り返し実行できるようにするため。
        - 同じく`find`、`cat`、`grep`、`ls`、`head`、`tail`、`wc`、`xcrun`などの読み取り専用コマンドも`allowedTools`に追加する（AIが実装）。調査・確認作業を確認なしで行えるようにするため。
- [x] 302 `InfoPlist.xcstrings`の`NSCameraUsageDescription`の記述（en, jp対応）
    - `写真を撮影するためにカメラへのアクセスが必要です`
- [ ] 303 Camera機能の実装
    - [ ] 303-1 `Deployment Info`の`iPhone Orientation`は`Portlate`のみ
    - [ ] 303-2 カメラは背面カメラのみ。`builtInWideAngleCamera`を使う。
    - [ ] 303-3 `videoZoomFactor`は`minAvailableVideoZoomFactor`。
    - [ ] 303-4 カメラの画像はCALayerに表示。
    - [ ] 303-5 カメラの画像は画面全体に表示。
        - Status Barは非表示
    - [ ] 303-6 シミュレータで実行する場合には`#if targetEnvironment(simulator) `で判別し、`Resource/image/simulator_dummy.jpg`を使用する。
    - [ ] 303-7 302のダイアログで拒否された場合には「カメラへのアクセスが許可されていません」とテキスト表示。
    
