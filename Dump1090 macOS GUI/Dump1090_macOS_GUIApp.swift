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
    @Environment(\.openWindow) private var openWindow
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(serverManager)
        }
        .defaultSize(width: 600, height: 500)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Dump1090 macOS GUI") {
                    openWindow(id: "about")
                }
            }
            
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
        
        // About window
        Window("About Dump1090 macOS GUI", id: "about") {
            if #available(macOS 15.0, *) {
                AboutView()
                    .containerBackground(.regularMaterial, for: .window)
                    .toolbar(removing: .title)
                    .toolbarBackground(.hidden, for: .windowToolbar)
                    .frame(width: 500, height: 300)
            } else {
                AboutView()
                    .frame(width: 500, height: 300)
            }
        }
        .defaultSize(width: 500, height: 300)
    }
}

