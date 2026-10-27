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
    let skillVM = SkillViewModel()

    private init() {
        KeychainHelper.migrateFromUserDefaults(
            udKey: "anthropic_api_key",
            keychainKey: "anthropic_api_key"
        )
    }

    /// Opens a saved record in the tab that made it, ready to refine.
    func open(_ record: PromptRecord) {
        if record.recordKind == .skill {
            skillVM.populate(from: record)
            activeTab = AppTab.skill.rawValue
        } else {
            generateVM.populate(from: record)
            activeTab = AppTab.prompt.rawValue
        }
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
    @Published var isSaving: Bool = false
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
            errorMessage = "Enter your Anthropic API key above, then tap SAVE."
            return
        }
        errorMessage = ""; isGenerating = true
        // Built here, on the main thread, so the Task never reads the
        // @Published fields while the UI may be writing them.
        let (system, message, maxTokens) = (buildSystemPrompt(), buildUserMessage(), maxTokensForRequest)
        Task {
            do {
                let result = try await ClaudeService.shared.generate(
                    systemPrompt: system, userMessage: message, maxTokens: maxTokens)
                await MainActor.run { self.generatedPrompt = result; self.version += 1; self.isGenerating = false }
            } catch {
                await MainActor.run { self.handle(error); self.isGenerating = false }
            }
        }
    }

    func refine() {
        guard !refineInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        guard hasResult else {
            errorMessage = "Generate a prompt before refining it."; return
        }
        guard !isRefining else { return }
        isRefining = true; errorMessage = ""
        let request = refineInput
        let (system, maxTokens) = (buildRefineSystemPrompt(), maxTokensForRequest)
        let message = "Prompt to revise:\n\(generatedPrompt)\n\nRequested change:\n\(request.capped(1000))"
        Task {
            do {
                let result = try await ClaudeService.shared.generate(
                    systemPrompt: system, userMessage: message, maxTokens: maxTokens)
                await MainActor.run {
                    self.generatedPrompt = result; self.version += 1
                    // Keep anything typed while the request was running.
                    if self.refineInput == request { self.refineInput = "" }
                    self.isRefining = false
                }
            } catch {
                await MainActor.run { self.handle(error); self.isRefining = false }
            }
        }
    }

    func save(folder: String?) {
        guard hasResult else { errorMessage = "Nothing to save yet."; return }
        // The title call makes a save take a second or two; without this a
        // second tap in that gap saved the prompt twice.
        guard !isSaving else { return }
        isSaving = true; errorMessage = ""
        savedMessageClear?.cancel(); savedMessage = "Saving..."
        let (goal, role, tone) = (self.goal, self.role, selectedTone)
        let (style, prompt) = (selectedOutputType, generatedPrompt)
        Task {
            do {
                // Check first, so a signed-out save does not pay for a title call.
                guard AuthService.shared.isSignedIn else { throw ServiceError.notSignedIn }
                let title = await ClaudeService.shared.suggestTitle(goal: goal, prompt: prompt)
                let stored = try await CloudHistoryStore.shared.savePrompt(
                    goal: goal, role: role, tone: tone,
                    style: style, prompt: prompt, folder: folder,
                    title: title)
                await MainActor.run {
                    self.isSaving = false
                    self.showSaved(stored.map { "Saved to \"\($0)\"" } ?? "Saved")
                }
            } catch {
                await MainActor.run {
                    self.isSaving = false; self.savedMessage = ""
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Clears the saved notice after 2 seconds. Each save cancels the last
    /// timer, so an earlier save's timer cannot wipe a later "Saving...".
    private var savedMessageClear: DispatchWorkItem?

    private func showSaved(_ text: String) {
        savedMessage = text
        let clear = DispatchWorkItem { [weak self] in self?.savedMessage = "" }
        savedMessageClear = clear
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: clear)
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
        // Pasted keys often carry a trailing space or newline, which the API rejects with a 401.
        let key = inlineAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { errorMessage = "Paste a key first, then tap SAVE."; return }
        KeychainHelper.save(key, key: "anthropic_api_key")
        showAPIKeyField = false; inlineAPIKey = ""; errorMessage = ""
    }

    /// A rejected key (401) reopens the key field so it can be replaced.
    /// Without this, a bad saved key left no way to enter a new one.
    private func handle(_ error: Error) {
        if case ServiceError.httpError(401, _) = error {
            showAPIKeyField = true
            errorMessage = "That API key was rejected. Paste a new key above, then tap SAVE."
        } else {
            errorMessage = error.localizedDescription
        }
    }

    /// Replaces the whole form, so nothing from the previous session (extras,
    /// a half-typed refinement, an old error) rides along on the next generate.
    func populate(from record: PromptRecord) {
        role = record.role ?? ""; goal = record.goal; extraInfo = ""
        generatedPrompt = record.generated_prompt; version = 1
        isEditing = false; refineInput = ""
        errorMessage = ""; savedMessage = ""; copyFlash = false; shareFlash = false
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

// MARK: - SkillViewModel

/// The SKILL tab: turns a name, a purpose and some rules into a SKILL.md file.
class SkillViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var purpose: String = ""
    @Published var steps: String = ""
    @Published var isGenerating = false
    @Published var generated: String = ""
    @Published var errorMessage: String = ""
    @Published var version: Int = 0
    @Published var isEditing = false
    @Published var refineInput: String = ""
    @Published var isRefining = false
    @Published var savedMessage: String = ""
    @Published var isSaving = false
    @Published var copyFlash = false
    @Published var shareFlash = false
    @Published var inlineAPIKey = ""
    @Published var showAPIKeyField = false

    var hasResult: Bool { !generated.isEmpty }

    func clear() {
        name = ""; purpose = ""; steps = ""
        generated = ""; errorMessage = ""; version = 0
        isEditing = false; refineInput = ""; savedMessage = ""
        copyFlash = false; shareFlash = false
    }

    func generate() {
        guard !purpose.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Say what the skill does and when to use it."; return
        }
        guard ClaudeService.shared.getAPIKey() != nil else {
            showAPIKeyField = true
            errorMessage = "Enter your Anthropic API key above, then tap SAVE."; return
        }
        errorMessage = ""; isGenerating = true
        let message = userMessage
        Task {
            do {
                let result = try await ClaudeService.shared.generate(
                    systemPrompt: Self.systemPrompt, userMessage: message, maxTokens: 1500)
                await MainActor.run { self.generated = result; self.version += 1; self.isGenerating = false }
            } catch {
                await MainActor.run { self.handle(error); self.isGenerating = false }
            }
        }
    }

    func saveAPIKey() {
        let key = inlineAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { errorMessage = "Paste a key first, then tap SAVE."; return }
        KeychainHelper.save(key, key: "anthropic_api_key")
        showAPIKeyField = false; inlineAPIKey = ""; errorMessage = ""
    }

    /// Same as the Prompt tab: a rejected key reopens the key field here,
    /// instead of sending the person to another tab that may not show it.
    private func handle(_ error: Error) {
        if case ServiceError.httpError(401, _) = error {
            showAPIKeyField = true
            errorMessage = "That API key was rejected. Paste a new key above, then tap SAVE."
        } else {
            errorMessage = error.localizedDescription
        }
    }

    func refine() {
        guard !refineInput.trimmingCharacters(in: .whitespaces).isEmpty, hasResult, !isRefining else { return }
        isRefining = true; errorMessage = ""
        let request = refineInput
        let message = "SKILL.md to revise:\n\(generated)\n\nRequested change:\n\(request.capped(1000))"
        Task {
            do {
                let result = try await ClaudeService.shared.generate(
                    systemPrompt: Self.refinePrompt, userMessage: message, maxTokens: 1500)
                await MainActor.run {
                    self.generated = result; self.version += 1
                    if self.refineInput == request { self.refineInput = "" }
                    self.isRefining = false
                }
            } catch {
                await MainActor.run { self.handle(error); self.isRefining = false }
            }
        }
    }

    func save(folder: String?) {
        guard hasResult else { errorMessage = "Nothing to save yet."; return }
        guard !isSaving else { return }
        isSaving = true; errorMessage = ""
        savedMessageClear?.cancel(); savedMessage = "Saving..."
        let (name, purpose, file) = (displayName, self.purpose, generated)
        Task {
            do {
                let stored = try await CloudHistoryStore.shared.savePrompt(
                    goal: name, role: purpose, tone: "", style: "",
                    prompt: file, folder: folder, kind: .skill)
                await MainActor.run {
                    self.isSaving = false
                    self.showSaved(stored.map { "Saved to \"\($0)\"" } ?? "Saved")
                }
            } catch {
                await MainActor.run {
                    self.isSaving = false; self.savedMessage = ""
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Clears the saved notice after 2 seconds. Each save cancels the last
    /// timer, so an earlier save's timer cannot wipe a later "Saving...".
    private var savedMessageClear: DispatchWorkItem?

    private func showSaved(_ text: String) {
        savedMessage = text
        let clear = DispatchWorkItem { [weak self] in self?.savedMessage = "" }
        savedMessageClear = clear
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: clear)
    }

    func copy() {
        copyToPasteboard(generated)
        copyFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { self.copyFlash = false }
    }

    func share() {
#if os(macOS)
        copyToPasteboard(generated)
#endif
        shareFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { self.shareFlash = false }
    }

    func populate(from record: PromptRecord) {
        name = record.goal; purpose = record.role ?? ""; steps = ""
        generated = record.generated_prompt; version = 1; isEditing = false
        refineInput = ""; errorMessage = ""; savedMessage = ""
        copyFlash = false; shareFlash = false
    }

    /// The saved name: what was typed, or the `name:` line Claude wrote.
    var displayName: String {
        let typed = name.trimmingCharacters(in: .whitespaces)
        if !typed.isEmpty { return typed }
        for line in generated.split(separator: "\n") where line.hasPrefix("name:") {
            return line.dropFirst(5).trimmingCharacters(in: .whitespaces)
        }
        return "untitled-skill"
    }

    var fileName: String { Markdown.fileName(for: displayName, prefix: "skill") }

    private var userMessage: String {
        var msg = "What it does and when to use it: \(purpose.capped(2000))"
        if !name.isEmpty  { msg = "Skill name: \(name.capped(80))\n" + msg }
        if !steps.isEmpty { msg += "\nSteps and rules: \(steps.capped(2000))" }
        return msg
    }

    private static let systemPrompt = [
        "Write a SKILL.md file for an AI agent. Return only the file, with no commentary before or after it.",
        "Start with YAML frontmatter between two lines of three hyphens. It has exactly two keys: name, in lowercase kebab-case (use the given name if there is one, otherwise make a short one), and description, one or two sentences saying what the skill does and the requests that should trigger it.",
        "After the frontmatter, write the instructions the agent follows: a numbered list of steps, then any rules or things to never do. Second-person imperative voice. No preamble, no hedge words.",
        "Never use em dashes in the output. Use periods, commas, colons, or parentheses instead."
    ].joined(separator: " ")

    private static let refinePrompt = [
        "Revise the SKILL.md below according to the requested change. Return only the revised file, with no commentary.",
        "Keep the frontmatter format and everything the request did not ask you to change.",
        "Never use em dashes in the output. Use periods, commas, colons, or parentheses instead."
    ].joined(separator: " ")
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
                let stored = try await CloudHistoryStore.shared.updateFolder(id: record.id, folder: folder)
                await MainActor.run {
                    if let idx = self.records.firstIndex(where: { $0.id == record.id }) {
                        self.records[idx] = self.records[idx].withFolder(stored)
                    }
                    self.folderInputID = nil; self.folderInputText = ""
                    if let f = stored, !self.folderNames.contains(f) {
                        self.folderNames.append(f)
                        self.folderNames.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                    }
                }
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }

    func rename(_ record: PromptRecord, to title: String) {
        Task {
            do {
                let stored = try await CloudHistoryStore.shared.updateTitle(id: record.id, title: title)
                await MainActor.run {
                    if let idx = self.records.firstIndex(where: { $0.id == record.id }) {
                        self.records[idx].title = stored
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
    @Published var folderInputID: String? = nil
    @Published var folderInputText = ""

    var folderNames: [String] { folders.map { $0.name } }

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

    /// Files the record elsewhere, or out of every folder with nil. Either way
    /// it leaves the folder that is open.
    func setFolder(_ record: PromptRecord, folder: String?) {
        Task {
            do {
                let stored = try await CloudHistoryStore.shared.updateFolder(id: record.id, folder: folder)
                await MainActor.run {
                    if stored != self.selectedFolder {
                        self.folderRecords.removeAll { $0.id == record.id }
                    }
                    self.folderInputID = nil; self.folderInputText = ""
                }
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }

    func delete(_ record: PromptRecord) {
        Task {
            do {
                try await CloudHistoryStore.shared.delete(id: record.id)
                await MainActor.run { self.folderRecords.removeAll { $0.id == record.id } }
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }

    func toggleFolderInput(_ id: String) {
        folderInputID = folderInputID == id ? nil : id
    }

    func rename(_ record: PromptRecord, to title: String) {
        Task {
            do {
                let stored = try await CloudHistoryStore.shared.updateTitle(id: record.id, title: title)
                await MainActor.run {
                    if let idx = self.folderRecords.firstIndex(where: { $0.id == record.id }) {
                        self.folderRecords[idx].title = stored
                    }
                }
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }

    /// Renames the open folder. The drill-in follows the new name, which may be
    /// an existing folder this one merged into.
    func renameFolder(to typed: String) {
        guard let old = selectedFolder else { return }
        Task {
            do {
                let stored = try await CloudHistoryStore.shared.renameFolder(from: old, to: typed)
                await MainActor.run { self.openFolder(stored) }
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }

    func toggleExpand(_ id: String) { expandedIDs.toggle(id) }
}
