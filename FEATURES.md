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

## Chapter 4
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
- [x] 402-zoom-layout-fix 402でのレイアウトの問題の修正 (Code Opus 4.7)
    - [x] Layoutの問題の修正
    - [x] スライダーの上部にTextで倍率を表示する。
- [x] 403 FlashModeの選択
    - モードは次の3種類
        - 自動 `bolt.badge.automatic.fill`
        - 常にON `bolt.fill`
        - 常にOff `bolt.slash.fill`
    -　[x] 403-1 画面左上にボタンとして表示
        - 初期値は自動とし、選択されているモードにより`SF Symbol`を表示する
    -　[x] 403-2 タップされるとポップアップのメニューを表示
        - 選択中の項目は✓を付ける。
        - 自動, 常にOn, 常にOffの選択
    - [x] 403-3 選択されるとモードを変更し、UserDefaultに保存
        - 次回起動時はそれをで初期値として読み取り設定する。
- [x] 403-FlashModeButton
    - [x] 403-4 FlashModeのボタンをToggleに変更
    - [x] 403-5 ToggleがONになったらToggleの近くに半透明のViewを表示（RoundRect）
        - 表示位置は Viewの左上がToggleの中心
        - Viewの中にメニューにあった項目を縦にボタンとして表示。
        - 選択されている項目には✓を付ける
        - 選択されるとモードを変更し、UserDefaultに保存
        - 次回起動時はそれをで初期値として読み取り設定する。        
- [x] 404 端末のローテーション
    - [x] 404-1 Portrait, Landscape Left, Landscape Rightに対応。Upside Downは対象外
        - ローテーションには`.rotationEffect`を使用
        - 位置の移動には`orientationObserver.orientation`を監視し`.offset`を変更
        - 大きさの変更には`orientationObserver.orientation`を監視し`.frame(width:)｀を変更
    - [x] 404-2 ローテーション時には画面上のToggleも中心を支点としてローテーション（アニメーション付き）
    - [x] 404-3 ToggleがONの時のViewもローテーションと位置変更（アニメーション付き）
        - Portraitから時計方向に90°回転させた: Viewの右上がToggleの中心
        - Portraitから反時計方向に90°回転させた: Viewの左下がToggleの中心
    - [x] 404-4 スライダーのローテーションと位置変更とサイズ変更（アニメーション付き）
        - スライダーと倍率を示すTextはまとめて1つのViewにする。
        - Portrait: シャッターボタンの上部に表示。画面横幅の80% 
        - Landscape: Landscapeにした時の画面下部に表示。Landscapeにした時の画面幅の80%

- [x] 402-fix-zoom-functionality
    - [x] `isVirtualDevice == true`で`constituentDevices`の中に`AVCaptureDeviceTypeBuiltInUltraWideCamera`がある場合
        - Sliderの倍率を `0.5 - 3.0`とする
        - 初期値は`1.0`
        - `videoZoomFactor`はSliderの値の2倍。
        - 実際の設定前に`minAvailableVideoZoomFactor...maxAvailableVideoZoomFactor`にclamp
    - [x] それ以外の場合
        - Sliderの倍率を `1.0 - 3.0` とする
        - 初期値は`1.0`
        - `videoZoomFactor`はSliderの値そのまま
        - 実際の設定前に`minAvailableVideoZoomFactor...maxAvailableVideoZoomFactor`にclamp

## Chapter 5
    - AVCaptureVideoPreviewLayer -> MTKView
   - [x] 501 `AVCaptureVideoPreviewLayer` を `MTKView` に置き換える
        - `UIRequiredDeviceCapabilities`に`metal`を追加
        - `AVCaptureVideoDataOutput`で映像フレームを取得する
            - [x] 501-1 `AVCaptureVideoDataOutput`の実装
            - [x] 501-2 `CMSampleBuffer`から`CIImage`を生成
        - `MTKView` / `MTKViewDelegate`を実装する
        - `MetalRenderer`を実装する
            - `CIImage`を`MTKView`に描画する
            - この時点ではフィルター処理は行わない
            - Chapter 6でCoreImageフィルターを差し込める構造にする
        - 既存機能を維持する
            - Zoomスライダーの操作で実機映像の拡大縮小が反映される
            - FlashModeのUIと保存処理は維持する
            - ShutterButton / FocusPoint / 各種UIの表示位置は維持する
            - シミュレータでは従来通りダミー画像を表示する
        - 受け入れ条件:
            - 実機でカメラ映像が`MTKView`経由で全画面表示される
            - `AVCaptureVideoPreviewLayer`への依存を表示処理から取り除く
            - Chapter 6のFilter PipelineはこのPRでは実装しない
            - `xcodebuild`でビルドが成功する
            - 実機確認が必要な項目はPR本文に明記する

## Chapter 6
    - CoreImageフィルターの実装と、Portraitでのパラメータ調整をゴールとする
    - 端末ローテーション時のUI回転・位置調整・ドラッグ操作はChapter 7で扱う
    - Chapter 6の動作確認はPortraitを前提とする
    - [x] 601 Filter Pipelineの実装
        - [x] 601-1 CIFilter
            - CIColorPosterize
                - 画像の抽象化
            - CILineOverlay
                - 画像の中の輪郭を抽出
            - CIMultiplyBlendMode
                - `inputImage`に`CIColorPosterize`の出力、`inputBackgroundImage`に`CILineOverlay`の出力
        - [x] 601-2 シミュレータ画像にも同じフィルターを適用
    - [ ] 602 パラメータ調整用パネルの表示とUserDefaults
        - [ ] 602-1 画面右上に`slider.horizontal.3`を表示
        - [ ] 602-2 `slider.horizontal.3`のタップでパラメータ表示のためのViewの表示
        - [ ] 602-3 Viewには以下の3つを操作するSliderを表示 (タイトルと現在の値をスライダの上部に)
            - 各フィルタの初期値は`setDefaults()`の値
            - inputLevels (CIColorPosterize) : 2...20, Step = 0.01
            - inputEdgeIntensity (CILineOverlay) : 0...5, Step = 0.01
            - inputThreshold (CILineOverlay) : 0...1, Step = 0.01
        - [ ] 602-4 各Sliderの移動で即時に画面に反映
            - UserDefaultsに保存し、次回起動時にはそれを参照する
            | Parameter | UserDefaults key |
            | --- | --- |
            | `inputLevels` | `"inputLevels"` |
            | `inputEdgeIntensity` | `"inputEdgeIntensity"` |
            | `inputThreshold` | `"inputThreshold"` |
    - 受け入れ条件:
        - Portraitでフィルター効果が確認できる
        - Portraitでパラメータ調整パネルを表示し、Sliderで即時反映できる
        - パラメータはUserDefaultsに保存される
        - LandscapeでのUI回転・位置調整はこの章では対象外
        - `slider.horizontal.3`とパラメータViewのローテーション、ドラッグ移動はこの章では実装しない

## Chapter 7
    - 座標の整合性の修正
    - [ ] 700 FocusPoint の座標整合性を修正する
        - `Chapter 5`で表示を`MTKView`に変更した事によりFocusPoint 表示位置と focusPointOfInterest /
    exposurePointOfInterest の不一致が発生した。その修正
    - [ ] 701 パラメータ調整UIの座標・回転対応
        - [ ] 701-1 `slider.horizontal.3`を端末ローテーションに追従して回転
        - [ ] 701-2 パラメータViewを端末ローテーションに追従して回転
        - [ ] 701-3 パラメータViewを指のドラッグで移動可能にする
        - [ ] 701-4 Portrait / Landscape Left / Landscape Right で既存UIと重ならない

## Chapter 8
    - [ ] `NSPhotoLibraryAddUsageDescription`の`InfoPilist`への追加
        - 「撮影した写真を保存するためにフォトライブラリへのアクセスが必要です。」
    - [ ] デバイスの向きに合わせてフィルタされた画像を回転させて保存
    - 最後に...
        - [ ] PrivacyInfoの追加
            - 全ソースをチェックし必要な項目を記述する

## Chapter 9
