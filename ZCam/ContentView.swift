//
//  ContentView.swift
//  ZCam
//
//  Created by 岡本啓一 on 2026/04/29.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()

    var body: some View {
        #if targetEnvironment(simulator)
        Image("simulator_dummy")
            .resizable()
            .scaledToFill()
            .ignoresSafeArea()
            .statusBarHidden(true)
        #else
        CameraPreviewView(session: cameraManager.session)
            .ignoresSafeArea()
            .statusBarHidden(true)
            .task {
                await cameraManager.requestAccess()
                cameraManager.start()
            }
        #endif
    }
}

#Preview {
    ContentView()
}
