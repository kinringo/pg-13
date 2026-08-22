// Markdown.swift — Shared (macOS + iOS)
//
// Turns prompts into formatted markdown documents: a single prompt, or a whole
// collection (a folder, or the full history) with a table of contents.
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
