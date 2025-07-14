//
//  UploadView.swift
//  ChronoTrail
//
//  Created by Jong-Hee Kang on 7/11/25.
//

import SwiftUI
import UIKit
import Combine

// MARK: - Upload Entry Model
struct UploadEntry: Identifiable, Codable {
    let id = UUID()
    let note: String
    let timestamp: Date
    let hasImage: Bool
    
    // We can't store UIImage in Codable, so we'll save it separately
    var image: UIImage? = nil
    
    enum CodingKeys: String, CodingKey {
        case id, note, timestamp, hasImage
    }
}

// MARK: - Upload Manager
class UploadManager: ObservableObject {
    @Published var uploads: [UploadEntry] = []
    
    init() {
        loadUploads()
    }
    
    func addUpload(note: String, image: UIImage?) {
        let upload = UploadEntry(
            note: note,
            timestamp: Date(),
            hasImage: image != nil
        )
        
        var uploadWithImage = upload
        uploadWithImage.image = image
        
        uploads.append(uploadWithImage)
        saveUploads()
        
        // Save image separately if exists
        if let image = image {
            saveImage(image, for: upload.id)
        }
    }
    
    func deleteUpload(_ upload: UploadEntry) {
        uploads.removeAll { $0.id == upload.id }
        saveUploads()
        
        // Delete associated image
        deleteImage(for: upload.id)
    }
    
    func clearAllUploads() {
        // Delete all images
        for upload in uploads {
            deleteImage(for: upload.id)
        }
        
        uploads.removeAll()
        UserDefaults.standard.removeObject(forKey: "savedUploads")
    }
    
    private func saveUploads() {
        if let encoded = try? JSONEncoder().encode(uploads.map { upload in
            UploadEntry(note: upload.note, timestamp: upload.timestamp, hasImage: upload.hasImage)
        }) {
            UserDefaults.standard.set(encoded, forKey: "savedUploads")
        }
    }
    
    private func loadUploads() {
        if let data = UserDefaults.standard.data(forKey: "savedUploads"),
           let decoded = try? JSONDecoder().decode([UploadEntry].self, from: data) {
            
            // Load uploads and their associated images
            uploads = decoded.map { upload in
                var uploadWithImage = upload
                uploadWithImage.image = loadImage(for: upload.id)
                return uploadWithImage
            }
        }
    }
    
    private func saveImage(_ image: UIImage, for id: UUID) {
        if let data = image.jpegData(compressionQuality: 0.8) {
            let url = getImageURL(for: id)
            try? data.write(to: url)
        }
    }
    
    private func loadImage(for id: UUID) -> UIImage? {
        let url = getImageURL(for: id)
        if let data = try? Data(contentsOf: url) {
            return UIImage(data: data)
        }
        return nil
    }
    
    private func deleteImage(for id: UUID) {
        let url = getImageURL(for: id)
        try? FileManager.default.removeItem(at: url)
    }
    
    private func getImageURL(for id: UUID) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("\(id.uuidString).jpg")
    }
}

// MARK: - Upload View
struct UploadView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var noteText = ""
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingActionSheet = false
    @State private var imagePickerSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var isUploading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    @StateObject private var audioRecorder = AudioRecorder()
    
    let onUpload: (String, UIImage?) -> Void
    private let uploadService = UploadAPIService()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Image Section
                    imageSection
                    
                    // Voice Section
                    voiceSection
                    
                    // Note Section
                    noteSection
                    
                    // Upload Button
                    uploadButton
                }
                .padding()
            }
            .navigationTitle("Add Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if audioRecorder.isRecording {
                            audioRecorder.stopRecording()
                        }
                        if audioRecorder.isPlaying {
                            audioRecorder.stopPlaying()
                        }
                        dismiss()
                    }
                    .disabled(isUploading)
                }
            }
            .disabled(isUploading)
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(sourceType: imagePickerSourceType) { image in
                selectedImage = image
            }
        }
        .actionSheet(isPresented: $showingActionSheet) {
            ActionSheet(
                title: Text("Add Photo"),
                buttons: [
                    .default(Text("Camera")) {
                        imagePickerSourceType = .camera
                        showingImagePicker = true
                    },
                    .default(Text("Photo Library")) {
                        imagePickerSourceType = .photoLibrary
                        showingImagePicker = true
                    },
                    .cancel()
                ]
            )
        }
        .alert("Upload Status", isPresented: $showingAlert) {
            Button("OK") {
                if alertMessage.contains("successful") {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }

    private var imageSection: some View {
        VStack(spacing: 12) {
            Text("Photo (Optional)")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if let image = selectedImage {
                // Show selected image
                VStack(spacing: 12) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .cornerRadius(12)
                        .shadow(radius: 2)
                    
                    HStack(spacing: 16) {
                        Button("Change Photo") {
                            showingActionSheet = true
                        }
                        .foregroundColor(.blue)
                        
                        Button("Remove") {
                            selectedImage = nil
                        }
                        .foregroundColor(.red)
                    }
                    .font(.subheadline)
                }
            } else {
                // Add photo button
                Button(action: {
                    showingActionSheet = true
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 40))
                        Text("Add Photo")
                            .font(.subheadline)
                    }
                    .foregroundColor(.blue)
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private var voiceSection: some View {
        VStack(spacing: 12) {
            Text("Voice Note (Optional)")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if !audioRecorder.permissionGranted {
                VStack(spacing: 8) {
                    Image(systemName: "mic.slash")
                        .font(.system(size: 30))
                        .foregroundColor(.red)
                    Text("Microphone permission required")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button(action: {
                        audioRecorder.requestPermission { _ in }
                    }) {
                        Text(audioRecorder.permissionGranted ? "Permission Granted" : "Request Permission")
                    }
                    .disabled(audioRecorder.permissionGranted)
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .frame(height: 100)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else if audioRecorder.hasRecording {
                // Show recording controls
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundColor(.blue)
                        Text("Voice note recorded")
                            .font(.subheadline)
                        Spacer()
                        Text(audioRecorder.formattedRecordingTime)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 20) {
                        Button(action: {
                            if audioRecorder.isPlaying {
                                audioRecorder.stopPlaying()
                            } else {
                                audioRecorder.playRecording()
                            }
                        }) {
                            Image(systemName: audioRecorder.isPlaying ? "stop.fill" : "play.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        
                        Button("Record Again") {
                            audioRecorder.deleteRecording()
                        }
                        .foregroundColor(.orange)
                        
                        Button("Delete") {
                            audioRecorder.deleteRecording()
                        }
                        .foregroundColor(.red)
                    }
                    .font(.subheadline)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else if audioRecorder.isRecording {
                // Recording in progress
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "record.circle")
                            .foregroundColor(.red)
                            .font(.title)
                        VStack(alignment: .leading) {
                            Text("Recording...")
                                .font(.subheadline)
                                .foregroundColor(.red)
                            Text("Time: \(audioRecorder.formattedRecordingTime)")
                                .font(.caption)
                            Text("Remaining: \(audioRecorder.timeRemaining)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    
                    Button("Finish Recording") {
                        audioRecorder.stopRecording()
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                // Start recording button
                Button(action: {
                    audioRecorder.startRecording()
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "mic.badge.plus")
                            .font(.system(size: 40))
                        Text("Add Voice Note")
                            .font(.subheadline)
                        Text("Max 30 seconds")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .foregroundColor(.blue)
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private var noteSection: some View {
        VStack(spacing: 12) {
            Text("Note")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            TextField("Enter your note here...", text: $noteText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(5...10)
        }
    }
    
    private var uploadButton: some View {
        Button(action: {
            uploadEntry()
        }) {
            HStack {
                if isUploading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                
                Text(isUploading ? "Uploading..." : "Save Entry")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(canUpload && !isUploading ? Color.blue : Color.gray)
            .cornerRadius(12)
        }
        .disabled(!canUpload || isUploading)
    }
    
    private var canUpload: Bool {
        !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || 
        selectedImage != nil || 
        audioRecorder.hasRecording
    }
    
    private func uploadEntry() {
        isUploading = true
        
        Task {
            do {
                let response = try await uploadService.uploadEntry(
                    note: noteText, 
                    image: selectedImage,
                    voiceData: audioRecorder.getRecordingData()
                )
                
                await MainActor.run {
                    isUploading = false
                    
                    // Save locally after successful API upload
                    onUpload(noteText, selectedImage)
                    
                    alertMessage = "Upload successful! \(response)"
                    showingAlert = true
                }
            } catch {
                await MainActor.run {
                    isUploading = false
                    alertMessage = "Upload failed: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
}

// MARK: - Upload API Service
class UploadAPIService {
    private let baseURL = "https://www.my-mock.com"
    
    func uploadEntry(note: String, image: UIImage?, voiceData: Data?) async throws -> String {
        guard let url = URL(string: "\(baseURL)/upload") else {
            throw UploadAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Prepare image data
        var imageBase64: String? = nil
        if let image = image,
           let imageData = image.jpegData(compressionQuality: 0.8) {
            imageBase64 = imageData.base64EncodedString()
        }
        
        // Prepare voice data
        var voiceBase64: String? = nil
        if let voiceData = voiceData {
            voiceBase64 = voiceData.base64EncodedString()
        }
        
        let requestBody = UploadRequest(
            note: note,
            imageData: imageBase64,
            voiceData: voiceBase64,
            timestamp: Date().timeIntervalSince1970
        )
        
        let jsonData = try JSONEncoder().encode(requestBody)
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UploadAPIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            throw UploadAPIError.serverError(statusCode: httpResponse.statusCode)
        }
        
        let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: data)
        return uploadResponse.message
    }
}

// MARK: - Upload API Models
struct UploadRequest: Codable {
    let note: String
    let imageData: String?
    let voiceData: String?
    let timestamp: TimeInterval
}

struct UploadResponse: Codable {
    let message: String
    let id: String?
    let success: Bool
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        message = try container.decodeIfPresent(String.self, forKey: .message) ?? "Upload completed"
        id = try container.decodeIfPresent(String.self, forKey: .id)
        success = try container.decodeIfPresent(Bool.self, forKey: .success) ?? true
    }
    
    enum CodingKeys: String, CodingKey {
        case message, id, success
    }
}

// MARK: - Upload API Errors
enum UploadAPIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int)
    case encodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid upload URL"
        case .invalidResponse:
            return "Invalid server response"
        case .serverError(let statusCode):
            return "Server error (Status: \(statusCode))"
        case .encodingError:
            return "Failed to encode upload data"
        }
    }
}

#Preview {
    UploadView { note, image in
        print("Uploaded: \(note)")
    }
}
