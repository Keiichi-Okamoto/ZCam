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
    @State private var focusIndicatorPosition: CGPoint = CGPoint(x: 0.5, y: 0.5)

    private let minZoomFactor: CGFloat = 0.5
    private let maxZoomFactor: CGFloat = 3.0

    var body: some View {
        if cameraManager.authorizationStatus == .denied || cameraManager.authorizationStatus == .restricted {
            deniedView
        } else {
            ZStack {
                cameraBackground
                    .ignoresSafeArea()
                focusIndicator
                topControls
                bottomControls
            }
            .statusBarHidden(true)
            .task {
                await cameraManager.requestAccess()
            }
        }
    }

    // MARK: - Top controls

    private var topControls: some View {
        VStack {
            HStack {
                flashModeButton
                    .padding(.leading, 16)
                Spacer()
            }
            .padding(.top, 16)
            Spacer()
        }
    }

    private var flashModeButton: some View {
        Menu {
            Button {
                cameraManager.setFlashMode(.auto)
            } label: {
                Label("自動", systemImage: cameraManager.flashMode == .auto ? "checkmark" : "")
            }
            Button {
                cameraManager.setFlashMode(.on)
            } label: {
                Label("常にON", systemImage: cameraManager.flashMode == .on ? "checkmark" : "")
            }
            Button {
                cameraManager.setFlashMode(.off)
            } label: {
                Label("常にOff", systemImage: cameraManager.flashMode == .off ? "checkmark" : "")
            }
        } label: {
            Image(systemName: flashModeSymbol)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white)
                .padding(8)
                .background(.black.opacity(0.4), in: Circle())
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

    // MARK: - Bottom controls

    private var bottomControls: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 0) {
                Text("zoom=\(String(format: "%.2f", cameraManager.zoomFactor))")
                    .foregroundStyle(.white)
                    .font(.caption)
                Slider(value: $cameraManager.zoomFactor, in: minZoomFactor...maxZoomFactor)
                    .onChange(of: cameraManager.zoomFactor) { _, newValue in
                        cameraManager.setZoomFactor(newValue)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 16)
                ShutterButton()
                    .padding(.bottom, 30)
            }
            .padding(.top, 30)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.5)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    // MARK: - Camera background

    @ViewBuilder
    private var cameraBackground: some View {
        #if targetEnvironment(simulator)
        // Color.black を土台にして Image を overlay することで、
        // Image の固有サイズが ZStack 全体の幅提案に伝播するのを防ぐ。
        // これがないと、同じ ZStack 内の Slider に「無限大の幅」が提案され描画が破綻する。
        Color.black
            .overlay {
                Image("simulator_dummy")
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(cameraManager.zoomFactor)
            }
            .clipped()
        #else
        CameraPreviewView(session: cameraManager.session) { devicePoint, screenPoint in
            cameraManager.setFocusPoint(devicePoint)
            withAnimation(.easeInOut(duration: 0.2)) {
                focusIndicatorPosition = screenPoint
            }
        }
        #endif
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

// MARK: - Subviews

struct ShutterButton: View {
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

#Preview {
    ContentView()
}
