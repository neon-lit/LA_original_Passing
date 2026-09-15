import Combine
@preconcurrency import CoreLocation
import Foundation
import MapKit

@MainActor
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var lastLocation: CLLocation?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isTracking = false
    @Published private(set) var placeName: String?
    @Published private(set) var address: String?

    private let manager = CLLocationManager()
    private var lastGeocodedLocation: CLLocation?
    private var wantsTracking = false

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 20
        manager.activityType = .other
        manager.pausesLocationUpdatesAutomatically = true
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    var statusText: String {
        switch authorizationStatus {
        case .notDetermined: "未設定"
        case .restricted: "利用できません"
        case .denied: "許可されていません"
        case .authorizedWhenInUse: "使用中のみ許可"
        case .authorizedAlways: "常に許可"
        @unknown default: "不明"
        }
    }

    var displayPlace: String {
        if let placeName, !placeName.isEmpty { return placeName }
        if let address, !address.isEmpty { return address }
        return lastLocation == nil ? "位置情報なし" : "現在地付近"
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func startTracking() {
        wantsTracking = true
        guard isAuthorized else {
            if authorizationStatus == .notDetermined {
                requestPermission()
            } else {
                errorMessage = "PASSINGを開始するには、設定から位置情報を許可してください。"
            }
            return
        }

        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
        isTracking = true
        errorMessage = nil
    }

    func stopTracking() {
        wantsTracking = false
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        manager.showsBackgroundLocationIndicator = false
        isTracking = false
    }

    func clearError() {
        errorMessage = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if wantsTracking, isAuthorized, !isTracking {
            startTracking()
        } else if authorizationStatus == .denied || authorizationStatus == .restricted {
            isTracking = false
            if wantsTracking {
                errorMessage = "PASSINGを開始するには、設定から位置情報を許可してください。"
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        lastLocation = location
        reverseGeocodeIfNeeded(location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard (error as? CLError)?.code != .locationUnknown else { return }
        errorMessage = "位置情報を取得できませんでした。設定と通信環境を確認してください。"
    }

    private func reverseGeocodeIfNeeded(_ location: CLLocation) {
        if let lastGeocodedLocation,
           location.distance(from: lastGeocodedLocation) < 100,
           placeName != nil || address != nil { return }

        lastGeocodedLocation = location
        Task {
            do {
                guard let request = MKReverseGeocodingRequest(location: location) else { return }
                request.preferredLocale = Locale(identifier: "ja_JP")
                let mapItems = try await request.mapItems
                guard let mapItem = mapItems.first else { return }
                let resolvedAddress = mapItem.address?.fullAddress
                    ?? mapItem.addressRepresentations?.fullAddress(includingRegion: false, singleLine: true)
                address = resolvedAddress
                placeName = mapItem.name?.isEmpty == false ? mapItem.name : resolvedAddress
            } catch {
                placeName = nil
            }
        }
    }
}
