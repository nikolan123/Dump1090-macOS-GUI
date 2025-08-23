//
//  Dump1090_macOS_GUIApp.swift
//  Dump1090 macOS GUI
//
//  Created by Niko on 20.08.25.
//

import SwiftUI

@main
struct Dump1090_macOS_GUIApp: App {
    @StateObject private var serverManager = ServerManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(serverManager)
        }
        .defaultSize(width: 600, height: 500)
    }
}
