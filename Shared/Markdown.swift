// Markdown.swift — Shared (macOS + iOS)
//
// Everything markdown, in three layers:
//   1. Document building. Prompts to markdown: one prompt, or a whole
//      collection (a folder, or the full history) with a table of contents.
//   2. Analysis. Outline, stats, and a lint pass that catches the failures
//      worth catching before a document ships.
//   3. The Docs tab. Authoring full markdown documents from a brief, with a
//      preview, a linter, and an export.
//
// House rule, and the same rule the generator's own system prompt enforces:
// no em dashes anywhere in generated prose.

import Foundation
import SwiftUI
import Combine
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

// MARK: - Document building

enum Markdown {

    /// One prompt as a standalone document.
    static func document(goal: String, role: String?, tone: String?, style: String?,
                         prompt: String, date: String? = nil) -> String {
        var out = "# \(heading(from: goal))\n\n"
        out += byline(date: date) + "\n\n"
        if let meta = metadataList(role: role, tone: tone, style: style) {
            out += meta + "\n\n"
        }
        out += "## Prompt\n\n" + fenced(prompt) + "\n"
        return out
    }

    /// Many prompts as one document, with a table of contents.
    static func collection(title: String, records: [PromptRecord]) -> String {
        var out = "# \(title)\n\n"
        out += byline(date: nil)
        out += "\n\n\(records.count) prompt\(records.count == 1 ? "" : "s").\n\n"

        guard !records.isEmpty else {
            return out + "_No prompts in this collection yet._\n"
        }

        out += "## Contents\n\n"
        for (i, r) in records.enumerated() {
            out += "\(i + 1). [\(escapeInline(heading(from: r.goal)))](#\(anchor(for: r.goal, index: i)))\n"
        }
        out += "\n---\n\n"

        for (i, r) in records.enumerated() {
            out += "## \(i + 1). \(heading(from: r.goal))\n\n"
            if let meta = metadataList(role: r.role, tone: r.tone, style: r.style, date: r.displayDate) {
                out += meta + "\n\n"
            }
            out += fenced(r.generated_prompt) + "\n\n"
            if i < records.count - 1 { out += "---\n\n" }
        }
        return out
    }

    // MARK: - Pieces

    private static func byline(date: String?) -> String {
        var line = "> Generated with PG-13"
        if let d = date, !d.isEmpty { line += " (\(d))" }
        return line
    }

    private static func metadataList(role: String?, tone: String?, style: String?,
                                     date: String? = nil) -> String? {
        var rows: [String] = []
        if let r = role,  !r.isEmpty { rows.append("- **Role:** \(escapeInline(r))") }
        if let t = tone,  !t.isEmpty { rows.append("- **Tone:** \(escapeInline(t))") }
        if let s = style, !s.isEmpty { rows.append("- **Output type:** \(escapeInline(s))") }
        if let d = date,  !d.isEmpty { rows.append("- **Saved:** \(escapeInline(d))") }
        return rows.isEmpty ? nil : rows.joined(separator: "\n")
    }

    /// First line of the goal, collapsed to one line so it cannot break a heading.
    private static func heading(from goal: String) -> String {
        let trimmed = goal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Generated Prompt" }
        let firstLine = trimmed.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? trimmed
        return firstLine.count > 90 ? String(firstLine.prefix(87)) + "..." : firstLine
    }

    /// Neutralises characters that would otherwise start markdown syntax inline.
    private static func escapeInline(_ s: String) -> String {
        s.replacingOccurrences(of: "\n", with: " ")
         .replacingOccurrences(of: "|", with: "\\|")
         .replacingOccurrences(of: "*", with: "\\*")
         .replacingOccurrences(of: "_", with: "\\_")
    }

    /// Wraps prompt text in a fence long enough to survive backticks inside it,
    /// so a generated prompt containing code cannot break out of its block.
    private static func fenced(_ body: String) -> String {
        let text = body.trimmingCharacters(in: .whitespacesAndNewlines)
        var longest = 0, current = 0
        for ch in text {
            if ch == "`" { current += 1; longest = max(longest, current) } else { current = 0 }
        }
        let fence = String(repeating: "`", count: max(3, longest + 1))
        return "\(fence)text\n\(text)\n\(fence)"
    }

    /// GitHub-style anchor for the "N. Goal" heading this document emits.
    private static func anchor(for goal: String, index: Int) -> String {
        let slug = heading(from: goal).lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -")).inverted)
            .joined()
            .replacingOccurrences(of: " ", with: "-")
        return "\(index + 1)-\(slug)"
    }

    // MARK: - File names

    /// `prompt-first-few-words.md`, safe on every filesystem the app targets.
    static func fileName(for goal: String, prefix: String = "prompt") -> String {
        let slug = goal.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .prefix(5)
            .joined(separator: "-")
        return slug.isEmpty ? "\(prefix).md" : "\(prefix)-\(slug).md"
    }

    /// Writes markdown to a private temp folder for sharing and returns the URL.
    /// Each export gets its own directory, so two prompts that slug to the same
    /// name cannot overwrite each other mid-share.
    static func writeTempFile(_ content: String, fileName: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pg13-export/\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(fileName)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

// MARK: - Analysis

extension Markdown {

    struct Stats {
        let words: Int
        let lines: Int
        let headings: Int
        /// 225 words per minute, the usual figure for skim-reading documentation.
        var readingMinutes: Int { max(1, Int((Double(words) / 225.0).rounded(.up))) }
    }

    struct Heading: Identifiable, Hashable {
        let id = UUID()
        let level: Int
        let text: String
    }

    /// Every line, flagged with whether it sits inside a fenced code block, so
    /// a `#` comment in a shell snippet is never mistaken for a heading.
    static func taggedLines(_ md: String) -> [(line: String, inFence: Bool)] {
        var out: [(String, Bool)] = []
        var fence: String? = nil
        for raw in md.components(separatedBy: .newlines) {
            let t = raw.trimmingCharacters(in: .whitespaces)
            if let open = fence {
                out.append((raw, true))
                if t.hasPrefix(open) { fence = nil }
            } else if t.hasPrefix("```") || t.hasPrefix("~~~") {
                fence = String(t.prefix(while: { $0 == "`" || $0 == "~" }))
                out.append((raw, true))
            } else {
                out.append((raw, false))
            }
        }
        return out
    }

    static func outline(_ md: String) -> [Heading] {
        taggedLines(md).compactMap { entry in
            guard !entry.inFence else { return nil }
            let t = entry.line.trimmingCharacters(in: .whitespaces)
            guard t.hasPrefix("#") else { return nil }
            let level = t.prefix(while: { $0 == "#" }).count
            guard level <= 6 else { return nil }
            let text = t.dropFirst(level).trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { return nil }
            return Heading(level: level, text: text)
        }
    }

    static func stats(_ md: String) -> Stats {
        Stats(words: md.split(whereSeparator: { $0.isWhitespace }).count,
              lines: md.isEmpty ? 0 : md.components(separatedBy: .newlines).count,
              headings: outline(md).count)
    }

    /// Structural and house-style problems, in the order a reader hits them.
    /// Every item is something that changes the rendered document or breaks a
    /// stated rule. Nothing here is a matter of taste.
    static func lint(_ md: String) -> [String] {
        guard !md.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        var problems: [String] = []

        if md.contains("\u{2014}") {
            problems.append("Em dash found. House style uses periods, commas, colons, or parentheses.")
        }
        if md.contains("\u{2013}") {
            problems.append("En dash found. Use a plain hyphen.")
        }

        // An unclosed fence renders everything after it as code.
        let fenceCount = md.components(separatedBy: .newlines)
            .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("```") }.count
        if fenceCount % 2 != 0 {
            problems.append("Unclosed code fence. Every opening ``` needs a closing ```.")
        }

        let heads = outline(md)
        let h1s = heads.filter { $0.level == 1 }.count
        if h1s == 0 { problems.append("No H1. Open the document with a single '# Title'.") }
        if h1s > 1  { problems.append("\(h1s) H1 headings. Keep one, demote the rest to '##'.") }

        // A jump from H1 straight to H3 breaks outlines and anchor navigation.
        var previous = 0
        for h in heads {
            if previous != 0 && h.level > previous + 1 {
                problems.append("Heading jumps from H\(previous) to H\(h.level) at \"\(h.text)\".")
                break
            }
            previous = h.level
        }

        for token in ["TODO", "TBD", "[insert", "lorem ipsum", "XXX"] {
            if md.localizedCaseInsensitiveContains(token) {
                problems.append("Placeholder left in the text: \"\(token)\".")
            }
        }
        return problems
    }

    /// The one lint rule with an unambiguous mechanical fix. The rest are
    /// judgement calls and stay the author's problem on purpose.
    static func normalizeDashes(_ md: String) -> String {
        md.replacingOccurrences(of: " \u{2014} ", with: ", ")
          .replacingOccurrences(of: "\u{2014}", with: ", ")
          .replacingOccurrences(of: "\u{2013}", with: "-")
    }

    /// Strips a fence the model sometimes wraps the whole document in, which
    /// would otherwise render the entire document as a code block.
    static func unwrapOuterFence(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```") else { return trimmed }
        var lines = trimmed.components(separatedBy: .newlines)
        guard lines.count > 2,
              lines.last?.trimmingCharacters(in: .whitespaces).hasPrefix("```") == true
        else { return trimmed }
        lines.removeFirst()
        lines.removeLast()
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Export controller

/// Drives a markdown export from any view: a save panel on macOS, a share sheet
/// on iOS. Failures surface in `errorMessage` instead of being swallowed, which
/// is what previously made a blocked sandbox write look like a no-op.
@MainActor
final class MarkdownExporter: ObservableObject {
    @Published var shareURL: URL? = nil
    @Published var isPresentingShare = false
    @Published var errorMessage = ""

    func export(_ content: String, fileName: String) {
        errorMessage = ""
#if os(macOS)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.nameFieldStringValue = fileName
        panel.isExtensionHidden = false
        panel.canCreateDirectories = true
        NSApp.activate(ignoringOtherApps: true)
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            var failure: String? = nil
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                failure = ServiceError
                    .exportFailed(error.localizedDescription).localizedDescription
            }
            if let failure {
                Task { @MainActor [weak self] in self?.errorMessage = failure }
            }
        }
#else
        do {
            shareURL = try Markdown.writeTempFile(content, fileName: fileName)
            isPresentingShare = true
        } catch {
            errorMessage = ServiceError
                .exportFailed(error.localizedDescription).localizedDescription
        }
#endif
    }
}

// MARK: - Docs view model

/// Authoring a document is a different job from generating a prompt: longer
/// output, real markdown, and a draft that has to survive the panel closing.
/// That earns its own model rather than more flags on GenerateViewModel.
final class MarkdownDocViewModel: ObservableObject {

    // Brief
    @Published var docType = "README"
    @Published var title = ""
    @Published var subject = ""
    @Published var audience = ""
    @Published var mustCover = ""
    @Published var depth = "Standard"

    // Result
    @Published var content = "" { didSet { scheduleDraftSave() } }
    @Published var version = 0
    @Published var showSource = true
    @Published var showOutline = false

    // Transient
    @Published var isGenerating = false
    @Published var isRefining = false
    @Published var refineInput = ""
    @Published var errorMessage = ""
    @Published var copyFlash = false

    let docTypes = ["README", "Spec", "Runbook", "How-to", "Brief",
                    "Meeting Notes", "Case Study", "Changelog"]
    let depths = ["Brief", "Standard", "Deep"]

    var hasContent: Bool { !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var problems: [String] { Markdown.lint(content) }
    var stats: Markdown.Stats { Markdown.stats(content) }
    var outline: [Markdown.Heading] { Markdown.outline(content) }

    /// TagToggle lets a selected tag be tapped off, so neither of these is
    /// guaranteed non-empty at request time.
    private var effectiveDocType: String { docType.isEmpty ? "document" : docType }
    private var effectiveDepth: String { depth.isEmpty ? "Standard" : depth }

    // MARK: Draft persistence

    private static let draftKey = "pg13DocDraft"
    private static let draftTitleKey = "pg13DocDraftTitle"
    private var draftTask: Task<Void, Never>?

    init() {
        // Property observers do not fire for assignments made in init, so this
        // restores the draft without immediately rewriting it.
        content = UserDefaults.standard.string(forKey: Self.draftKey) ?? ""
        title = UserDefaults.standard.string(forKey: Self.draftTitleKey) ?? ""
        if !content.isEmpty { version = 1 }
    }

    /// The macOS panel dismisses whenever focus moves, so an unsaved draft is
    /// easy to lose. Debounced rather than written on every keystroke.
    private func scheduleDraftSave() {
        let snapshot = content
        let snapshotTitle = title
        draftTask?.cancel()
        draftTask = Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            UserDefaults.standard.set(snapshot, forKey: Self.draftKey)
            UserDefaults.standard.set(snapshotTitle, forKey: Self.draftTitleKey)
        }
    }

    // MARK: Actions

    func generate() {
        guard !subject.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Describe what the document should cover."; return
        }
        guard ClaudeService.shared.getAPIKey() != nil else {
            errorMessage = "Add your Anthropic API key on the Generate tab first."; return
        }
        errorMessage = ""; isGenerating = true
        Task {
            do {
                let result = try await ClaudeService.shared.generate(
                    systemPrompt: buildSystemPrompt(),
                    userMessage: buildUserMessage(),
                    maxTokens: maxTokens)
                await MainActor.run {
                    self.content = Markdown.unwrapOuterFence(result)
                    self.version += 1
                    self.isGenerating = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isGenerating = false
                }
            }
        }
    }

    func refine() {
        let ask = refineInput.trimmingCharacters(in: .whitespaces)
        guard !ask.isEmpty else { return }
        guard hasContent else {
            errorMessage = "Generate a document before revising it."; return
        }
        isRefining = true; errorMessage = ""
        Task {
            do {
                let result = try await ClaudeService.shared.generate(
                    systemPrompt: refineSystemPrompt,
                    userMessage: "Document:\n\(capped(content, 12000))\n\nRequested change:\n\(capped(ask, 1000))",
                    // Revision returns the whole document, so it needs at least
                    // as much headroom as the original generation did.
                    maxTokens: max(maxTokens, 2500))
                await MainActor.run {
                    self.content = Markdown.unwrapOuterFence(result)
                    self.version += 1
                    self.refineInput = ""
                    self.isRefining = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isRefining = false
                }
            }
        }
    }

    func fixDashes() { content = Markdown.normalizeDashes(content) }

    func copy() {
        copyToPasteboard(content)
        copyFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { self.copyFlash = false }
    }

    func clear() {
        title = ""; subject = ""; audience = ""; mustCover = ""
        content = ""; refineInput = ""; errorMessage = ""; version = 0
    }

    /// Pulls a saved prompt in as the starting brief, so History feeds Docs.
    func load(from record: PromptRecord) {
        title = ""
        subject = record.goal
        audience = record.role ?? ""
        mustCover = record.generated_prompt
    }

    var exportFileName: String {
        let base = title.isEmpty ? subject : title
        let prefix = effectiveDocType.lowercased().replacingOccurrences(of: " ", with: "-")
        return Markdown.fileName(for: base, prefix: prefix)
    }

    // MARK: Prompt construction

    private var maxTokens: Int {
        switch effectiveDepth {
        case "Brief": return 1200
        case "Deep":  return 4000
        default:      return 2500
        }
    }

    private var lengthRule: String {
        switch effectiveDepth {
        case "Brief":
            return "Keep it to roughly 150 to 300 words, three sections at most."
        case "Deep":
            return "Be thorough: 800 to 1500 words, with sub-sections, worked examples, and edge cases called out explicitly."
        default:
            return "Aim for 400 to 700 words."
        }
    }

    private func capped(_ s: String, _ limit: Int) -> String {
        s.count <= limit ? s : String(s.prefix(limit)) + "..."
    }

    private func buildSystemPrompt() -> String {
        [
            "Write a complete \(effectiveDocType) as a GitHub-flavored markdown document. Return only the markdown. No commentary before or after it, and do not wrap the document in a code fence.",
            "Open with a single '# ' title and use '##' for sections, never skipping a heading level. Use lists, tables, and fenced code blocks only where they carry information.",
            "Write in plain, specific language. No preamble, no filler, no hedge words ('feel free to', 'consider', 'it is worth noting'). Never leave a placeholder such as TODO or [insert x]: if a detail was not supplied, write the section around what is known.",
            "Never use em dashes or en dashes. Use periods, commas, colons, or parentheses instead.",
            lengthRule
        ].joined(separator: " ")
    }

    private var refineSystemPrompt: String {
        [
            "Revise the markdown document below according to the requested change. Return the full revised document as markdown, with no commentary and no surrounding code fence.",
            "Keep every section the request did not ask you to change, including its wording.",
            "Never use em dashes or en dashes. Use periods, commas, colons, or parentheses instead."
        ].joined(separator: " ")
    }

    private func buildUserMessage() -> String {
        var msg = "Document type: \(effectiveDocType)"
        if !title.isEmpty     { msg += "\nTitle: \(capped(title, 200))" }
        msg += "\nSubject: \(capped(subject, 3000))"
        if !audience.isEmpty  { msg += "\nAudience: \(capped(audience, 300))" }
        if !mustCover.isEmpty { msg += "\nMust cover: \(capped(mustCover, 2000))" }
        return msg
    }
}

// MARK: - Preview renderer

/// A block-level preview: headings, lists, quotes, rules, and code blocks.
/// Inline emphasis comes from AttributedString. Tables render as raw source,
/// which is a deliberate limit rather than a bug: a real table layout is not
/// worth the code in a 420pt panel.
struct MarkdownPreview: View {
    let source: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                block.view
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private enum Block {
        case heading(level: Int, text: String)
        case bullet(String)
        case numbered(marker: String, text: String)
        case quote(String)
        case rule
        case code(String)
        case paragraph(String)
        case blank

        @ViewBuilder var view: some View {
            switch self {
            case .heading(let level, let text):
                Text(text)
                    .font(QM.mono(level == 1 ? 14 : level == 2 ? 12 : 11))
                    .foregroundColor(level == 1 ? QM.accentMagenta : QM.textPrimary)
                    .tracking(level == 1 ? 1 : 0.5)
                    .padding(.top, level == 1 ? 0 : 6)
            case .bullet(let text):
                HStack(alignment: .top, spacing: 6) {
                    Text("·").font(QM.mono(11)).foregroundColor(QM.accentCyan)
                    Text(MarkdownPreview.inline(text))
                        .font(QM.mono(11)).foregroundColor(QM.textPrimary)
                }
            case .numbered(let marker, let text):
                HStack(alignment: .top, spacing: 6) {
                    Text(marker).font(QM.mono(11)).foregroundColor(QM.accentCyan)
                    Text(MarkdownPreview.inline(text))
                        .font(QM.mono(11)).foregroundColor(QM.textPrimary)
                }
            case .quote(let text):
                HStack(alignment: .top, spacing: 8) {
                    Rectangle().fill(QM.borderTeal).frame(width: 2)
                    Text(MarkdownPreview.inline(text))
                        .font(QM.mono(10)).foregroundColor(QM.textSecondary)
                }
                .fixedSize(horizontal: false, vertical: true)
            case .rule:
                Rectangle().fill(QM.border).frame(height: 1).padding(.vertical, 4)
            case .code(let text):
                Text(text)
                    .font(QM.mono(10))
                    .foregroundColor(QM.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(QM.bgHover)
                    .overlay(Rectangle().stroke(QM.border, lineWidth: 1))
            case .paragraph(let text):
                Text(MarkdownPreview.inline(text))
                    .font(QM.mono(11)).foregroundColor(QM.textPrimary).lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .blank:
                Color.clear.frame(height: 2)
            }
        }
    }

    private static func inline(_ s: String) -> AttributedString {
        (try? AttributedString(
            markdown: s,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(s)
    }

    private var blocks: [Block] {
        var out: [Block] = []
        var codeBuffer: [String] = []
        var inCode = false

        for raw in source.components(separatedBy: .newlines) {
            let t = raw.trimmingCharacters(in: .whitespaces)

            if t.hasPrefix("```") {
                if inCode {
                    out.append(.code(codeBuffer.joined(separator: "\n")))
                    codeBuffer = []; inCode = false
                } else {
                    inCode = true
                }
                continue
            }
            if inCode { codeBuffer.append(raw); continue }

            if t.isEmpty { out.append(.blank); continue }
            if t == "---" || t == "***" || t == "___" { out.append(.rule); continue }

            if t.hasPrefix("#") {
                let level = t.prefix(while: { $0 == "#" }).count
                if level <= 6 {
                    let text = t.dropFirst(level).trimmingCharacters(in: .whitespaces)
                    if !text.isEmpty { out.append(.heading(level: level, text: text)); continue }
                }
            }
            if t.hasPrefix("> ") {
                out.append(.quote(String(t.dropFirst(2)))); continue
            }
            if t.hasPrefix("- ") || t.hasPrefix("* ") {
                out.append(.bullet(String(t.dropFirst(2)))); continue
            }
            if let dot = t.firstIndex(of: "."),
               t.distance(from: t.startIndex, to: dot) <= 3,
               t[t.startIndex..<dot].allSatisfy({ $0.isNumber }),
               t.index(after: dot) < t.endIndex,
               t[t.index(after: dot)] == " " {
                out.append(.numbered(marker: String(t[t.startIndex...dot]),
                                     text: String(t[t.index(dot, offsetBy: 2)...])))
                continue
            }
            out.append(.paragraph(t))
        }
        // An unclosed fence still has to render something.
        if inCode && !codeBuffer.isEmpty {
            out.append(.code(codeBuffer.joined(separator: "\n")))
        }
        return out
    }
}

// MARK: - DocsView

struct DocsView: View {
    @ObservedObject var vm: MarkdownDocViewModel
    @StateObject private var exporter = MarkdownExporter()

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    brief
                    controls
                    if !problem.isEmpty { errorBox }
                    if vm.hasContent {
                        result.id("docResult").padding(.top, 14)
                    }
                    Spacer(minLength: 16)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
#if os(iOS)
            .sheet(isPresented: $exporter.isPresentingShare) {
                if let url = exporter.shareURL { ShareSheet(items: [url]) }
            }
            .scrollDismissesKeyboard(.interactively)
#endif
            .onChangeCompat(of: vm.version) { v in
                if v > 0 {
                    withAnimation(.easeOut(duration: 0.35)) {
                        proxy.scrollTo("docResult", anchor: .top)
                    }
                }
            }
        }
    }

    private var problem: String {
        vm.errorMessage.isEmpty ? exporter.errorMessage : vm.errorMessage
    }

    // MARK: Brief

    @ViewBuilder private var brief: some View {
        field(label: "Document Type") {
            TagFlow(items: vm.docTypes, selected: $vm.docType)
        }
        field(label: "Title", optional: true) {
            PlatformTextField(placeholder: "Left blank, Claude writes one",
                              text: $vm.title)
        }
        field(label: "What It Covers") {
            PlatformTextArea(placeholder: "The subject, in as much detail as you have",
                             text: $vm.subject)
        }
        field(label: "Audience", optional: true) {
            PlatformTextField(placeholder: "New engineer, client, hiring manager…",
                              text: $vm.audience)
        }
        field(label: "Must Cover", optional: true) {
            PlatformTextArea(placeholder: "Required sections, facts, constraints, source text…",
                             text: $vm.mustCover)
        }
        field(label: "Depth") {
            TagFlow(items: vm.depths, selected: $vm.depth)
        }
    }

    @ViewBuilder private var controls: some View {
        HStack(spacing: 10) {
            QMButton(label: vm.isGenerating ? "Writing..." : "Write Document",
                     style: .primary, height: 30,
                     isLoading: vm.isGenerating, flexible: true) { vm.generate() }
            QMButton(label: "Clear All", height: 30) { vm.clear() }
        }
        .padding(.top, 14)
    }

    @ViewBuilder private var errorBox: some View {
        Text(problem)
            .font(QM.mono(10))
            .foregroundColor(QM.accentRed)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(Rectangle().stroke(QM.accentRed.opacity(0.4), lineWidth: 1))
            .padding(.top, 8)
    }

    // MARK: Result

    @ViewBuilder private var result: some View {
        VStack(alignment: .leading, spacing: 8) {
            statsBar
            if !vm.problems.isEmpty { lintPanel }
            if vm.showOutline && !vm.outline.isEmpty { outlinePanel }
            body_
            HStack(spacing: 5) {
                QMButton(label: vm.copyFlash ? "Copied" : "Copy",
                         style: vm.copyFlash ? .active : .ghost, flexible: true) { vm.copy() }
                QMButton(label: "Export MD", flexible: true) {
                    vm.errorMessage = ""
                    exporter.export(vm.content, fileName: vm.exportFileName)
                }
                QMButton(label: vm.showSource ? "Preview" : "Source",
                         style: .ghost, flexible: true) { vm.showSource.toggle() }
            }
            HStack(spacing: 4) {
                PlatformTextField(placeholder: "Add a rollback section, tighten the intro…",
                                  text: $vm.refineInput,
                                  borderOverride: QM.borderHot.opacity(0.5))
                QMButton(label: "Revise →", style: .ghost, isLoading: vm.isRefining) { vm.refine() }
            }
        }
    }

    @ViewBuilder private var statsBar: some View {
        let s = vm.stats
        HStack(spacing: 8) {
            Text("v\(vm.version)")
                .font(QM.mono(9)).foregroundColor(QM.accentAmber)
                .padding(.horizontal, 5).padding(.vertical, 2)
                .overlay(Rectangle().stroke(QM.accentAmber.opacity(0.5), lineWidth: 1))
            Text("\(s.words) WORDS · \(s.headings) HEADINGS · \(s.readingMinutes) MIN")
                .font(QM.mono(9)).foregroundColor(QM.textMuted).tracking(1)
            Spacer()
            if !vm.outline.isEmpty {
                Button(action: { vm.showOutline.toggle() }) {
                    Text(vm.showOutline ? "HIDE OUTLINE" : "OUTLINE")
                        .font(QM.mono(9))
                        .foregroundColor(vm.showOutline ? QM.accentCyan : QM.textMuted)
                        .tracking(1)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder private var lintPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(vm.problems.count) ISSUE\(vm.problems.count == 1 ? "" : "S")")
                    .font(QM.mono(9)).foregroundColor(QM.accentAmber).tracking(1.5)
                Spacer()
                if vm.content.contains("\u{2014}") || vm.content.contains("\u{2013}") {
                    QMButton(label: "Fix Dashes", height: 20) { vm.fixDashes() }
                }
            }
            ForEach(vm.problems, id: \.self) { p in
                Text("· \(p)")
                    .font(QM.mono(9)).foregroundColor(QM.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(Rectangle().stroke(QM.accentAmber.opacity(0.4), lineWidth: 1))
    }

    @ViewBuilder private var outlinePanel: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(vm.outline) { h in
                Text(h.text)
                    .font(QM.mono(9))
                    .foregroundColor(h.level == 1 ? QM.textPrimary : QM.textSecondary)
                    .padding(.leading, CGFloat(h.level - 1) * 10)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(QM.bgElevated)
        .overlay(Rectangle().stroke(QM.border, lineWidth: 1))
    }

    @ViewBuilder private var body_: some View {
        if vm.showSource {
            TextEditor(text: $vm.content)
                .font(QM.mono(11))
                .foregroundColor(QM.textPrimary)
                .scrollContentBackground(.hidden)
                .background(QM.bgElevated)
                .frame(minHeight: 200, maxHeight: 420)
                .overlay(Rectangle().stroke(QM.borderTeal.opacity(0.5), lineWidth: 1))
        } else {
            ScrollView(.vertical, showsIndicators: true) {
                MarkdownPreview(source: vm.content)
                    .padding(10)
                    .textSelection(.enabled)
            }
            .background(QM.bgElevated)
            .frame(minHeight: 200, maxHeight: 420)
            .overlay(Rectangle().stroke(QM.borderTeal.opacity(0.3), lineWidth: 1))
        }
    }

    @ViewBuilder
    private func field<Content: View>(
        label: String,
        optional: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                FieldLabel(text: label)
                if optional {
                    Text("optional")
                        .font(QM.mono(8)).foregroundColor(QM.textMuted).tracking(0.5)
                }
            }
            content()
        }
        .padding(.bottom, 12)
    }
}
