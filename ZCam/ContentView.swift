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
        CameraPreviewView(session: cameraManager.session)
            .ignoresSafeArea()
            .task {
                await cameraManager.requestAccess()
                cameraManager.start()
            }
    }
}

#Preview {
    ContentView()
}
