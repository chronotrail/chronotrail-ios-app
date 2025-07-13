//
//  SettingsView.swift
//  ChronoTrail
//
//  Created by Jong-Hee Kang on 7/11/25.
//

import SwiftUI
import CoreLocation

struct SettingsView: View {
    @ObservedObject var locationManager: LocationManager
    @StateObject private var uploadManager = UploadManager()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Location Tracking")) {
                    Toggle("Enable Location Tracking", isOn: $locationManager.isTrackingEnabled)
                    
                    if locationManager.isTrackingEnabled {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Status: Active")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text("Location will be recorded every 5 minutes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section(header: Text("Location Data")) {
                    HStack {
                        Text("Recorded Locations")
                        Spacer()
                        Text("\(locationManager.locationData.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    if !locationManager.locationData.isEmpty {
                        Button("Clear All Location Data") {
                            locationManager.clearLocationData()
                        }
                        .foregroundColor(.red)
                    }
                }
                
                Section(header: Text("Upload Entries")) {
                    HStack {
                        Text("Saved Entries")
                        Spacer()
                        Text("\(uploadManager.uploads.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    if !uploadManager.uploads.isEmpty {
                        NavigationLink("View All Entries") {
                            UploadHistoryView(uploadManager: uploadManager)
                        }
                        
                        Button("Clear All Entries") {
                            uploadManager.clearAllUploads()
                        }
                        .foregroundColor(.red)
                    }
                }
                
                if !locationManager.locationData.isEmpty {
                    Section(header: Text("Recent Locations")) {
                        ForEach(locationManager.locationData.suffix(5).reversed(), id: \.id) { location in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("📍 \(location.latitude, specifier: "%.6f"), \(location.longitude, specifier: "%.6f")")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                
                                Text(location.timestamp, style: .time)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                
                Section(header: Text("Permissions")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Location Permission")
                            .font(.subheadline)
                        
                        Text(locationPermissionStatus)
                            .font(.caption)
                            .foregroundColor(locationPermissionColor)
                    }
                    
                    if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                        Button("Open Settings") {
                            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(settingsUrl)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var locationPermissionStatus: String {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            return "Not requested"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .authorizedWhenInUse:
            return "When in use"
        case .authorizedAlways:
            return "Always (Recommended)"
        @unknown default:
            return "Unknown"
        }
    }
    
    private var locationPermissionColor: Color {
        switch locationManager.authorizationStatus {
        case .authorizedAlways:
            return .green
        case .authorizedWhenInUse:
            return .orange
        case .denied, .restricted:
            return .red
        default:
            return .secondary
        }
    }
}

// MARK: - Upload History View
struct UploadHistoryView: View {
    @ObservedObject var uploadManager: UploadManager
    
    var body: some View {
        List {
            ForEach(uploadManager.uploads.reversed()) { upload in
                VStack(alignment: .leading, spacing: 8) {
                    // Image if present
                    if let image = upload.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 150)
                            .cornerRadius(8)
                    }
                    
                    // Note
                    if !upload.note.isEmpty {
                        Text(upload.note)
                            .font(.body)
                    }
                    
                    // Timestamp
                    Text(upload.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let reversedIndex = uploadManager.uploads.count - 1 - index
                    let upload = uploadManager.uploads[reversedIndex]
                    uploadManager.deleteUpload(upload)
                }
            }
        }
        .navigationTitle("Upload History")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsView(locationManager: LocationManager())
}