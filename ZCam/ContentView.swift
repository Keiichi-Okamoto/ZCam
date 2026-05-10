//
//  ContentView.swift
//  ZCam
//
//  Created by 岡本啓一 on 2026/04/29.
//

import AVFoundation
import SwiftUI

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var orientationObserver = OrientationObserver()
    @State private var focusIndicatorPosition: CGPoint = CGPoint(x: 0.5, y: 0.5)
    @State private var isFlashMenuOpen = false

    var body: some View {
        GeometryReader { proxy in
            if cameraManager.authorizationStatus == .denied || cameraManager.authorizationStatus == .restricted {
                deniedView
            } else {
                ZStack {
                    cameraBackground
                        .ignoresSafeArea()
                    focusIndicator

                    // メニューが開いている時は背景タップで閉じる
                    if isFlashMenuOpen {
                        Color.clear
                            .contentShape(Rectangle())
                            .ignoresSafeArea()
                            .onTapGesture { isFlashMenuOpen = false }
                    }
                    
                    SliderView(viewSize: proxy.size,
                               cameraManager: cameraManager,
                               orientationObserver: orientationObserver)

                    ShutterButtonView(viewSize: proxy.size,
                                      orientationObserver: orientationObserver)

                    TopControls(cameraManager: cameraManager,
                                orientationObserver: orientationObserver,
                                isFlashMenuOpen: $isFlashMenuOpen)
                }
                .statusBarHidden(true)
                .task {
                    await cameraManager.requestAccess()
                }
            }
        }
    }

    // MARK: - Top controls

    private struct TopControls: View {
        @ObservedObject var cameraManager: CameraManager
        @ObservedObject var orientationObserver: OrientationObserver
        @Binding var isFlashMenuOpen: Bool
        var body: some View {
            VStack {
                HStack {
                    FlashModeButton(cameraManager: cameraManager,
                                    orientationObserver: orientationObserver,
                                    isFlashMenuOpen: $isFlashMenuOpen)
                        .padding(.leading, 16)
                    Spacer()
                }
                .padding(.top, 16)
                Spacer()
            }
        }
    }

    // MARK: - FlashModeButton
    private struct FlashModeButton: View {
        @ObservedObject var cameraManager: CameraManager
        @ObservedObject var orientationObserver: OrientationObserver
        @Binding var isFlashMenuOpen: Bool
        let flashModeMenuOffset = CGSize(width: 36, height: 36)

        var body: some View {
            ZStack(alignment: .topLeading) {
                // トグルボタン
                Button {
                    isFlashMenuOpen.toggle()
                } label: {
                    Image(systemName: flashModeSymbol)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(isFlashMenuOpen ? .black : .white)
                        .padding(8)
                        .background(isFlashMenuOpen ? .white : .black.opacity(0.4), in: Circle())
                }
                .rotationEffect(orientationObserver.rotationAngle)
                .animation(.easeInOut(duration: 0.3), value: orientationObserver.orientation)
                
                // フラッシュメニュー（トグルON時に表示）
                if isFlashMenuOpen {
                    FlashModeMenu(cameraManager: cameraManager,
                                  isFlashMenuOpen: $isFlashMenuOpen)
                        .rotationEffect(orientationObserver.rotationAngle)
                        .animation(.easeInOut(duration: 0.3), value: orientationObserver.orientation)
                        .offset(flashModeMenuOffset)
                }
            }
        }
        
        private var flashModeSymbol: String {
            switch cameraManager.flashMode {
            case .auto: return "bolt.badge.automatic.fill"
            case .on:   return "bolt.fill"
            case .off:  return "bolt.slash.fill"
            @unknown default: return "bolt.badge.automatic.fill"
            }
        }
    }

    private struct FlashModeMenu: View {
        @ObservedObject var cameraManager: CameraManager
        @Binding var isFlashMenuOpen: Bool

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                FlashModeMenuItem(cameraManager: cameraManager,
                                  isFlashMenuOpen: $isFlashMenuOpen,
                                  label: "自動",
                                  mode: .auto)
                Divider().background(.white.opacity(0.3))

                FlashModeMenuItem(cameraManager: cameraManager,
                                  isFlashMenuOpen: $isFlashMenuOpen,
                                  label: "常にON",
                                  mode: .on)
                Divider().background(.white.opacity(0.3))

                FlashModeMenuItem(cameraManager: cameraManager,
                                  isFlashMenuOpen: $isFlashMenuOpen,
                                  label: "常にOff",
                                  mode: .off)
            }
            .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
            .fixedSize()
        }
    }

    private struct FlashModeMenuItem: View {
        @ObservedObject var cameraManager: CameraManager
        @Binding var isFlashMenuOpen: Bool
        let label: String
        let mode: AVCaptureDevice.FlashMode
        var body: some View {
            Button {
                cameraManager.setFlashMode(mode)
                isFlashMenuOpen = false
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .opacity(cameraManager.flashMode == mode ? 1 : 0)
                    Text(label)
                        .font(.system(size: 15))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(minWidth: 120, alignment: .leading)
            }
        }
    }

    // MARK: - Slider
    private struct SliderView: View {
        let viewSize: CGSize
        @ObservedObject var cameraManager: CameraManager
        @ObservedObject var orientationObserver: OrientationObserver
        @State var sliderWidth: CGFloat = 0
        @State var sliderOffset = CGSize.zero

        var body: some View {
            HStack {
                ZoomSliderView(
                    sliderValue: $cameraManager.sliderValue,
                    minZoom: cameraManager.sliderMinZoom,
                    maxZoom: cameraManager.sliderMaxZoom,
                    onChanged: { cameraManager.setZoomFactor($0) }
                )
                .frame(width: sliderWidth)
                .rotationEffect(orientationObserver.rotationAngle)
                .animation(.easeInOut(duration: 0.3),
                           value: orientationObserver.rotationAngle)
                .offset(sliderOffset)
                .padding(.horizontal, 0)
                .onChange(of: orientationObserver.orientation) { _, orientation in
                    withAnimation {
                        sliderWidth(orientation)
                        sliderOffset(orientation)
                    }
                }
                .onAppear {
                    let orientation = orientationObserver.orientation
                    sliderWidth(orientation)
                    sliderOffset(orientation)
                }
            }
        }

        private func sliderWidth(_ orientation: UIDeviceOrientation) {
            let widthRatio = 0.8
            switch orientation {
            case .portrait:
                sliderWidth = viewSize.width * widthRatio
            case .landscapeLeft, .landscapeRight:
                sliderWidth = viewSize.height * widthRatio
            default:
                break
            }
        }

        private func sliderOffset(_ orientation: UIDeviceOrientation) {
            let screenWidth = viewSize.width
            let screenHeight = viewSize.height

            // ZStack は中央基準なので、offset は画面中心からの相対距離で指定する
            // 各値は実機で目視確認しながら試行錯誤で決定した
            switch orientation {
            case .portrait:
                sliderOffset = CGSize(width: 0, height: screenHeight / 2 - 180)
            case .landscapeLeft:
                sliderOffset = CGSize(width: -screenWidth * 3 / 4 + 50, height: 0)
            case .landscapeRight:
                sliderOffset = CGSize(width: screenWidth / 4 - 31.0 - 50, height: 0)
            default:
                break
            }
        }
    }

    private struct ZoomSliderView: View {
        @Binding var sliderValue: CGFloat
        let minZoom: CGFloat
        let maxZoom: CGFloat
        let onChanged: (CGFloat) -> Void

        var body: some View {
            VStack(spacing: 2) {
                Text("zoom=\(String(format: "%.2f", sliderValue))")
                    .foregroundStyle(.white)
                    .font(.caption)
                Slider(value: $sliderValue, in: minZoom...maxZoom)
                    .onChange(of: sliderValue) { _, newValue in
                        onChanged(newValue)
                    }
            }
        }
    }

    // MARK: - ShutterButton
    private struct ShutterButtonView: View {
        let viewSize: CGSize
        @ObservedObject var orientationObserver: OrientationObserver
        @State var shutterButtonOffset = CGSize.zero

        var body: some View {
            HStack(alignment: .center) {
                ShutterButton()
                    .rotationEffect(orientationObserver.rotationAngle)
                    .offset(shutterButtonOffset)
                    .onChange(of: orientationObserver.orientation) { _, orientation in
                        withAnimation {
                            shutterButtonOffset(orientation)
                        }
                    }
                    .onAppear {
                        let orientation = orientationObserver.orientation
                        shutterButtonOffset(orientation)
                    }
            }
        }

        private func shutterButtonOffset(_ orientation: UIDeviceOrientation) {
            let screenHeight = viewSize.height
            // ZStack は中央基準なので、offset は画面中心からの相対距離で指定する
            // 各値は実機で目視確認しながら試行錯誤で決定した
            switch orientation {
            case .portrait:
                shutterButtonOffset = CGSize(width: 0, height: screenHeight / 2 - 100)
            case .landscapeLeft, .landscapeRight:
                shutterButtonOffset = CGSize(width: -100, height: screenHeight / 2 - 100)
            default:
                break
            }
        }
    }

    private struct ShutterButton: View {
        var body: some View {
            ZStack {
                Circle()
                    .strokeBorder(.white, lineWidth: 3)
                    .frame(width: 72, height: 72)
                Circle()
                    .fill(.white)
                    .frame(width: 60, height: 60)
            }
        }
    }

    // MARK: - Camera background
    @ViewBuilder
    private var cameraBackground: some View {
        CameraPreviewView(
            frameStore: cameraManager.frameStore,
            onTap: { devicePoint, screenPoint in
                cameraManager.setFocusPoint(devicePoint)
                withAnimation(.easeInOut(duration: 0.2)) {
                    focusIndicatorPosition = screenPoint
                }
            },
            zoomFactor: cameraManager.sliderValue
        )
    }

    // MARK: - Focus indicator
    private var focusIndicator: some View {
        GeometryReader { geometry in
            Image(systemName: "dot.crosshair")
                .font(.system(size: 60))
                .foregroundStyle(.green)
                .position(
                    x: focusIndicatorPosition.x * geometry.size.width,
                    y: focusIndicatorPosition.y * geometry.size.height
                )
        }
        .ignoresSafeArea()
    }

    // MARK: - Denied view

    private var deniedView: some View {
        Text("カメラへのアクセスが許可されていません")
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)
            .ignoresSafeArea()
            .statusBarHidden(true)
    }
}

#Preview {
    ContentView()
}
