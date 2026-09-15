import Combine
import CoreLocation
import Foundation
@preconcurrency import MultipeerConnectivity
import UIKit

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

    private static let serviceType = "passing-song"
    private let peerID = MCPeerID(displayName: "PASSING-\(UUID().uuidString.prefix(8))")
    private lazy var session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
    private lazy var advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: Self.serviceType)
    private lazy var browser = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
    private let sessionToken = UUID().uuidString
    private var currentSong: Song?
    private var currentLocation: CLLocation?
    private var firstSeenAt: [String: Date] = [:]
    private var completedPeerTokens = Set<String>()
    private var sendTimer: Timer?

    override init() {
        super.init()
        session.delegate = self
        advertiser.delegate = self
        browser.delegate = self
    }

    func start(song: Song, location: CLLocation?) {
        guard !isRunning else { return }
        currentSong = song
        currentLocation = location
        encounters = []
        firstSeenAt = [:]
        completedPeerTokens = []
        errorMessage = nil
        isRunning = true
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
        sendTimer = Timer.scheduledTimer(
            timeInterval: 3,
            target: self,
            selector: #selector(sendTimerFired),
            userInfo: nil,
            repeats: true
        )
        sendCurrentPacket()
    }

    func updateLocation(_ location: CLLocation?) {
        currentLocation = location
    }

    func clearError() {
        errorMessage = nil
    }

    func stop() {
        sendTimer?.invalidate()
        sendTimer = nil
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        session.disconnect()
        connectedPeerCount = 0
        isRunning = false
        currentSong = nil
        currentLocation = nil
    }

    private func sendCurrentPacket() {
        guard isRunning,
              let currentSong,
              !session.connectedPeers.isEmpty else { return }

        let packet = PassingPacket(
            peerToken: sessionToken,
            sentAt: .now,
            latitude: currentLocation?.coordinate.latitude,
            longitude: currentLocation?.coordinate.longitude,
            horizontalAccuracy: currentLocation?.horizontalAccuracy,
            song: currentSong
        )

        do {
            let data = try JSONEncoder().encode(packet)
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            errorMessage = "近くの端末へ曲を送信できませんでした。"
        }
    }

    @objc private func sendTimerFired() {
        sendCurrentPacket()
    }

    private func receive(_ data: Data) {
        guard isRunning,
              let packet = try? JSONDecoder().decode(PassingPacket.self, from: data),
              packet.peerToken != sessionToken,
              abs(packet.sentAt.timeIntervalSinceNow) < 20,
              !completedPeerTokens.contains(packet.peerToken),
              let currentLocation,
              let latitude = packet.latitude,
              let longitude = packet.longitude else { return }

        let remoteLocation = CLLocation(latitude: latitude, longitude: longitude)
        let distance = currentLocation.distance(from: remoteLocation)
        let accuracyAllowance = min(
            max(currentLocation.horizontalAccuracy, 0) + max(packet.horizontalAccuracy ?? 0, 0),
            30
        )
        guard distance <= 50 + accuracyAllowance else {
            firstSeenAt[packet.peerToken] = nil
            return
        }

        let now = Date()
        if let firstSeen = firstSeenAt[packet.peerToken], now.timeIntervalSince(firstSeen) >= 10 {
            completedPeerTokens.insert(packet.peerToken)
            encounters.append(
                NearbySongEncounter(id: packet.peerToken, song: packet.song, encounteredAt: now)
            )
        } else if firstSeenAt[packet.peerToken] == nil {
            firstSeenAt[packet.peerToken] = now
        }
    }

    private struct PassingPacket: Codable {
        let peerToken: String
        let sentAt: Date
        let latitude: Double?
        let longitude: Double?
        let horizontalAccuracy: Double?
        let song: Song
    }
}

extension NearbyPassingService: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor [weak self] in
            self?.connectedPeerCount = session.connectedPeers.count
            if state == .connected { self?.sendCurrentPacket() }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        Task { @MainActor [weak self] in self?.receive(data) }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension NearbyPassingService: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        Task { @MainActor [weak self] in
            invitationHandler(true, self?.session)
        }
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        Task { @MainActor [weak self] in self?.errorMessage = "近距離通信を開始できませんでした。" }
    }
}

extension NearbyPassingService: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor [weak self] in
            guard let self, self.peerID.displayName < peerID.displayName else { return }
            self.browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 15)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        Task { @MainActor [weak self] in self?.errorMessage = "近くのPASSINGユーザーを検索できませんでした。" }
    }
}
