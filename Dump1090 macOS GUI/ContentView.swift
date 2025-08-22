//
//  ContentView.swift
//  Dump1090 macOS GUI
//
//  Created by Niko on 20.08.25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var serverManager = ServerManager()
    @State private var showingLogs = false

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            headerView
                .padding(.horizontal)
                .padding(.vertical, 12)
            
            Divider()
            
            // MARK: - Settings Form
            Form {
                // MARK: - Device Section
                Section(header: Text("Device").font(.headline).fontWeight(.bold)) {
                    HStack {
                        Picker("Device", selection: $serverManager.selectedDeviceIndex) {
                            ForEach(serverManager.availableDevices.indices, id: \.self) { idx in
                                Text(serverManager.availableDevices[idx]).tag(idx)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        Spacer()
                        
                        Button {
                            serverManager.detectDevices()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .help("Rescan for devices")
                    }
                    
                    Toggle("Custom Gain", isOn: $serverManager.enableGain)
                       .toggleStyle(.switch)
                    
                    if serverManager.enableGain {
                        TextField(
                            "Gain (dB)",
                            text: Binding(
                                get: { String(serverManager.gain) },
                                set: { newValue in
                                    if let intValue = Int(newValue) {
                                        serverManager.gain = intValue
                                    }
                                }
                            )
                        )
                    } else {
                        HStack {
                            Text("Gain")
                            Spacer()
                            Text("Max")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // MARK: - Networking Section
                Section(header: Text("Networking").font(.headline).fontWeight(.bold)) {
                    Picker("Accessible from", selection: $serverManager.bindAddress) {
                        Text("This Mac Only").tag("127.0.0.1")
                        Text("Local Network").tag("0.0.0.0")
                    }
                    .pickerStyle(.menu)

                    HStack {
                        Text("TCP Raw Input Listen Port")
                        Spacer()
                        TextField("", text: Binding(
                            get: { String(serverManager.netRiPort) },
                            set: { if let value = UInt16($0) { serverManager.netRiPort = value } }
                        ))
                    }

                    HStack {
                        Text("TCP Raw Output Port")
                        Spacer()
                        TextField("", text: Binding(
                            get: { String(serverManager.netRoPort) },
                            set: { if let value = UInt16($0) { serverManager.netRoPort = value } }
                        ))
                    }

                    HStack {
                        Text("TCP BaseStation Output Listen Port")
                        Spacer()
                        TextField("", text: Binding(
                            get: { String(serverManager.netSbsPort) },
                            set: { if let value = UInt16($0) { serverManager.netSbsPort = value } }
                        ))
                    }

                    HStack {
                        Text("TCP Beast Input Listen Port")
                        Spacer()
                        TextField("", text: Binding(
                            get: { String(serverManager.netBiPort) },
                            set: { if let value = UInt16($0) { serverManager.netBiPort = value } }
                        ))
                    }

                    HStack {
                        Text("TCP Beast Output Listen Port")
                        Spacer()
                        TextField("", text: Binding(
                            get: { String(serverManager.netBoPort) },
                            set: { if let value = UInt16($0) { serverManager.netBoPort = value } }
                        ))
                    }

                    Toggle("Enable Network Discovery", isOn: $serverManager.networkDiscoveryEnabled)
                        .toggleStyle(.switch)
                        .onChange(of: serverManager.networkDiscoveryEnabled) { _, newValue in
                            serverManager.setNetworkDiscovery(newValue)
                        }
                }

                // MARK: - Location Section
                Section(header: Text("Location").font(.headline).fontWeight(.bold)) {
                    TextField("Latitude", text: $serverManager.latitude)
                    TextField("Longitude", text: $serverManager.longitude)
                }
                
                // MARK: - Other Section
                Section(header: Text("Other").font(.headline).fontWeight(.bold)) {
                    TextField("Extra Launch Arguments", text: $serverManager.customLaunchArguments)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .frame(maxHeight: .infinity)

            // MARK: - Status & Controls
            footerView
                .padding()
                .background(.ultraThickMaterial)
        }
        .frame(minWidth: 400, minHeight: 300)
        .task {
            serverManager.detectDevices()
        }
    }

    // MARK: - Subviews
    private var headerView: some View {
        HStack {
            Image(systemName: "airplane.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)
            VStack(alignment: .leading) {
                Text("dump1090")
                    .font(.title)
                    .fontWeight(.bold)
                Text("ADS-B, Mode S, and Mode 3/A receiver")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .alert(serverManager.errorMessage, isPresented: $serverManager.showErrorAlert) {
            Button("OK", role: .cancel) { }
        }
    }

    private var footerView: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Status:")
                    .foregroundColor(.secondary)
                Text(serverManager.status)
                    .fontWeight(.bold)
                Spacer()
                Button("Logs") {
                    showingLogs = true
                }
            }
            .font(.subheadline)

            Button(action: { serverManager.toggleServer() }) {
                Text(serverManager.isRunning ? "Stop Server" : "Start Server")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .sheet(isPresented: $showingLogs) {
                VStack(spacing: 0) {
                    HStack {
                        Text("Server Logs")
                            .font(.headline)
                        Spacer()
                        Button("Close") {
                            showingLogs = false
                        }
                        .keyboardShortcut(.cancelAction)
                    }
                    .padding()
                    Divider()
                    
                    ScrollView {
                        VStack(alignment: .leading) {
                            ForEach(serverManager.logLines, id: \.self) { line in
                                Text(line)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .background(Color(NSColor.textBackgroundColor))
                }
                .frame(minWidth: 600, minHeight: 400)
            }
            .tint(serverManager.isRunning ? .red : .green)
        }
    }
    
    struct LogsView: View {
        let consoleOutput: String
        
        var body: some View {
            ScrollView {
                Text(consoleOutput)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(Color(NSColor.textBackgroundColor))
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .preferredColorScheme(.light)
        ContentView()
            .preferredColorScheme(.dark)
    }
}
