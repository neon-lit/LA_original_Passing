import Combine
@preconcurrency import CoreBluetooth
import Foundation
import SwiftUI

struct NearbySongEncounter: Identifiable, Hashable {
    let id: String
    let song: Song
    let encounteredAt: Date
}

@MainActor
final class NearbyPassingService: NSObject, ObservableObject {
    @Published private(set) var encounters: [NearbySongEncounter] = []
    @Published private(set) var connectedPeerCount = 0
    @Published private(set) var isRunning = false
    @Published private(set) var errorMessage: String?

    private static let serviceUUID = CBUUID(string: "786A8C20-436E-4DC7-9C2B-624991B46647")
    private static let songCharacteristicUUID = CBUUID(string: "11D40C20-035E-4D9B-BD50-70EE71E47C98")
    private static let maximumConnections = 12
    private static let minimumSignalStrength = -105
    private static let encounterDuration: TimeInterval = 4
    private static let maximumPacketSize = 480

    private let sessionToken = UUID().uuidString
    private var centralManager: CBCentralManager?
    private var peripheralManager: CBPeripheralManager?
    private var songCharacteristic: CBMutableCharacteristic?
    private var discoveredPeripherals: [UUID: CBPeripheral] = [:]
    private var lastSeenPeripheralAt: [UUID: Date] = [:]
    private var signalStrengths: [UUID: Int] = [:]
    private var peerTokensByPeripheralID: [UUID: String] = [:]
    private var firstSeenAt: [String: Date] = [:]
    private var completedPeerTokens = Set<String>()
    private var completedPeripheralIDs = Set<UUID>()
    private var exchangeTimer: Timer?
    private var currentSong: Song?

    func start(song: Song) {
        guard !isRunning else { return }
        currentSong = song
        encounters = []
        discoveredPeripherals = [:]
        lastSeenPeripheralAt = [:]
        signalStrengths = [:]
        peerTokensByPeripheralID = [:]
        firstSeenAt = [:]
        completedPeerTokens = []
        completedPeripheralIDs = []
        errorMessage = nil
        connectedPeerCount = 0
        isRunning = true

        centralManager = CBCentralManager(
            delegate: self,
            queue: .main,
            options: [
                CBCentralManagerOptionShowPowerAlertKey: true,
                CBCentralManagerOptionRestoreIdentifierKey: "app.passing.bluetooth.central"
            ]
        )
        peripheralManager = CBPeripheralManager(
            delegate: self,
            queue: .main,
            options: [
                CBPeripheralManagerOptionShowPowerAlertKey: true,
                CBPeripheralManagerOptionRestoreIdentifierKey: "app.passing.bluetooth.peripheral"
            ]
        )
        exchangeTimer = Timer.scheduledTimer(
            timeInterval: 1.5,
            target: self,
            selector: #selector(exchangeTimerFired),
            userInfo: nil,
            repeats: true
        )
    }

    func clearError() {
        errorMessage = nil
    }

    func stop() {
        exchangeTimer?.invalidate()
        exchangeTimer = nil
        centralManager?.stopScan()
        for peripheral in discoveredPeripherals.values where peripheral.state != .disconnected {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        peripheralManager?.stopAdvertising()
        peripheralManager?.removeAllServices()
        centralManager = nil
        peripheralManager = nil
        songCharacteristic = nil
        discoveredPeripherals = [:]
        lastSeenPeripheralAt = [:]
        signalStrengths = [:]
        peerTokensByPeripheralID = [:]
        completedPeripheralIDs = []
        connectedPeerCount = 0
        isRunning = false
        currentSong = nil
    }

    @objc private func exchangeTimerFired() {
        guard isRunning else { return }
        let expiryDate = Date().addingTimeInterval(-8)
        let expiredIDs = lastSeenPeripheralAt.compactMap { identifier, date in
            date < expiryDate ? identifier : nil
        }
        for identifier in expiredIDs {
            if let peripheral = discoveredPeripherals[identifier], peripheral.state != .disconnected {
                centralManager?.cancelPeripheralConnection(peripheral)
            }
            discoveredPeripherals[identifier] = nil
            lastSeenPeripheralAt[identifier] = nil
            signalStrengths[identifier] = nil
            if let peerToken = peerTokensByPeripheralID.removeValue(forKey: identifier),
               !completedPeerTokens.contains(peerToken) {
                firstSeenAt[peerToken] = nil
            }
        }

        for peripheral in discoveredPeripherals.values where peripheral.state == .connected {
            guard let service = peripheral.services?.first(where: { $0.uuid == Self.serviceUUID }),
                  let characteristic = service.characteristics?.first(where: {
                      $0.uuid == Self.songCharacteristicUUID
                  }) else { continue }
            peripheral.readValue(for: characteristic)
        }
        updateNearbyCount()
        connectToAvailablePeripherals()
    }

    private func configurePeripheralService() {
        guard isRunning, let peripheralManager, songCharacteristic == nil else { return }
        let characteristic = CBMutableCharacteristic(
            type: Self.songCharacteristicUUID,
            properties: [.read],
            value: nil,
            permissions: [.readable]
        )
        let service = CBMutableService(type: Self.serviceUUID, primary: true)
        service.characteristics = [characteristic]
        songCharacteristic = characteristic
        peripheralManager.add(service)
    }

    private func startAdvertising() {
        guard isRunning,
              let peripheralManager,
              peripheralManager.state == .poweredOn,
              !peripheralManager.isAdvertising else { return }
        peripheralManager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [Self.serviceUUID],
            CBAdvertisementDataLocalNameKey: "PASSING"
        ])
    }

    private func startScanning() {
        guard isRunning,
              let centralManager,
              centralManager.state == .poweredOn,
              !centralManager.isScanning else { return }
        centralManager.scanForPeripherals(
            withServices: [Self.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }

    private func connectToAvailablePeripherals() {
        guard let centralManager else { return }
        let activeConnectionCount = discoveredPeripherals.values.filter {
            $0.state == .connecting || $0.state == .connected
        }.count
        guard activeConnectionCount < Self.maximumConnections else { return }

        let connectionSlots = Self.maximumConnections - activeConnectionCount
        let candidates = discoveredPeripherals.values
            .filter { $0.state == .disconnected && !completedPeripheralIDs.contains($0.identifier) }
            .sorted {
                signalStrengths[$0.identifier, default: -100] > signalStrengths[$1.identifier, default: -100]
            }
            .prefix(connectionSlots)
        for peripheral in candidates {
            centralManager.connect(peripheral, options: nil)
        }
    }

    private func updateNearbyCount() {
        let activeSince = Date().addingTimeInterval(-6)
        let nearbyPeerTokens: Set<String> = Set(lastSeenPeripheralAt.compactMap { identifier, lastSeenAt in
            guard lastSeenAt >= activeSince,
                  let peerToken = peerTokensByPeripheralID[identifier],
                  peerToken != sessionToken else { return nil }
            return peerToken
        })
        connectedPeerCount = nearbyPeerTokens.count
    }

    private func currentPacketData() -> Data? {
        guard isRunning, let currentSong else { return nil }
        var bluetoothSong = BluetoothSong(song: currentSong)
        var packet = PassingPacket(
            peerToken: sessionToken,
            sentAt: Date().timeIntervalSince1970,
            song: bluetoothSong
        )
        guard var data = try? JSONEncoder().encode(packet) else { return nil }
        if data.count > Self.maximumPacketSize {
            bluetoothSong.previewURL = nil
            packet = PassingPacket(
                peerToken: sessionToken,
                sentAt: Date().timeIntervalSince1970,
                song: bluetoothSong
            )
            guard let smallerData = try? JSONEncoder().encode(packet) else { return nil }
            data = smallerData
        }
        if data.count > Self.maximumPacketSize {
            bluetoothSong.artworkURL = nil
            packet = PassingPacket(
                peerToken: sessionToken,
                sentAt: Date().timeIntervalSince1970,
                song: bluetoothSong
            )
            guard let smallestData = try? JSONEncoder().encode(packet) else { return nil }
            data = smallestData
        }
        return data.count <= Self.maximumPacketSize ? data : nil
    }

    private func receive(_ data: Data, from peripheral: CBPeripheral) {
        lastSeenPeripheralAt[peripheral.identifier] = .now
        updateNearbyCount()
        guard isRunning,
              let packet = try? JSONDecoder().decode(PassingPacket.self, from: data),
              packet.peerToken != sessionToken,
              abs(packet.sentAt - Date().timeIntervalSince1970) < 20,
              !completedPeerTokens.contains(packet.peerToken) else { return }

        peerTokensByPeripheralID[peripheral.identifier] = packet.peerToken
        guard signalStrengths[peripheral.identifier, default: -100] >= Self.minimumSignalStrength else {
            firstSeenAt[packet.peerToken] = nil
            return
        }

        let now = Date()
        if let firstSeen = firstSeenAt[packet.peerToken],
           now.timeIntervalSince(firstSeen) >= Self.encounterDuration {
            completedPeerTokens.insert(packet.peerToken)
            completedPeripheralIDs.insert(peripheral.identifier)
            encounters.append(
                NearbySongEncounter(id: packet.peerToken, song: packet.song.song, encounteredAt: now)
            )
            centralManager?.cancelPeripheralConnection(peripheral)
        } else if firstSeenAt[packet.peerToken] == nil {
            firstSeenAt[packet.peerToken] = now
        }
    }

    private func handleBluetoothState(_ state: CBManagerState) {
        guard isRunning else { return }
        switch state {
        case .poweredOff:
            errorMessage = "曲を交換するにはBluetoothをオンにしてください。"
        case .unauthorized:
            errorMessage = "設定アプリでPASSINGのBluetooth利用を許可してください。"
        case .unsupported:
            errorMessage = "この端末はBluetooth LE通信に対応していません。"
        default:
            break
        }
    }

    private struct PassingPacket: Codable {
        let peerToken: String
        let sentAt: TimeInterval
        let song: BluetoothSong

        private enum CodingKeys: String, CodingKey {
            case peerToken = "p"
            case sentAt = "d"
            case song = "s"
        }
    }

    private struct BluetoothSong: Codable {
        let title: String
        let artist: String
        let musicItemID: String?
        var artworkURL: URL?
        var previewURL: URL?

        init(song: Song) {
            title = song.title
            artist = song.artist
            musicItemID = song.musicItemID
            artworkURL = song.artworkURL
            previewURL = song.previewURL
        }

        var song: Song {
            Song(
                title: title,
                artist: artist,
                colors: [.blue, .indigo],
                musicItemID: musicItemID,
                artworkURL: artworkURL,
                previewURL: previewURL
            )
        }

        private enum CodingKeys: String, CodingKey {
            case title = "t"
            case artist = "a"
            case musicItemID = "i"
            case artworkURL = "w"
            case previewURL = "v"
        }
    }
}

extension NearbyPassingService: @preconcurrency CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        handleBluetoothState(central.state)
        if central.state == .poweredOn {
            errorMessage = nil
            startScanning()
        }
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        let restoredPeripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] ?? []
        for peripheral in restoredPeripherals {
            peripheral.delegate = self
            discoveredPeripherals[peripheral.identifier] = peripheral
            lastSeenPeripheralAt[peripheral.identifier] = .now
        }
        startScanning()
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard isRunning else { return }
        discoveredPeripherals[peripheral.identifier] = peripheral
        lastSeenPeripheralAt[peripheral.identifier] = .now
        if RSSI.intValue <= 0 {
            signalStrengths[peripheral.identifier] = RSSI.intValue
        }
        peripheral.delegate = self
        updateNearbyCount()
        connectToAvailablePeripherals()
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        lastSeenPeripheralAt[peripheral.identifier] = .now
        peripheral.discoverServices([Self.serviceUUID])
        updateNearbyCount()
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        lastSeenPeripheralAt[peripheral.identifier] = nil
        updateNearbyCount()
        connectToAvailablePeripherals()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        updateNearbyCount()
        connectToAvailablePeripherals()
    }
}

extension NearbyPassingService: @preconcurrency CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil,
              let service = peripheral.services?.first(where: { $0.uuid == Self.serviceUUID }) else {
            centralManager?.cancelPeripheralConnection(peripheral)
            return
        }
        peripheral.discoverCharacteristics([Self.songCharacteristicUUID], for: service)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard error == nil,
              let characteristic = service.characteristics?.first(where: {
                  $0.uuid == Self.songCharacteristicUUID
              }) else {
            centralManager?.cancelPeripheralConnection(peripheral)
            return
        }
        peripheral.readValue(for: characteristic)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil,
              characteristic.uuid == Self.songCharacteristicUUID,
              let data = characteristic.value else { return }
        receive(data, from: peripheral)
    }
}

extension NearbyPassingService: @preconcurrency CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        handleBluetoothState(peripheral.state)
        if peripheral.state == .poweredOn {
            errorMessage = nil
            configurePeripheralService()
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String: Any]) {
        if let restoredServices = dict[CBPeripheralManagerRestoredStateServicesKey] as? [CBMutableService],
           let restoredCharacteristic = restoredServices
            .compactMap(\.characteristics)
            .joined()
            .compactMap({ $0 as? CBMutableCharacteristic })
            .first(where: { $0.uuid == Self.songCharacteristicUUID }) {
            songCharacteristic = restoredCharacteristic
        }
        startAdvertising()
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        guard error == nil else {
            errorMessage = "Bluetoothで曲を公開できませんでした。"
            return
        }
        startAdvertising()
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if error != nil {
            errorMessage = "BluetoothでPASSINGを開始できませんでした。"
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        guard request.characteristic.uuid == Self.songCharacteristicUUID,
              let packetData = currentPacketData() else {
            peripheral.respond(to: request, withResult: .readNotPermitted)
            return
        }
        guard request.offset <= packetData.count else {
            peripheral.respond(to: request, withResult: .invalidOffset)
            return
        }
        request.value = packetData.subdata(in: request.offset..<packetData.count)
        peripheral.respond(to: request, withResult: .success)
    }
}
