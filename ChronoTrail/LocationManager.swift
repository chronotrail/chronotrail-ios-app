//
//  LocationManager.swift
//  ChronoTrail
//
//  Created by Jong-Hee Kang on 7/11/25.
//

import Foundation
import CoreLocation
import Combine

// MARK: - Location Data Model
struct LocationData: Identifiable, Codable {
    let id = UUID()
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    let accuracy: Double
}

// MARK: - Location Manager
class LocationManager: NSObject, ObservableObject {
    private let manager = CLLocationManager()
    private var locationTimer: Timer?
    private var lastLocationTime: Date?
    
    @Published var isTrackingEnabled = false {
        didSet {
            if isTrackingEnabled {
                startLocationTracking()
            } else {
                stopLocationTracking()
            }
        }
    }
    
    @Published var locationData: [LocationData] = []
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 50 // Update when user moves 50 meters
        
        // Configure for background location
        manager.allowsBackgroundLocationUpdates = false // Will be set to true when tracking starts
        manager.pausesLocationUpdatesAutomatically = false
        
        // Load saved location data
        loadLocationData()
        
        // Load tracking preference
        isTrackingEnabled = UserDefaults.standard.bool(forKey: "locationTrackingEnabled")
    }
    
    func requestLocationPermission() {
        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            // Show alert to go to settings
            break
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        case .authorizedAlways:
            break
        @unknown default:
            break
        }
    }
    
    private func startLocationTracking() {
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else {
            requestLocationPermission()
            return
        }
        
        UserDefaults.standard.set(true, forKey: "locationTrackingEnabled")
        
        // Enable background location updates (requires "Always" permission)
        if authorizationStatus == .authorizedAlways {
            manager.allowsBackgroundLocationUpdates = true
        }
        
        // Start continuous location updates (works in background)
        manager.startUpdatingLocation()
        
        // Also monitor significant location changes (more battery efficient for background)
        manager.startMonitoringSignificantLocationChanges()
        
        // Set up timer for foreground periodic updates
        setupLocationTimer()
    }
    
    private func stopLocationTracking() {
        UserDefaults.standard.set(false, forKey: "locationTrackingEnabled")
        
        manager.allowsBackgroundLocationUpdates = false
        manager.stopUpdatingLocation()
        manager.stopMonitoringSignificantLocationChanges()
        
        locationTimer?.invalidate()
        locationTimer = nil
    }
    
    private func setupLocationTimer() {
        locationTimer?.invalidate()
        
        // Timer works in foreground, location updates work in background
        locationTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            // This ensures we get updates when app is in foreground
            self.manager.requestLocation()
        }
    }
    
    private func shouldRecordLocation() -> Bool {
        // Record location if:
        // 1. It's the first location, OR
        // 2. 5 minutes have passed since last recorded location
        
        guard let lastTime = lastLocationTime else {
            return true // First location
        }
        
        let timeSinceLastLocation = Date().timeIntervalSince(lastTime)
        return timeSinceLastLocation >= 300 // 5 minutes = 300 seconds
    }
    
    private func addLocationData(_ location: CLLocation) {
        // Only record if 5 minutes have passed or it's the first location
        guard shouldRecordLocation() else { return }
        
        let locationData = LocationData(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            timestamp: Date(),
            accuracy: location.horizontalAccuracy
        )
        
        self.locationData.append(locationData)
        self.lastLocationTime = Date()
        saveLocationData()
        
        print("📍 Location recorded: \(locationData.latitude), \(locationData.longitude) at \(locationData.timestamp)")
    }
    
    private func saveLocationData() {
        if let encoded = try? JSONEncoder().encode(locationData) {
            UserDefaults.standard.set(encoded, forKey: "savedLocationData")
        }
        
        // Also save the last location time
        UserDefaults.standard.set(lastLocationTime, forKey: "lastLocationTime")
    }
    
    private func loadLocationData() {
        if let data = UserDefaults.standard.data(forKey: "savedLocationData"),
           let decoded = try? JSONDecoder().decode([LocationData].self, from: data) {
            locationData = decoded
        }
        
        // Load last location time
        if let savedTime = UserDefaults.standard.object(forKey: "lastLocationTime") as? Date {
            lastLocationTime = savedTime
        }
    }
    
    func clearLocationData() {
        locationData.removeAll()
        lastLocationTime = nil
        UserDefaults.standard.removeObject(forKey: "savedLocationData")
        UserDefaults.standard.removeObject(forKey: "lastLocationTime")
    }
}

// MARK: - Core Location Delegate
extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Only add location if accuracy is reasonable (within 100 meters)
        if location.horizontalAccuracy < 100 {
            addLocationData(location)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
            
            if status == .authorizedAlways {
                if self.isTrackingEnabled {
                    self.startLocationTracking()
                }
            } else if status == .authorizedWhenInUse {
                if self.isTrackingEnabled {
                    self.startLocationTracking()
                }
            } else if status == .denied || status == .restricted {
                self.isTrackingEnabled = false
            }
        }
    }
}
