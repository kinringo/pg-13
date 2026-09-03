// Models.swift — Shared (macOS + iOS)

import SwiftUI

// MARK: - Color + Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a,r,g,b) = (255,(int>>8)*17,(int>>4 & 0xF)*17,(int & 0xF)*17)
        case 6:  (a,r,g,b) = (255,int>>16,int>>8 & 0xFF,int & 0xFF)
        case 8:  (a,r,g,b) = (int>>24,int>>16 & 0xFF,int>>8 & 0xFF,int & 0xFF)
        default: (a,r,g,b) = (255,0,0,0)
        }
        self.init(.sRGB,
                  red:     Double(r)/255,
                  green:   Double(g)/255,
                  blue:    Double(b)/255,
                  opacity: Double(a)/255)
    }
}

// MARK: - PromptRecord

struct PromptRecord: Codable, Identifiable {
    let id: String
    let goal: String
    let role: String?
    let tone: String?
    let style: String?
    let generated_prompt: String
    let folder: String?
    let created_at: String
    let used: Bool?

    var displayDate: String {
        guard let date = Self.isoFull.date(from: created_at)
                      ?? Self.isoShort.date(from: created_at) else { return created_at }
        return Self.display.string(from: date)
    }

    private static let isoFull: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoShort: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    private static let display: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f
    }()
}

// MARK: - ServiceError

enum ServiceError: LocalizedError {
    case noAPIKey
    case httpError(Int, String)
    case decodingError(Error)
    case notConfigured
    case notSignedIn
    case emptyResponse
    case exportFailed(String)
    case emailConfirmationRequired
    case backendUnreachable

    var errorDescription: String? {
        switch self {
        case .noAPIKey:                    return "No Anthropic API key set."
        case .httpError(let code, let msg): return "HTTP \(code): \(msg)"
        case .decodingError(let e):         return "Decode error: \(e.localizedDescription)"
        case .notConfigured:               return "Sync backend not configured."
        case .notSignedIn:                 return "Sign in (History tab) to save and sync."
        case .emptyResponse:               return "Claude returned nothing. Try rewording the goal."
        case .exportFailed(let why):       return "Export failed. \(why)"
        case .emailConfirmationRequired:
            return "Account created. Click the link in the confirmation email, then sign in."
        case .backendUnreachable:
            return "Cannot reach the sync backend. Free Supabase projects pause after about a week idle. Open the Supabase dashboard and resume the project, then try again."
        }
    }
}

// MARK: - Anthropic Codable

struct ThinkingConfig: Codable {
    let type: String
}
struct AnthropicRequest: Codable {
    let model: String
    let max_tokens: Int
    let system: String
    let messages: [AnthropicMessage]
    var thinking: ThinkingConfig? = nil   // nil is omitted by JSONEncoder
}
struct AnthropicMessage: Codable {
    let role: String
    let content: String
}
struct AnthropicResponse: Codable {
    // text is optional so non-text blocks (e.g. thinking) decode without error
    struct Content: Codable { let type: String; let text: String? }
    let content: [Content]

    /// Concatenated text from all text-type blocks.
    var outputText: String {
        content.compactMap { $0.type == "text" ? $0.text : nil }.joined()
    }
}
struct AnthropicErrorResponse: Codable {
    struct ErrorDetail: Codable { let message: String }
    let error: ErrorDetail
}
