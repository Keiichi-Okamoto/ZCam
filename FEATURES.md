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
- [x] 303 Camera機能の実装
    - [x] 303-1 `Deployment Info`の`iPhone Orientation`は`Portrait`のみ
    - [x] 303-2 カメラは背面カメラのみ。`builtInWideAngleCamera`を使う。
    - [x] 303-3 `videoZoomFactor`は`minAvailableVideoZoomFactor`。
    - [x] 303-4 カメラの画像はCALayerに表示。
    - [x] 303-5 カメラの画像は画面全体に表示。
        - Status Barは非表示
    - [x] 303-6 シミュレータで実行する場合には`#if targetEnvironment(simulator) `で判別し、`Resource/image/simulator_dummy.jpg`を使用する。
    - [x] 303-7 302のダイアログで拒否された場合には「カメラへのアクセスが許可されていません」とテキスト表示。

## Chapter 4（変更の可能性あり）
- [x] 401 Auto Focus機能の追加
    - [x] 401-1 `UIRequiredDeviceCapabilities`への追加
        - `auto-focus-camera`, `camera-flash`
    - [x] 401-2 continuousAutoFocus、continuousAutoWhiteBalance, continuousAutoExposure
        - 下記の順番で可能なものに設定。
        - continuousAuto -> auto -> locked
    - [x] 401-3 focus Point
        - 初期値は画面中央
        - Focus Pointには`dot.crosshair`を緑で描画
        - 指でタップした位置にFocus Pointを合わせる。
        - 画面のダブルタップで画面中央に戻る
        - Focus Pointが変わった場合にはアニメーションでSF Symbolを移動
- [x] 402 Zoom機能
    - [x] 402-1 ダミーのシャッターボタンを標準のカメラアプリと同じ位置に同じようなデザインで配置
    - [x] 402-2 AVCaptureDeviceの変更
        - 下記の順番でデバイスを選択 
        - builtInTripleCamera -> builtInDualCamera -> builtInWideAngleCamera
    - [x] 402-3 Zoom用スラーダーの実装
        - シャッターボタンの上に配置
        - 左を最小、右を最大とする
    - [ ] 402-4 builtInWideAngleCameraの最小倍率を1とする
    - [x] 402-5 デフォルトは
        - 実機: x1
        - シミュレータ: x1.5 
    - [x] 402-6 スライダの最小最高値
        - 実機: min = 0.5, max = 3.0
    - [x] 402-7 スライダの操作に合わせて画像の拡大縮小
        - 実機、シミュレータでそれぞれスライダーの値に合わせて対応する画像を拡大縮小する。
- [ ] 403 FlashModeの選択
    - モードは次の3種類
        - 自動 `bolt.badge.automatic.fill`
        - 常にON `bolt.fill`
        - 常にOff `bolt.slash.fill`
    -　[ ] 403-1 画面左上にボタンとして表示
        - 初期値は自動とし、選択されているモードにより`SF Symbol`を表示する
    -　[ ] 403-2 タップされるとポップアップのメニューを表示
        - 選択中の項目は✓を付ける。
        - 自動, 常にOn, 常にOffの選択
    - [ ] 403-3 選択されるとモードを変更し、UserDefaultに保存
        - 次回起動時はそれをで初期値として読み取り設定する。
- [ ] 404 端末のローテーション
    - ローテーション時には画面上のボタン等も中心を支点としてローテーション
    - スライダー
        - Portrait: シャッターボタンの上部に表示。画面横幅の80% 
        - Landscape: Landscapeにした時の画面下部に表示。Landscapeにした時の画面幅の80%

## Chapter 5
    
## Chapter 6
    - `UIRequiredDeviceCapabilities`に`metal`を追加
    - `CALayer`を`MTKView`に置き換える
    

## Chapter 7
    - `NSPhotoLibraryAddUsageDescription`の`InfoPilist`への追加
        - 「撮影した写真を保存するためにフォトライブラリへのアクセスが必要です。」
    - デバイスの向きに合わせて画像を回転させて保存


    - PrivacyInfoの追加
        - 全ソースをチェックし必要な項目を記述する

## Chapter 8
    
