// AppState.swift — Shared (macOS + iOS)

import SwiftUI
import Combine

// MARK: - Cross-platform pasteboard

func copyToPasteboard(_ text: String) {
#if os(iOS)
    UIPasteboard.general.string = text
#else
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
#endif
}

// MARK: - Theme notification

extension Notification.Name {
    static let pg13ThemeChanged = Notification.Name("pg13ThemeChanged")
}

// MARK: - AppState

class AppState: ObservableObject {
    static let shared = AppState()
    @Published var activeTab: Int = 0
    let generateVM = GenerateViewModel()
    /// Docs owns a persisted draft, so it lives as long as the app rather than
    /// being rebuilt each time the tab is shown.
    let docVM = MarkdownDocViewModel()

    private init() {
        KeychainHelper.migrateFromUserDefaults(
            udKey: "anthropic_api_key",
            keychainKey: "anthropic_api_key"
        )
    }

    @Published var lightMode: Bool = UserDefaults.standard.bool(forKey: "pg13Light") {
        didSet {
            UserDefaults.standard.set(lightMode, forKey: "pg13Light")
            NotificationCenter.default.post(name: .pg13ThemeChanged, object: lightMode)
        }
    }
}

// MARK: - GenerateViewModel

class GenerateViewModel: ObservableObject {
    @Published var role: String = ""
    @Published var goal: String = ""
    @Published var extraInfo: String = ""
    @Published var selectedTone: String = ""
    @Published var selectedOutputType: String = ""
    @Published var isGenerating: Bool = false
    @Published var generatedPrompt: String = ""
    @Published var errorMessage: String = ""
    @Published var version: Int = 0
    @Published var isEditing: Bool = false
    @Published var refineInput: String = ""
    @Published var isRefining: Bool = false
    @Published var savedMessage: String = ""
    @Published var shareFlash: Bool = false
    @Published var copyFlash: Bool = false
    @Published var inlineAPIKey: String = ""
    @Published var showAPIKeyField: Bool = false

    let tones = ["Professional","Casual","Concise","Detailed","Creative",
                 "Persuasive","Technical","Empathetic","Formal","Playful"]
    let outputTypes = ["Bullets","Steps","Prose","Table","Template",
                       "Q&A","Checklist","Summary","Email","Script"]

    var hasResult: Bool { !generatedPrompt.isEmpty }

    func clear() {
        role = ""; goal = ""; extraInfo = ""
        selectedTone = ""; selectedOutputType = ""
        generatedPrompt = ""; errorMessage = ""; version = 0
        isEditing = false; refineInput = ""; savedMessage = ""
        copyFlash = false; shareFlash = false
    }

    func generate() {
        guard !goal.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Goal is required."; return
        }
        guard ClaudeService.shared.getAPIKey() != nil else {
            showAPIKeyField = true
            errorMessage = "Enter your Anthropic API key below."
            return
        }
        errorMessage = ""; isGenerating = true
        Task {
            do {
                let result = try await ClaudeService.shared.generate(
                    systemPrompt: buildSystemPrompt(),
                    userMessage: buildUserMessage(),
                    maxTokens: maxTokensForRequest)
                await MainActor.run { self.generatedPrompt = result; self.version += 1; self.isGenerating = false }
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription; self.isGenerating = false }
            }
        }
    }

    func refine() {
        guard !refineInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        guard hasResult else {
            errorMessage = "Generate a prompt before refining it."; return
        }
        isRefining = true; errorMessage = ""
        Task {
            do {
                let result = try await ClaudeService.shared.generate(
                    systemPrompt: buildRefineSystemPrompt(),
                    userMessage: "Prompt to revise:\n\(generatedPrompt)\n\nRequested change:\n\(refineInput.capped(1000))",
                    maxTokens: maxTokensForRequest)
                await MainActor.run {
                    self.generatedPrompt = result; self.version += 1
                    self.refineInput = ""; self.isRefining = false
                }
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription; self.isRefining = false }
            }
        }
    }

    func save(folder: String?) {
        guard hasResult else { errorMessage = "Nothing to save yet."; return }
        Task {
            do {
                try await CloudHistoryStore.shared.savePrompt(
                    goal: goal, role: role, tone: selectedTone,
                    style: selectedOutputType, prompt: generatedPrompt, folder: folder)
                await MainActor.run {
                    self.savedMessage = folder != nil ? "Saved to \"\(folder!)\"" : "Saved"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.savedMessage = "" }
                }
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }

    func copy() {
        copyToPasteboard(generatedPrompt)
        copyFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { self.copyFlash = false }
    }

    func makeShareText() -> String {
        shareText(goal: goal, role: role, tone: selectedTone,
                  style: selectedOutputType, prompt: generatedPrompt)
    }

    func makeMarkdown() -> String {
        Markdown.document(goal: goal, role: role, tone: selectedTone,
                          style: selectedOutputType, prompt: generatedPrompt)
    }

    /// macOS copies the text; iOS presents a share sheet and only needs the flash.
    func share() {
#if os(macOS)
        copyToPasteboard(makeShareText())
#endif
        shareFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { self.shareFlash = false }
    }

    func saveAPIKey() {
        KeychainHelper.save(inlineAPIKey, key: "anthropic_api_key")
        showAPIKeyField = false; inlineAPIKey = ""; errorMessage = ""
    }

    func populate(from record: PromptRecord) {
        role = record.role ?? ""; goal = record.goal
        generatedPrompt = record.generated_prompt; version = 1
        isEditing = false
        selectedTone = record.tone ?? ""; selectedOutputType = record.style ?? ""
    }

    // MARK: Prompt construction

    /// Output types whose shape needs more than a few sentences and needs light
    /// markdown to express. The length and "no markdown" rules are relaxed for
    /// these, otherwise the system prompt contradicts the format the user picked.
    private static let structuredOutputTypes: Set<String> =
        ["Bullets", "Steps", "Table", "Template", "Q&A", "Checklist"]

    private var wantsStructuredOutput: Bool {
        Self.structuredOutputTypes.contains(selectedOutputType)
    }

    /// Headroom for the response. Structured formats legitimately run longer.
    private var maxTokensForRequest: Int { wantsStructuredOutput ? 1024 : 512 }

    private func buildSystemPrompt() -> String {
        var parts = [
            "Write a single, ready-to-use prompt: a direct instruction an AI can execute immediately.",
            "Rules: second-person imperative voice. No preamble, no self-explanation, no meta-commentary ('This prompt is designed to...', 'Use the following...'). No hedge words ('feel free to', 'consider', 'you may want to', 'if applicable').",
            "Never use em dashes in the output. Use periods, commas, colons, or parentheses instead. Only use an em dash if it is truly unavoidable, which is almost never."
        ]
        if !selectedTone.isEmpty { parts.append("Tone: \(selectedTone).") }

        if wantsStructuredOutput {
            parts.append("Shape the prompt as \(selectedOutputType.lowercased()). Use only the markdown that structure needs and nothing decorative. 12 lines maximum.")
        } else if !selectedOutputType.isEmpty {
            parts.append("Output format: \(selectedOutputType). No markdown. 4 sentences, hard cap.")
        } else {
            parts.append("No markdown. 2 to 3 sentences, hard cap.")
        }
        return parts.joined(separator: " ")
    }

    /// Refinement keeps the original constraints but must not re-impose the
    /// length cap, or "make it longer" would be silently reverted every time.
    private func buildRefineSystemPrompt() -> String {
        var parts = [
            "Revise the prompt below according to the requested change. Return only the revised prompt, with no commentary about what you changed.",
            "Keep everything the request did not ask you to change. Stay in second-person imperative voice. No preamble, no hedge words.",
            "Never use em dashes in the output. Use periods, commas, colons, or parentheses instead."
        ]
        if !selectedTone.isEmpty       { parts.append("Tone: \(selectedTone).") }
        if !selectedOutputType.isEmpty { parts.append("Output format: \(selectedOutputType).") }
        return parts.joined(separator: " ")
    }

    private func buildUserMessage() -> String {
        var msg = "Goal: \(goal.capped(2000))"
        if !role.isEmpty      { msg += "\nRole/Background: \(role.capped(500))" }
        if !extraInfo.isEmpty { msg += "\nAdditional context: \(extraInfo.capped(2000))" }
        return msg
    }
}

// MARK: - HistoryViewModel

class HistoryViewModel: ObservableObject {
    @Published var records: [PromptRecord] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var expandedIDs: Set<String> = []
    @Published var folderInputID: String? = nil
    @Published var folderInputText = ""
    @Published var folderNames: [String] = []

    func load() {
        isLoading = true; errorMessage = ""
        Task {
            async let r = CloudHistoryStore.shared.fetchHistory()
            async let f = CloudHistoryStore.shared.fetchFolderNames()
            do {
                let (records, folders) = try await (r, f)
                await MainActor.run {
                    self.records = records
                    self.folderNames = folders.map { $0.name }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription; self.isLoading = false }
            }
        }
    }

    func toggleExpand(_ id: String) { expandedIDs.toggle(id) }

    func delete(_ record: PromptRecord) {
        Task {
            do {
                try await CloudHistoryStore.shared.delete(id: record.id)
                await MainActor.run { self.records.removeAll { $0.id == record.id } }
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }

    func setFolder(_ record: PromptRecord, folder: String?) {
        Task {
            do {
                try await CloudHistoryStore.shared.updateFolder(id: record.id, folder: folder)
                await MainActor.run {
                    if let idx = self.records.firstIndex(where: { $0.id == record.id }) {
                        self.records[idx] = self.records[idx].withFolder(folder)
                    }
                    self.folderInputID = nil; self.folderInputText = ""
                    if let f = folder, !self.folderNames.contains(f) {
                        self.folderNames.append(f); self.folderNames.sort()
                    }
                }
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }
}

// MARK: - FoldersViewModel

class FoldersViewModel: ObservableObject {
    @Published var folders: [(name: String, count: Int)] = []
    @Published var selectedFolder: String? = nil
    @Published var folderRecords: [PromptRecord] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var expandedIDs: Set<String> = []

    func loadFolders() {
        isLoading = true; errorMessage = ""
        Task {
            do {
                let result = try await CloudHistoryStore.shared.fetchFolderNames()
                await MainActor.run { self.folders = result; self.isLoading = false }
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription; self.isLoading = false }
            }
        }
    }

    func openFolder(_ name: String) {
        selectedFolder = name; isLoading = true; errorMessage = ""
        Task {
            do {
                let result = try await CloudHistoryStore.shared.fetchFolder(name)
                await MainActor.run { self.folderRecords = result; self.isLoading = false }
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription; self.isLoading = false }
            }
        }
    }

    func back() {
        selectedFolder = nil; folderRecords = []; expandedIDs = []; errorMessage = ""
        loadFolders()
    }

    func removeFromFolder(_ record: PromptRecord) {
        Task {
            do {
                try await CloudHistoryStore.shared.updateFolder(id: record.id, folder: nil)
                await MainActor.run { self.folderRecords.removeAll { $0.id == record.id } }
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }

    func toggleExpand(_ id: String) { expandedIDs.toggle(id) }
}
