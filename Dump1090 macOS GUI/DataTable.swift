//
//  DataTable.swift
//  Dump1090 macOS GUI
//
//  Created by Niko on 22.08.25.
//

import Network
import SwiftUI

// MARK: - Aircraft Model
struct Aircraft: Identifiable {
    let id: String
    var callsign: String
    var altitude: String
    var groundSpeed: String
    var track: String
    var latitude: String
    var longitude: String
}

// MARK: - ViewModel
@MainActor
class AircraftViewModel: ObservableObject {
    @StateObject private var serverManager = ServerManager()
    
    @Published var aircraftList: [Aircraft] = []
    private var aircraftDict: [String: Aircraft] = [:]
    private var connection: NWConnection?
        
    func start(host: String, port: UInt16) {
        let nwHost = NWEndpoint.Host(host)
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            print("Invalid port: \(port)")
            return
        }
        
        connection = NWConnection(host: nwHost, port: nwPort, using: .tcp)
        connection?.stateUpdateHandler = { state in
            print("Connection state: \(state)")
        }
        connection?.start(queue: .global())
        receive()
    }
    
    private func receive() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            if let data, let line = String(data: data, encoding: .utf8) {
                for row in line.split(separator: "\n") {
                    if row.starts(with: "MSG") {
                        Task { @MainActor in
                            self?.handleMessage(String(row))
                        }
                    }
                }
            }
            if isComplete == false && error == nil {
                Task { @MainActor in
                    self?.receive()
                }
            }
        }
    }
    
    private func handleMessage(_ msg: String) {
        let parts = msg.split(separator: ",", omittingEmptySubsequences: false).map { String($0) }
        guard parts.count >= 22 else { return }
        
        let hexIdent = parts[4]
        let newData = Aircraft(
            id: hexIdent,
            callsign: parts[10],
            altitude: parts[11],
            groundSpeed: parts[12],
            track: parts[13],
            latitude: parts[14],
            longitude: parts[15]
        )
        
        // merge with old table
        if var existing = aircraftDict[hexIdent] {
            if !newData.callsign.isEmpty { existing.callsign = newData.callsign }
            if !newData.altitude.isEmpty { existing.altitude = newData.altitude }
            if !newData.groundSpeed.isEmpty { existing.groundSpeed = newData.groundSpeed }
            if !newData.track.isEmpty { existing.track = newData.track }
            if !newData.latitude.isEmpty { existing.latitude = newData.latitude }
            if !newData.longitude.isEmpty { existing.longitude = newData.longitude }
            aircraftDict[hexIdent] = existing
        } else {
            aircraftDict[hexIdent] = newData
        }
        
        Task { @MainActor in
            self.aircraftList = Array(self.aircraftDict.values).sorted { $0.id < $1.id }
        }
    }
}

struct DataView: View {
    let host: String
    let port: UInt16
    
    @StateObject private var viewModel = AircraftViewModel()
    
    var body: some View {
        Table(viewModel.aircraftList) {
            TableColumn("HexIdent", value: \.id)
            TableColumn("Callsign", value: \.callsign)
            TableColumn("Altitude", value: \.altitude)
            TableColumn("Speed", value: \.groundSpeed)
            TableColumn("Track", value: \.track)
            TableColumn("Lat", value: \.latitude)
            TableColumn("Lon", value: \.longitude)
        }
        .frame(minWidth: 800, minHeight: 400)
        .onAppear {
            viewModel.start(host: host, port: port)
        }
    }
}
