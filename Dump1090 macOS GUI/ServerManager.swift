//
//  ServerManager.swift
//  Dump1090 macOS GUI
//
//  Created by Niko on 20.08.25.
//

import Foundation

@MainActor
class ServerManager: ObservableObject {
    // Published states
    @Published private(set) var logLines: [String] = []
    
    @Published var deviceIndex: Int = 0
    @Published var gain: Int = 0
    @Published var enableGain: Bool = false
    @Published var latitude: String = ""
    @Published var longitude: String = ""

    @Published var status: String = "Offline"
    @Published var consoleOutput: String = ""
    @Published var isRunning: Bool = false
    @Published var networkDiscoveryEnabled: Bool = true
    @Published var showingAdvancedPorts = false
    
    @Published var availableDevices: [String] = []
    @Published var selectedDeviceIndex: Int = 0
    
    @Published var bindAddress: String = "127.0.0.1"
    @Published var netRiPort: Int = 30001
    @Published var netRoPort: Int = 30002
    @Published var netSbsPort: Int = 30003
    @Published var netBiPort: Int = 30004
    @Published var netBoPort: Int = 30005

    @Published var showErrorAlert: Bool = false
    @Published var errorMessage: String = ""
    
    private var task: Process?
    private var service: NetService?

    init() {
        service = NetService(domain: "", type: "_maxplanes._tcp", name: "", port: Int32(netRoPort))
        service?.publish()
    }

    func toggleServer() {
        if isRunning {
            killServer()
        } else {
            launchServer()
        }
    }

    private func launchServer() {
        let task = Process()
        guard let execURL = Bundle.main.url(forAuxiliaryExecutable: "dump1090_mac") else {
            appendConsole("Executable not found")
            return
        }

        task.executableURL = execURL
        task.arguments = buildArguments()
        
        appendConsole("Launching with arguments: " + (task.arguments?.joined(separator: " ") ?? "none"))
        appendConsole("\n")

        let outPipe = Pipe()
        let errPipe = Pipe()

        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                Task { @MainActor in
                    self?.appendConsole(str)
                }
            }
        }
        errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                Task { @MainActor in
                    self?.appendConsole(str)
                }
            }
        }

        task.standardOutput = outPipe
        task.standardError = errPipe

        do {
            try task.run()
            self.task = task
            setServerState(true)
        } catch {
            appendConsole("Failed to launch dump1090: \(error.localizedDescription)")
        }

        task.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                self?.setServerState(false)
            }
        }
    }

    private func buildArguments() -> [String] {
        var args: [String] = []

        // Device config
        args.append("--device-index")
        args.append("\(deviceIndex)")

        if enableGain {
            args.append("--gain")
            args.append("\(gain)")
        }

        // Networking
        args.append("--net")
        args.append("--net-bind-address")
        args.append(bindAddress)
        
        args.append("--net-ri-port"); args.append("\(netRiPort)")
        args.append("--net-ro-port"); args.append("\(netRoPort)")
        args.append("--net-sbs-port"); args.append("\(netSbsPort)")
        args.append("--net-bi-port"); args.append("\(netBiPort)")
        args.append("--net-bo-port"); args.append("\(netBoPort)")
        
        // Disable HTTP
        args.append(contentsOf: ["--net-http-port", "0"])

        // Location
        if !latitude.isEmpty, !longitude.isEmpty {
            args.append("--lat"); args.append(latitude)
            args.append("--lon"); args.append(longitude)
        }
    
        return args
    }

    private func killServer() {
        task?.interrupt()
        usleep(10)
        if task?.isRunning == true {
            task?.terminate()
        }
        task = nil
        setServerState(false)
    }

    private func setServerState(_ running: Bool) {
        isRunning = running
        if running {
            status = "Running..."
        } else if status != "No USB Device" {
            status = "Offline"
        }
    }

    private func appendConsole(_ str: String) {
        Task { @MainActor in
            if str.hasPrefix("No supported RTL-SDR devices found.") {
                status = "No USB Device"
            }

            // Detect USB/port errors
            if str.contains("usb_claim_interface error") || str.contains("port already in use") || str.contains("No supported RTLSDR devices found.") {
                handleDeviceOrPortError(str)
            }

            let newLines = str.split(separator: "\n", omittingEmptySubsequences: false).map { String($0) }
            logLines.append(contentsOf: newLines)

            if logLines.count > 1000 {
                logLines = Array(logLines.suffix(1000))
            }
        }
    }
    
    @MainActor
    private func handleDeviceOrPortError(_ str: String) {
        errorMessage = str
        showErrorAlert = true
    }

    func setNetworkDiscovery(_ enabled: Bool) {
        if enabled {
            service?.publish()
        } else {
            service?.stop()
        }
    }

    func detectDevices() {
        guard let execURL = Bundle.main.url(forAuxiliaryExecutable: "dump1090_mac") else {
            print("[DEBUG] Executable not found")
            return
        }

        print("[DEBUG] Executable found at: \(execURL.path)")

        let task = Process()
        task.executableURL = execURL
        task.arguments = ["--device-index", "999"] // force error to list devices

        let pipe = Pipe()
        task.standardError = pipe
        task.standardOutput = pipe

        do {
            try task.run()
        } catch {
            print("[DEBUG] Failed to run detection: \(error)")
            return
        }

        task.terminationHandler = { [weak self] _ in
            guard let self = self else { return }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                print("[DEBUG] dump1090 output:\n\(output)")
                Task { @MainActor in
                    let devices = self.parseDevices(from: output)
                    print("[DEBUG] Parsed devices: \(devices)")
                    self.availableDevices = devices
                    if !self.availableDevices.isEmpty {
                        self.selectedDeviceIndex = 0
                        self.deviceIndex = 0
                    }
                }
            } else {
                print("[DEBUG] Failed to read output from dump1090")
            }
        }
    }

    private func parseDevices(from output: String) -> [String] {
        var devices: [String] = []
        let lines = output.split(separator: "\n")
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.contains("No matching devices found") || trimmed.contains("Error opening") {
                break
            }
            
            if trimmed.first?.isNumber == true {
                devices.append(trimmed)
            }
        }
        
        print("[DEBUG] Parsed devices: \(devices)")
        return devices
    }
}
