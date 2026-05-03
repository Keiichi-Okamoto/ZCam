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
    @State private var focusIndicatorOffset: CGSize = .zero

    var body: some View {
        #if targetEnvironment(simulator)
        Image("simulator_dummy")
            .resizable()
            .scaledToFill()
            .ignoresSafeArea()
            .statusBarHidden(true)
        #else
        Group {
            if cameraManager.authorizationStatus == .denied || cameraManager.authorizationStatus == .restricted {
                Text("カメラへのアクセスが許可されていません")
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.black)
                    .ignoresSafeArea()
                    .statusBarHidden(true)
            } else {
                GeometryReader { geometry in
                    ZStack {
                        CameraPreviewView(session: cameraManager.session)
                            .ignoresSafeArea()

                        Image(systemName: "dot.crosshair")
                            .font(.system(size: 60))
                            .foregroundStyle(.green)
                            .offset(focusIndicatorOffset)
                    }
                    .statusBarHidden(true)
                    .gesture(
                        TapGesture(count: 2)
                            .onEnded {
                                let center = CGPoint(x: 0.5, y: 0.5)
                                cameraManager.resetFocusToCenter()
                                moveFocusIndicator(to: center, in: geometry.size)
                            }
                    )
                    .simultaneousGesture(
                        SpatialTapGesture()
                            .onEnded { value in
                                let size = geometry.size
                                let normalized = CGPoint(
                                    x: value.location.x / size.width,
                                    y: value.location.y / size.height
                                )
                                cameraManager.setFocusPoint(normalized)
                                moveFocusIndicator(to: normalized, in: size)
                            }
                    )
                }
            }
        }
        .task {
            await cameraManager.requestAccess()
        }
        #endif
    }

    private func moveFocusIndicator(to normalizedPoint: CGPoint, in size: CGSize) {
        let offsetX = normalizedPoint.x * size.width - size.width / 2
        let offsetY = normalizedPoint.y * size.height - size.height / 2
        withAnimation(.easeInOut(duration: 0.2)) {
            focusIndicatorOffset = CGSize(width: offsetX, height: offsetY)
        }
    }
}

#Preview {
    ContentView()
}
