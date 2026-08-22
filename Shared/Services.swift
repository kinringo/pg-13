// Services.swift — Shared (macOS + iOS)

import Foundation
import Combine

// MARK: - ClaudeService

class ClaudeService {
    static let shared = ClaudeService()
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    func getAPIKey() -> String? {
        if let envKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        return KeychainHelper.load(key: "anthropic_api_key")
    }

    func generate(systemPrompt: String, userMessage: String,
                  maxTokens: Int = 512) async throws -> String {
        guard let apiKey = getAPIKey() else { throw ServiceError.noAPIKey }

        let body = AnthropicRequest(
            model: "claude-sonnet-5",
            max_tokens: maxTokens,
            system: systemPrompt,
            messages: [AnthropicMessage(role: "user", content: userMessage)],
            thinking: ThinkingConfig(type: "disabled")   // fast path; no thinking blocks in response
        )

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json",  forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey,              forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01",        forHTTPHeaderField: "anthropic-version")
        req.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let msg = (try? JSONDecoder().decode(AnthropicErrorResponse.self, from: data))?.error.message
                   ?? "Request rejected."
            throw ServiceError.httpError(http.statusCode, msg)
        }
        let decoded: AnthropicResponse
        do {
            decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        } catch {
            throw ServiceError.decodingError(error)
        }
        // A 200 with no text block (refusal, or a stop before any text was emitted)
        // would otherwise leave the UI sitting on an unchanged, empty result.
        let text = decoded.outputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw ServiceError.emptyResponse }
        return text
    }
}

// MARK: - Supabase configuration

enum SupabaseConfig {
    /// From Supabase → Project Settings → API. The publishable key is meant to
    /// ship in the client: it grants nothing on its own. Every row is gated by
    /// row-level security on `auth.uid()`, and requests carry a per-user JWT.
    /// See the README for the table and policy this depends on.
    static let url = "https://kxkpewnebbftderbizph.supabase.co"
    static let anonKey = "sb_publishable_SVoScLJoPc7fzGSdfyh3Iw_0KolcA_7"
    static var isConfigured: Bool { !url.isEmpty && !anonKey.isEmpty }
}

// MARK: - AuthService (Supabase Auth, session in Keychain)

struct AuthSession: Codable {
    let access_token: String
    let refresh_token: String
    let expires_at: TimeInterval   // unix seconds, minus a safety margin
    let email: String
}

@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published private(set) var session: AuthSession?
    var isSignedIn: Bool { session != nil }
    var email: String? { session?.email }

    private init() {
        if let json = KeychainHelper.load(key: "supabase_session"),
           let data = json.data(using: .utf8) {
            session = try? JSONDecoder().decode(AuthSession.self, from: data)
        }
    }

    private func persist(_ s: AuthSession?) {
        session = s
        if let s, let data = try? JSONEncoder().encode(s),
           let json = String(data: data, encoding: .utf8) {
            KeychainHelper.save(json, key: "supabase_session")
        } else {
            KeychainHelper.delete(key: "supabase_session")
        }
    }

    private struct TokenResponse: Codable {
        let access_token: String
        let refresh_token: String
        let expires_in: Int
        struct User: Codable { let email: String? }
        let user: User?
    }

    private func authRequest(path: String, body: [String: String]) async throws -> TokenResponse {
        guard SupabaseConfig.isConfigured else { throw ServiceError.notConfigured }
        var req = URLRequest(url: URL(string: "\(SupabaseConfig.url)/auth/v1/\(path)")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode >= 300 {
            struct AuthError: Codable { let msg: String?; let error_description: String?; let message: String? }
            let e = try? JSONDecoder().decode(AuthError.self, from: data)
            throw ServiceError.httpError(http.statusCode,
                e?.msg ?? e?.error_description ?? e?.message ?? "Authentication failed")
        }
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    private func makeSession(_ t: TokenResponse, fallbackEmail: String) -> AuthSession {
        AuthSession(access_token: t.access_token,
                    refresh_token: t.refresh_token,
                    expires_at: Date().timeIntervalSince1970 + Double(t.expires_in) - 60,
                    email: t.user?.email ?? fallbackEmail)
    }

    func signIn(email: String, password: String) async throws {
        let t = try await authRequest(path: "token?grant_type=password",
                                      body: ["email": email, "password": password])
        persist(makeSession(t, fallbackEmail: email))
        await CloudHistoryStore.shared.migrateLocalIfNeeded()
    }

    func signUp(email: String, password: String) async throws {
        _ = try await authRequest(path: "signup", body: ["email": email, "password": password])
        try await signIn(email: email, password: password)
    }

    func signOut() { persist(nil) }

    /// The single in-flight refresh, if one is running. Supabase rotates refresh
    /// tokens on use, so two concurrent refreshes would invalidate each other and
    /// silently sign the user out. Callers share one Task instead.
    private var refreshTask: Task<String, Error>?

    /// Returns a live access token, refreshing via the stored refresh token if expired.
    func validAccessToken() async throws -> String {
        guard let s = session else { throw ServiceError.notSignedIn }
        if Date().timeIntervalSince1970 < s.expires_at { return s.access_token }

        if let existing = refreshTask { return try await existing.value }

        let task = Task<String, Error> { [weak self] in
            guard let self else { throw ServiceError.notSignedIn }
            do {
                let t = try await self.authRequest(path: "token?grant_type=refresh_token",
                                                   body: ["refresh_token": s.refresh_token])
                let renewed = self.makeSession(t, fallbackEmail: s.email)
                self.persist(renewed)
                return renewed.access_token
            } catch {
                // Refresh token rejected → session is dead; force a fresh sign-in.
                if case ServiceError.httpError = error { self.persist(nil) }
                throw error
            }
        }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }
}

// MARK: - CloudHistoryStore (Supabase + RLS, per-user rows)

class CloudHistoryStore {
    static let shared = CloudHistoryStore()
    private let table = "prompt_history"

    private func makeRequest(queryItems: [URLQueryItem], method: String,
                             body: Data? = nil, prefer: String? = nil) async throws -> URLRequest {
        guard SupabaseConfig.isConfigured else { throw ServiceError.notConfigured }
        let token = try await AuthService.shared.validAccessToken()
        var comps = URLComponents(string: "\(SupabaseConfig.url)/rest/v1/\(table)")!
        if !queryItems.isEmpty { comps.queryItems = queryItems }
        var req = URLRequest(url: comps.url!)
        req.httpMethod = method
        req.setValue("application/json",     forHTTPHeaderField: "Content-Type")
        req.setValue("application/json",     forHTTPHeaderField: "Accept")
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)",      forHTTPHeaderField: "Authorization")
        if let prefer { req.setValue(prefer, forHTTPHeaderField: "Prefer") }
        req.httpBody = body
        return req
    }

    /// PostgREST reads `,` `.` `(` `)` as filter syntax. Quoting the operand keeps
    /// folder names like "Q4, drafts" from silently altering the query.
    private func eq(_ value: String) -> String {
        "eq.\"\(value.replacingOccurrences(of: "\"", with: "\\\""))\""
    }

    private func run(_ req: URLRequest, _ action: String) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode >= 300 {
            // PostgREST returns a structured error. Surface only its message, never
            // the raw body, which can echo row contents back into the UI.
            struct RESTError: Codable { let message: String? }
            let detail = (try? JSONDecoder().decode(RESTError.self, from: data))?.message
            throw ServiceError.httpError(http.statusCode, "\(action) failed. \(detail ?? "")")
        }
        return data
    }

    func fetchHistory() async throws -> [PromptRecord] {
        let req = try await makeRequest(queryItems: [
            URLQueryItem(name: "order", value: "created_at.desc"),
            URLQueryItem(name: "limit", value: "50"),
        ], method: "GET")
        let data = try await run(req, "Load history")
        do { return try JSONDecoder().decode([PromptRecord].self, from: data) }
        catch { throw ServiceError.decodingError(error) }
    }

    func fetchFolder(_ folder: String) async throws -> [PromptRecord] {
        let req = try await makeRequest(queryItems: [
            URLQueryItem(name: "folder", value: eq(folder)),
            URLQueryItem(name: "order", value: "created_at.desc"),
        ], method: "GET")
        let data = try await run(req, "Load folder")
        do { return try JSONDecoder().decode([PromptRecord].self, from: data) }
        catch { throw ServiceError.decodingError(error) }
    }

    func fetchFolderNames() async throws -> [(name: String, count: Int)] {
        let req = try await makeRequest(queryItems: [
            URLQueryItem(name: "folder", value: "not.is.null"),
            URLQueryItem(name: "select", value: "folder"),
        ], method: "GET")
        let data = try await run(req, "Load folders")
        struct Row: Codable { let folder: String? }
        let rows = try JSONDecoder().decode([Row].self, from: data)
        var counts: [String: Int] = [:]
        for row in rows { if let f = row.folder { counts[f, default: 0] += 1 } }
        return counts.map { (name: $0.key, count: $0.value) }.sorted { $0.name < $1.name }
    }

    func savePrompt(goal: String, role: String, tone: String, style: String,
                    prompt: String, folder: String?) async throws {
        struct Body: Codable {
            let goal, generated_prompt: String
            let role, tone, style, folder: String?
            let used: Bool
        }
        let data = try JSONEncoder().encode(Body(
            goal: goal, generated_prompt: prompt,
            role: role.isEmpty ? nil : role,
            tone: tone.isEmpty ? nil : tone,
            style: style.isEmpty ? nil : style,
            folder: folder, used: false))
        let req = try await makeRequest(queryItems: [], method: "POST",
                                        body: data, prefer: "return=minimal")
        _ = try await run(req, "Save")
    }

    func updateFolder(id: String, folder: String?) async throws {
        struct Body: Codable { let folder: String? }
        let data = try JSONEncoder().encode(Body(folder: folder))
        let req = try await makeRequest(queryItems: [
            URLQueryItem(name: "id", value: eq(id)),
        ], method: "PATCH", body: data)
        _ = try await run(req, "Update")
    }

    func delete(id: String) async throws {
        let req = try await makeRequest(queryItems: [
            URLQueryItem(name: "id", value: eq(id)),
        ], method: "DELETE")
        _ = try await run(req, "Delete")
    }

    /// One-time: pushes records saved locally (pre-sync builds) to the cloud,
    /// then renames the local file so it never runs twice.
    func migrateLocalIfNeeded() async {
        let locals = HistoryStore.shared.migrateOut()
        for r in locals {
            try? await savePrompt(goal: r.goal, role: r.role ?? "", tone: r.tone ?? "",
                                  style: r.style ?? "", prompt: r.generated_prompt,
                                  folder: r.folder)
        }
    }
}

// MARK: - HistoryStore (local, on-device)

/// Prompt history lives in a JSON file in the app's sandboxed Application
/// Support directory — no cloud, no shared keys, nothing leaves the device.
class HistoryStore {
    static let shared = HistoryStore()

    private let fileURL: URL = {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PG-13", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("prompt_history.json")
    }()

    /// Serializes all reads/writes so concurrent view-model calls can't interleave.
    private let queue = DispatchQueue(label: "com.pg13.historystore")

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private func loadAll() -> [PromptRecord] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([PromptRecord].self, from: data)) ?? []
    }

    private func writeAll(_ records: [PromptRecord]) throws {
        let data = try JSONEncoder().encode(records)
        try data.write(to: fileURL, options: .atomic)
    }

    private func onQueue<T>(_ work: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { cont in
            queue.async { cont.resume(with: Result { try work() }) }
        }
    }

    func fetchHistory() async throws -> [PromptRecord] {
        try await onQueue {
            Array(self.loadAll().sorted { $0.created_at > $1.created_at }.prefix(50))
        }
    }

    func fetchFolder(_ folder: String) async throws -> [PromptRecord] {
        try await onQueue {
            self.loadAll()
                .filter { $0.folder == folder }
                .sorted { $0.created_at > $1.created_at }
        }
    }

    func fetchFolderNames() async throws -> [(name: String, count: Int)] {
        try await onQueue {
            var counts: [String: Int] = [:]
            for r in self.loadAll() { if let f = r.folder { counts[f, default: 0] += 1 } }
            return counts.map { (name: $0.key, count: $0.value) }.sorted { $0.name < $1.name }
        }
    }

    func savePrompt(goal: String, role: String, tone: String, style: String,
                    prompt: String, folder: String?) async throws {
        try await onQueue {
            var records = self.loadAll()
            records.append(PromptRecord(
                id: UUID().uuidString,
                goal: goal,
                role: role.isEmpty ? nil : role,
                tone: tone.isEmpty ? nil : tone,
                style: style.isEmpty ? nil : style,
                generated_prompt: prompt,
                folder: folder,
                created_at: Self.iso.string(from: Date()),
                used: false))
            try self.writeAll(records)
        }
    }

    func updateFolder(id: String, folder: String?) async throws {
        try await onQueue {
            var records = self.loadAll()
            guard let idx = records.firstIndex(where: { $0.id == id }) else { return }
            let r = records[idx]
            records[idx] = PromptRecord(
                id: r.id, goal: r.goal, role: r.role, tone: r.tone, style: r.style,
                generated_prompt: r.generated_prompt, folder: folder,
                created_at: r.created_at, used: r.used)
            try self.writeAll(records)
        }
    }

    func delete(id: String) async throws {
        try await onQueue {
            var records = self.loadAll()
            records.removeAll { $0.id == id }
            try self.writeAll(records)
        }
    }

    /// Returns all local records and retires the file (kept as .migrated backup).
    func migrateOut() -> [PromptRecord] {
        queue.sync {
            let records = loadAll()
            if !records.isEmpty {
                let backup = fileURL.appendingPathExtension("migrated")
                try? FileManager.default.removeItem(at: backup)
                try? FileManager.default.moveItem(at: fileURL, to: backup)
            }
            return records
        }
    }
}
