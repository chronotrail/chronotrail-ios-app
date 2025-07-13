//
//  ContentView.swift
//  ChronoTrail
//
//  Created by Jong-Hee Kang on 7/11/25.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isTyping = false
    @State private var showingImagePicker = false
    @State private var showingActionSheet = false
    @State private var showingSettings = false
    @State private var showingUpload = false
    @State private var imagePickerSourceType: UIImagePickerController.SourceType = .photoLibrary
    
    private let apiService = ChatAPIService()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var uploadManager = UploadManager()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Chat Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                        }
                        
                        if isTyping {
                            TypingIndicator()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .onChange(of: messages.count) { _, _ in
                    if let lastMessage = messages.last {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Input Area
            inputArea
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            addInitialMessage()
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(sourceType: imagePickerSourceType) { image in
                handleSelectedImage(image)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(locationManager: locationManager)
        }
        .sheet(isPresented: $showingUpload) {
            UploadView { note, image in
                uploadManager.addUpload(note: note, image: image)
            }
        }
        .actionSheet(isPresented: $showingActionSheet) {
            ActionSheet(
                title: Text("Select Image"),
                buttons: actionSheetButtons()
            )
        }
    }
    
    private var headerView: some View {
        HStack {
            Text("ChronoTrail AI")
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            HStack(spacing: 16) {
                // Location tracking indicator
                if locationManager.isTrackingEnabled {
                    Image(systemName: "location.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 16))
                }
                
                // Upload button
                Button(action: { showingUpload = true }) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.blue)
                }
                
                // Settings button
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gear")
                        .foregroundColor(.secondary)
                }
                
                Button(action: clearChat) {
                    Image(systemName: "trash")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
    }
    
    private var inputArea: some View {
        HStack(spacing: 12) {
            // Photo button
            Button(action: {
                showingActionSheet = true
            }) {
                Image(systemName: "plus")
                    .foregroundColor(.blue)
                    .font(.system(size: 18))
            }
            
            TextField("Type a message...", text: $inputText, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(1...4)
            
            Button(action: sendMessage) {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(inputText.isEmpty ? .secondary : .blue)
                    .font(.system(size: 18))
            }
            .disabled(inputText.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: -1)
    }
    
    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = ChatMessage(
            id: UUID(),
            content: inputText,
            isUser: true,
            timestamp: Date()
        )
        
        messages.append(userMessage)
        let messageContent = inputText
        inputText = ""
        
        // Send message to API service
        sendMessageToAPI(messageContent)
    }
    
    private func sendMessageToAPI(_ message: String) {
        isTyping = true
        
        Task {
            do {
                let response = try await apiService.sendMessage(message)
                
                await MainActor.run {
                    isTyping = false
                    
                    let aiMessage = ChatMessage(
                        id: UUID(),
                        content: response,
                        isUser: false,
                        timestamp: Date()
                    )
                    
                    messages.append(aiMessage)
                }
            } catch {
                await MainActor.run {
                    isTyping = false
                    
                    let errorMessage = ChatMessage(
                        id: UUID(),
                        content: "Sorry, I encountered an error: \(error.localizedDescription)",
                        isUser: false,
                        timestamp: Date()
                    )
                    
                    messages.append(errorMessage)
                }
            }
        }
    }
    
    private func addInitialMessage() {
        let welcomeMessage = ChatMessage(
            id: UUID(),
            content: "Hello! I'm ChronoTrail AI. How can I help you today?",
            isUser: false,
            timestamp: Date()
        )
        messages.append(welcomeMessage)
    }
    
    private func clearChat() {
        messages.removeAll()
        addInitialMessage()
    }
    
    private func actionSheetButtons() -> [ActionSheet.Button] {
        var buttons: [ActionSheet.Button] = []
        
        // Add camera option only if camera is available
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            buttons.append(.default(Text("Camera")) {
                imagePickerSourceType = .camera
                showingImagePicker = true
            })
        }
        
        // Add photo library option
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            buttons.append(.default(Text("Photo Library")) {
                imagePickerSourceType = .photoLibrary
                showingImagePicker = true
            })
        }
        
        buttons.append(.cancel())
        return buttons
    }
    
    private func handleSelectedImage(_ image: UIImage) {
        let imageMessage = ChatMessage(
            id: UUID(),
            content: "",
            isUser: true,
            timestamp: Date(),
            image: image
        )
        
        messages.append(imageMessage)
        
        // Send image to API service
        sendImageToAPI(image)
    }
    
    private func sendImageToAPI(_ image: UIImage) {
        isTyping = true
        
        Task {
            do {
                let response = try await apiService.sendImage(image)
                
                await MainActor.run {
                    isTyping = false
                    
                    let aiMessage = ChatMessage(
                        id: UUID(),
                        content: response,
                        isUser: false,
                        timestamp: Date()
                    )
                    
                    messages.append(aiMessage)
                }
            } catch {
                await MainActor.run {
                    isTyping = false
                    
                    let errorMessage = ChatMessage(
                        id: UUID(),
                        content: "Sorry, I couldn't process the image: \(error.localizedDescription)",
                        isUser: false,
                        timestamp: Date()
                    )
                    
                    messages.append(errorMessage)
                }
            }
        }
    }
}

// MARK: - Chat Message Model
struct ChatMessage: Identifiable {
    let id: UUID
    let content: String
    let isUser: Bool
    let timestamp: Date
    let image: UIImage?
    
    init(id: UUID, content: String, isUser: Bool, timestamp: Date, image: UIImage? = nil) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.image = image
    }
}

// MARK: - Message Bubble View
struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
                    // Image if present
                    if let image = message.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 200, maxHeight: 200)
                            .cornerRadius(12)
                    }
                    
                    // Text content if present
                    if !message.content.isEmpty {
                        Text(message.content)
                            .multilineTextAlignment(message.isUser ? .trailing : .leading)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(message.isUser ? Color.blue : Color(.systemGray5))
                .foregroundColor(message.isUser ? .white : .primary)
                .cornerRadius(18)
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !message.isUser {
                Spacer()
            }
        }
    }
}

// MARK: - Typing Indicator
struct TypingIndicator: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.secondary)
                            .frame(width: 8, height: 8)
                            .offset(y: animationOffset)
                            .animation(
                                .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                                value: animationOffset
                            )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray5))
                .cornerRadius(18)
                
                Text("AI is typing...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .onAppear {
            animationOffset = -4
        }
    }
}

// MARK: - Chat API Service
class ChatAPIService {
    private let baseURL = "https://www.mock-url.com/mock-api"
    
    func sendMessage(_ message: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/chat") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = ChatRequest(message: message)
        let jsonData = try JSONEncoder().encode(requestBody)
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        
        let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
        return chatResponse.response
    }
    
    func sendImage(_ image: UIImage) async throws -> String {
        guard let url = URL(string: "\(baseURL)/image") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Convert image to base64 for JSON transmission
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw APIError.imageProcessingFailed
        }
        
        let base64String = imageData.base64EncodedString()
        let requestBody = ImageRequest(imageData: base64String)
        let jsonData = try JSONEncoder().encode(requestBody)
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        
        let imageResponse = try JSONDecoder().decode(ImageResponse.self, from: data)
        return imageResponse.response
    }
}

// MARK: - API Models
struct ChatRequest: Codable {
    let message: String
}

struct ChatResponse: Codable {
    let response: String
}

struct ImageRequest: Codable {
    let imageData: String
}

struct ImageResponse: Codable {
    let response: String
}

// MARK: - API Errors
enum APIError: Error, LocalizedError {
    case invalidURL
    case serverError
    case imageProcessingFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .serverError:
            return "Server error occurred"
        case .imageProcessingFailed:
            return "Failed to process image"
        }
    }
}


#Preview {
    ContentView()
}
