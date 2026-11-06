//
//  ServerManager.swift
//  Dump1090 macOS GUI
//
//  Created by Niko on 20.08.25.
//

import Foundation
import Combine

@MainActor
class ServerManager: ObservableObject {
    // Published states
    @Published private(set) var logLines: [String] = []
    
    @Published var deviceIndex: Int = 0 {
        didSet { defaults.set(deviceIndex, forKey: SettingsKey.deviceIndex) }
    }
    @Published var gain: Int = 0 {
        didSet { defaults.set(gain, forKey: SettingsKey.gain) }
    }
    @Published var enableGain: Bool = false {
        didSet { defaults.set(enableGain, forKey: SettingsKey.enableGain) }
    }
    @Published var latitude: String = "" {
        didSet { defaults.set(latitude, forKey: SettingsKey.latitude) }
    }
    @Published var longitude: String = "" {
        didSet { defaults.set(longitude, forKey: SettingsKey.longitude) }
    }

    @Published var status: String = "Offline"
    @Published var consoleOutput: String = ""
    @Published var isRunning: Bool = false
    @Published var showingLogs = false
    @Published var showingData = false
    @Published var networkDiscoveryEnabled: Bool = true {
        didSet {
            defaults.set(networkDiscoveryEnabled, forKey: SettingsKey.discovery)
            updateNetworkDiscovery()
        }
    }
    @Published var showingAdvancedPorts = false
    
    @Published var availableDevices: [String] = []
    
    @Published var customLaunchArguments: String = "" {
        didSet { defaults.set(customLaunchArguments, forKey: SettingsKey.launchArguments) }
    }
    @Published var bindAddress: String = "127.0.0.1" {
        didSet { defaults.set(bindAddress, forKey: SettingsKey.bindAddress) }
    }
    @Published var netRiPort: UInt16 = 30001 {
        didSet { defaults.set(Int(netRiPort), forKey: SettingsKey.rawInputPort) }
    }
    @Published var netRoPort: UInt16 = 30002 {
        didSet {
            defaults.set(Int(netRoPort), forKey: SettingsKey.rawOutputPort)
            updateNetworkDiscovery()
        }
    }
    @Published var netSbsPort: UInt16 = 30003 {
        didSet { defaults.set(Int(netSbsPort), forKey: SettingsKey.baseStationPort) }
    }
    @Published var netBiPort: UInt16 = 30004 {
        didSet { defaults.set(Int(netBiPort), forKey: SettingsKey.beastInputPort) }
    }
    @Published var netBoPort: UInt16 = 30005 {
        didSet { defaults.set(Int(netBoPort), forKey: SettingsKey.beastOutputPort) }
    }

    @Published var showErrorAlert: Bool = false
    @Published var errorMessage: String = ""
    
    private var task: Process?
    private var service: NetService?
    private let defaults: UserDefaults
    private var isRestoringSettings = true

    private enum SettingsKey {
        static let deviceIndex = "device.index"
        static let gain = "device.gain"
        static let enableGain = "device.enableGain"
        static let launchArguments = "launch.arguments"
        static let latitude = "location.latitude"
        static let longitude = "location.longitude"
        static let bindAddress = "network.bindAddress"
        static let discovery = "network.discoveryEnabled"
        static let rawInputPort = "network.rawInputPort"
        static let rawOutputPort = "network.rawOutputPort"
        static let baseStationPort = "network.baseStationPort"
        static let beastInputPort = "network.beastInputPort"
        static let beastOutputPort = "network.beastOutputPort"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        deviceIndex = max(0, defaults.object(forKey: SettingsKey.deviceIndex) as? Int ?? 0)
        gain = defaults.object(forKey: SettingsKey.gain) as? Int ?? 0
        enableGain = defaults.object(forKey: SettingsKey.enableGain) as? Bool ?? false
        customLaunchArguments = defaults.string(forKey: SettingsKey.launchArguments) ?? ""
        latitude = defaults.string(forKey: SettingsKey.latitude) ?? ""
        longitude = defaults.string(forKey: SettingsKey.longitude) ?? ""
        if let address = defaults.string(forKey: SettingsKey.bindAddress),
           ["127.0.0.1", "0.0.0.0"].contains(address) {
            bindAddress = address
        }
        networkDiscoveryEnabled = defaults.object(forKey: SettingsKey.discovery) as? Bool ?? true
        netRiPort = Self.savedPort(in: defaults, key: SettingsKey.rawInputPort, fallback: 30001)
        netRoPort = Self.savedPort(in: defaults, key: SettingsKey.rawOutputPort, fallback: 30002)
        netSbsPort = Self.savedPort(in: defaults, key: SettingsKey.baseStationPort, fallback: 30003)
        netBiPort = Self.savedPort(in: defaults, key: SettingsKey.beastInputPort, fallback: 30004)
        netBoPort = Self.savedPort(in: defaults, key: SettingsKey.beastOutputPort, fallback: 30005)

        isRestoringSettings = false
        updateNetworkDiscovery()
    }

    deinit {
        service?.stop()
    }

    private static func savedPort(in defaults: UserDefaults, key: String, fallback: UInt16) -> UInt16 {
        guard let value = defaults.object(forKey: key) as? Int,
              let port = UInt16(exactly: value) else { return fallback }
        return port
    }

    func toggleServer() {
        if isRunning {
            killServer()
        } else {
            launchServer()
        }
    }

    func launchServer() {
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

    func buildArguments() -> [String] {
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
        
        // Custom launch arguments
        if !customLaunchArguments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            args.append(contentsOf: customLaunchArguments.split(separator: " ").map { String($0) })
        }

        return args
    }

    func killServer() {
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
            if str.contains("usb_claim_interface error") || str.contains("port already in use") || str.contains("No supported RTLSDR devices found.") || str.contains("Unknown or not enough arguments") {
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

    private func updateNetworkDiscovery() {
        guard !isRestoringSettings else { return }
        service?.stop()
        service = nil
        guard networkDiscoveryEnabled, netRoPort != 0 else { return }
        service = NetService(domain: "", type: "_maxplanes._tcp", name: "", port: Int32(netRoPort))
        service?.publish()
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
                    if !self.availableDevices.isEmpty,
                       !self.availableDevices.indices.contains(self.deviceIndex) {
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
