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
    @StateObject private var filterPipeline = FilterPipeline()
    @State private var focusIndicatorPosition: CGPoint = CGPoint(x: 0.5, y: 0.5)
    @State private var focusCenterViewPoint: CGPoint = CGPoint(x: 0.5, y: 0.5)
    @State private var focusCenterDevicePoint: CGPoint = CGPoint(x: 0.5, y: 0.5)
    @State private var isFlashMenuOpen = false
    @State private var isParameterPanelOpen = false

    var body: some View {
        GeometryReader { proxy in
            if cameraManager.authorizationStatus == .denied || cameraManager.authorizationStatus == .restricted {
                deniedView
                    .frame(width: proxy.size.width, height: proxy.size.height)
            } else {
                ZStack {
                    cameraBackground
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                    focusIndicator(viewSize: proxy.size)
                    if isFlashMenuOpen || isParameterPanelOpen {
                        Color.clear
                            .contentShape(Rectangle())
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .onTapGesture {
                                isFlashMenuOpen = false
                                isParameterPanelOpen = false
                            }
                    }
                    TopControls(cameraManager: cameraManager,
                                orientationObserver: orientationObserver,
                                isFlashMenuOpen: $isFlashMenuOpen,
                                isParameterPanelOpen: $isParameterPanelOpen)
                    ShutterButtonView(viewSize: proxy.size,
                                      orientationObserver: orientationObserver,
                                      onShutter: { cameraManager.capturePhoto() })
                    SliderView(viewSize: proxy.size,
                               cameraManager: cameraManager,
                               orientationObserver: orientationObserver)
                    if isParameterPanelOpen {
                        ParameterPanel(filterPipeline: filterPipeline,
                                       viewSize: proxy.size,
                                       orientationObserver: orientationObserver)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                    }
                }
                .ignoresSafeArea()
                .statusBarHidden(true)
                .onChange(of: orientationObserver.orientation) { _, orientation in
                    guard orientation == .portrait ||
                          orientation == .landscapeLeft ||
                          orientation == .landscapeRight else {
                        return
                    }
                    resetFocusPointToCenter()
                }
                .task {
                    await cameraManager.requestAccess()
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - CameraIconButton

    private struct CameraIconButton: View {
        let systemName: String
        let isActive: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Image(systemName: systemName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isActive ? .black : .white)
                    .padding(8)
                    .background(isActive ? .white : .black.opacity(0.4), in: Circle())
            }
        }
    }

    // MARK: - Top controls

    private struct TopControls: View {
        @ObservedObject var cameraManager: CameraManager
        @ObservedObject var orientationObserver: OrientationObserver
        @Binding var isFlashMenuOpen: Bool
        @Binding var isParameterPanelOpen: Bool
        var body: some View {
            VStack {
                HStack {
                    FlashModeButton(cameraManager: cameraManager,
                                    orientationObserver: orientationObserver,
                                    isFlashMenuOpen: $isFlashMenuOpen,
                                    isParameterPanelOpen: $isParameterPanelOpen)
                        .padding(.leading, 16)
                    Spacer()
                    CameraIconButton(systemName: "slider.horizontal.3", isActive: isParameterPanelOpen) {
                        isParameterPanelOpen.toggle()
                        if isParameterPanelOpen { isFlashMenuOpen = false }
                    }
                    .rotationEffect(orientationObserver.rotationAngle)
                    .animation(.easeInOut(duration: 0.3), value: orientationObserver.orientation)
                    .padding(.trailing, 16)
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
        @Binding var isParameterPanelOpen: Bool
        let flashModeMenuOffset = CGSize(width: 36, height: 36)

        var body: some View {
            CameraIconButton(systemName: flashModeSymbol, isActive: isFlashMenuOpen) {
                isFlashMenuOpen.toggle()
                if isFlashMenuOpen { isParameterPanelOpen = false }
            }
            .rotationEffect(orientationObserver.rotationAngle)
            .animation(.easeInOut(duration: 0.3), value: orientationObserver.orientation)
            .overlay(alignment: .topLeading) {
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

        var body: some View {
            ZStack {
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
                .position(sliderPosition)
                .animation(.easeInOut(duration: 0.3),
                           value: orientationObserver.orientation)
            }
            .frame(width: viewSize.width, height: viewSize.height)
        }

        private var sliderWidth: CGFloat {
            switch orientationObserver.orientation {
            case .portrait:
                return viewSize.width * 0.8
            case .landscapeLeft, .landscapeRight:
                return viewSize.height * 0.8
            default:
                return viewSize.width * 0.8
            }
        }

        private var sliderPosition: CGPoint {
            switch orientationObserver.orientation {
            case .portrait:
                return CGPoint(x: viewSize.width / 2, y: viewSize.height - 180)
            case .landscapeLeft:
                return CGPoint(x: 72, y: viewSize.height / 2)
            case .landscapeRight:
                return CGPoint(x: viewSize.width - 72, y: viewSize.height / 2)
            default:
                return CGPoint(x: viewSize.width / 2, y: viewSize.height - 180)
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
        let onShutter: () -> Void

        var body: some View {
            HStack(alignment: .center) {
                ShutterButton(action: onShutter)
                    .offset(shutterButtonOffset)
            }
        }

        private var shutterButtonOffset: CGSize {
            CGSize(width: 0, height: viewSize.height / 2 - 100)
        }
    }

    private struct ShutterButton: View {
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                ZStack {
                    Circle()
                        .strokeBorder(.white, lineWidth: 3)
                        .frame(width: 72, height: 72)
                    Circle()
                        .fill(.white)
                        .frame(width: 60, height: 60)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Camera background
    @ViewBuilder
    private var cameraBackground: some View {
        #if targetEnvironment(simulator)
        CameraPreviewView(
            frameStore: cameraManager.frameStore,
            filterPipeline: filterPipeline,
            onTap: { viewPoint, devicePoint in
                cameraManager.setFocusPoint(devicePoint)
                withAnimation(.easeInOut(duration: 0.2)) {
                    focusIndicatorPosition = viewPoint
                }
            },
            onCenterPointChange: { viewPoint, devicePoint in
                focusCenterViewPoint = viewPoint
                focusCenterDevicePoint = devicePoint
            },
            zoomFactor: cameraManager.sliderValue
        )
        #else
        CameraPreviewView(
            frameStore: cameraManager.frameStore,
            filterPipeline: filterPipeline,
            onTap: { viewPoint, devicePoint in
                cameraManager.setFocusPoint(devicePoint)
                withAnimation(.easeInOut(duration: 0.2)) {
                    focusIndicatorPosition = viewPoint
                }
            },
            onCenterPointChange: { viewPoint, devicePoint in
                focusCenterViewPoint = viewPoint
                focusCenterDevicePoint = devicePoint
            }
        )
        #endif
    }

    // MARK: - Focus indicator
    private func focusIndicator(viewSize: CGSize) -> some View {
        ZStack {
            Image(systemName: "dot.crosshair")
                .font(.system(size: 60))
                .foregroundStyle(.green)
                .position(
                    x: focusIndicatorPosition.x * viewSize.width,
                    y: focusIndicatorPosition.y * viewSize.height
                )
        }
        .frame(width: viewSize.width, height: viewSize.height)
        .ignoresSafeArea()
    }

    private func resetFocusPointToCenter() {
        cameraManager.setFocusPoint(focusCenterDevicePoint)
        withAnimation(.easeInOut(duration: 0.2)) {
            focusIndicatorPosition = focusCenterViewPoint
        }
    }

    // MARK: - Parameter panel

    private struct ParameterPanel: View {
        @ObservedObject var filterPipeline: FilterPipeline
        let viewSize: CGSize
        @ObservedObject var orientationObserver: OrientationObserver
        @State private var restingOffset: CGSize = .zero
        @GestureState private var dragTranslation: CGSize = .zero
        private let panelEdgeInset: CGFloat = 16
        private let panelMaxWidth: CGFloat = 360
        private let fixedPanelHeight: CGFloat = 228

        var body: some View {
            panelContent
                .frame(width: panelWidth, height: panelHeight)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .rotationEffect(orientationObserver.rotationAngle)
                .position(panelPosition)
                .gesture(panelDragGesture, including: .gesture)
                .animation(.easeInOut(duration: 0.3), value: orientationObserver.orientation)
                .frame(width: viewSize.width, height: viewSize.height)
                .onChange(of: orientationObserver.orientation) { _, _ in
                    restingOffset = .zero
                }
        }

        private var panelContent: some View {
            VStack(alignment: .leading, spacing: 20) {
                parameterSlider(
                    title: "inputLevels",
                    value: $filterPipeline.inputLevels,
                    in: 2...20
                )
                parameterSlider(
                    title: "inputEdgeIntensity",
                    value: $filterPipeline.inputEdgeIntensity,
                    in: 0...5
                )
                parameterSlider(
                    title: "inputThreshold",
                    value: $filterPipeline.inputThreshold,
                    in: 0...1
                )
            }
            .padding(20)
        }

        private var panelDragGesture: some Gesture {
            DragGesture()
                .updating($dragTranslation) { value, state, _ in
                    state = value.translation
                }
                .onEnded { value in
                    let proposedOffset = CGSize(
                        width: restingOffset.width + value.translation.width,
                        height: restingOffset.height + value.translation.height
                    )
                    let proposedPosition = position(from: proposedOffset)
                    let clampedPosition = clamped(proposedPosition)
                    restingOffset = CGSize(
                        width: clampedPosition.x - defaultPosition.x,
                        height: clampedPosition.y - defaultPosition.y
                    )
                }
        }

        private var panelWidth: CGFloat {
            let horizontalLimit = viewSize.width - panelEdgeInset * 2
            if orientationObserver.isLandscape {
                let rotatedHeightLimit = viewSize.height - panelEdgeInset * 2
                return min(horizontalLimit, rotatedHeightLimit, panelMaxWidth)
            }
            return min(horizontalLimit, panelMaxWidth)
        }

        private var panelHeight: CGFloat {
            fixedPanelHeight
        }

        private var panelPosition: CGPoint {
            clamped(
                position(
                    from: CGSize(
                        width: restingOffset.width + dragTranslation.width,
                        height: restingOffset.height + dragTranslation.height
                    )
                )
            )
        }

        private var defaultPosition: CGPoint {
            switch orientationObserver.orientation {
            case .landscapeLeft:
                return CGPoint(x: viewSize.width - panelInset.width, y: viewSize.height / 2)
            case .landscapeRight:
                return CGPoint(x: panelInset.width, y: viewSize.height / 2)
            default:
                return CGPoint(x: viewSize.width / 2, y: 210)
            }
        }

        private func position(from offset: CGSize) -> CGPoint {
            CGPoint(
                x: defaultPosition.x + offset.width,
                y: defaultPosition.y + offset.height
            )
        }

        private func clamped(_ position: CGPoint) -> CGPoint {
            let inset = panelInset
            return CGPoint(
                x: min(max(position.x, inset.width), viewSize.width - inset.width),
                y: min(max(position.y, inset.height), viewSize.height - inset.height)
            )
        }

        private var panelInset: CGSize {
            switch orientationObserver.orientation {
            case .landscapeLeft, .landscapeRight:
                return CGSize(
                    width: panelHeight / 2 + panelEdgeInset,
                    height: panelWidth / 2 + panelEdgeInset
                )
            default:
                return CGSize(
                    width: panelWidth / 2 + panelEdgeInset,
                    height: panelHeight / 2 + panelEdgeInset
                )
            }
        }

        private func parameterSlider(title: String, value: Binding<Float>, in range: ClosedRange<Float>) -> some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.2f", value.wrappedValue))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.primary)
                }
                Slider(value: value, in: range)
            }
        }
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
