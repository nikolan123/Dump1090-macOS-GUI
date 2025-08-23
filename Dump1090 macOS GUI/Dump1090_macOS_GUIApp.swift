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
        .commands {
            CommandMenu("Server") {
                Button("Start") {
                    serverManager.launchServer()
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(serverManager.isRunning)
                
                Button("Stop") {
                    serverManager.killServer()
                }
                .keyboardShortcut(".", modifiers: .command)
                .disabled(!serverManager.isRunning)
                
                Divider()
                
                Button("Logs") {
                    serverManager.showingData = false
                    serverManager.showingLogs.toggle()
                }
                .keyboardShortcut("l", modifiers: .command)

                Button("Data") {
                    serverManager.showingLogs = false
                    serverManager.showingData.toggle()
                }
                .keyboardShortcut("d", modifiers: .command)
            }
        }
    }
}
