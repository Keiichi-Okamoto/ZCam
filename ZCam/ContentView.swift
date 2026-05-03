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
                        CameraPreviewView(session: cameraManager.session) { devicePoint, screenPoint in
                            cameraManager.setFocusPoint(devicePoint)
                            withAnimation(.easeInOut(duration: 0.2)) {
                                focusIndicatorPosition = screenPoint
                            }
                        }
                        .ignoresSafeArea()

                        Image(systemName: "dot.crosshair")
                            .font(.system(size: 60))
                            .foregroundStyle(.green)
                            .position(
                                x: focusIndicatorPosition.x * geometry.size.width,
                                y: focusIndicatorPosition.y * geometry.size.height
                            )
                    }
                    .statusBarHidden(true)
                }
            }
        }
        .task {
            await cameraManager.requestAccess()
        }
        #endif
    }
}

#Preview {
    ContentView()
}
