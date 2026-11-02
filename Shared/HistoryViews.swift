// HistoryViews.swift — Shared (macOS + iOS)
//
// One saved record in the SAVED tab (FolderViews.swift): Figma List
// "Saved Item" and the file-to-folder picker (mobile 03).

import SwiftUI

// MARK: - HistoryItemView

struct HistoryItemView: View {
    let record: PromptRecord
    let isExpanded: Bool
    let showFolderInput: Bool
    @Binding var folderInputText: String
    let folderNames: [String]
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onSetFolder: (String?) -> Void
    let onShowFolderInput: () -> Void
    let onUse: () -> Void
    /// Set inside an open folder: adds REMOVE beside SAVE in the folder picker.
    var onRemoveFromFolder: (() -> Void)? = nil
    /// Set where titles can be edited: adds RENAME to the toolbar. Blank
    /// clears the title, and the row falls back to the goal.
    var onRename: ((String) -> Void)? = nil

    @State private var isHovered = false
    @State private var shareFlash = false
    @State private var showShareSheet = false
    @State private var shareSheetText = ""
    @State private var showRenameInput = false
    @State private var renameText = ""
    @StateObject private var exporter = MarkdownExporter()

    var filteredFolders: [String] {
        folderInputText.isEmpty ? folderNames
            : folderNames.filter { $0.localizedCaseInsensitiveContains(folderInputText) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: QM.Space.s10) {
            HStack(spacing: QM.Space.s16) {
                Button(action: onToggle) {
                    SavedItemHeader(title: record.displayTitle, kind: record.recordKind,
                                    tags: tags, isExpanded: isExpanded)
                }
                .buttonStyle(.plain)
                .accessibilityHint(isExpanded ? "Collapses the prompt" : "Shows the full prompt")
                if !isExpanded {
                    Button(action: onUse) {
                        Image(systemName: ResultAction.edit.symbol)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(QM.iconDefault)
                            .frame(width: 24, height: 23)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(editLabel)
                    .accessibilityLabel(editLabel)
                }
            }

            if isExpanded {
                PromptBox(text: record.generated_prompt, maxHeight: 200)
                ResultToolbar(items: toolbarItems)
                if showRenameInput, let onRename {
                    InlineInput(placeholder: "Title...", text: $renameText, actionLabel: "Save") {
                        onRename(renameText)
                        showRenameInput = false
                    }
                }
                if showFolderInput {
                    HStack(spacing: QM.Space.s8) {
                        InlineInput(placeholder: "Folder name...", text: $folderInputText,
                                    actionLabel: "Save") {
                            guard !folderInputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            onSetFolder(folderInputText)
                        }
                        if let onRemoveFromFolder {
                            SmallButton(label: "Remove", style: .label, height: InlineInput.height,
                                        action: onRemoveFromFolder)
                        }
                    }
                    if !filteredFolders.isEmpty {
                        FlowLayout(spacing: QM.Space.s4) { folderChips }
                    }
                }
            }
        }
        // Figma List/Item Type=Saved Item: an outlined card, 16 side padding,
        // 8 above and below, radius/window corners.
        .padding(.horizontal, QM.Space.s16)
        .padding(.vertical, QM.Space.s8)
        .qmBox(fill: isHovered && !isExpanded ? QM.selected : QM.control,
               stroke: QM.borderDefault, radius: QM.Radius.window)
#if os(macOS)
        .onHover { isHovered = $0 }
#endif
        .padding(.horizontal, QM.Space.s20)
#if os(iOS)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(text: shareSheetText)
        }
        .sheet(isPresented: $exporter.isPresentingShare) {
            if let url = exporter.shareURL {
                ShareSheet(items: [url])
            }
        }
#endif
    }

    private var toolbarItems: [(action: ResultAction, label: String, active: Bool, run: () -> Void)] {
        var items: [(action: ResultAction, label: String, active: Bool, run: () -> Void)] = [
            (.copy, "Copy", false, { copyToPasteboard(record.generated_prompt) }),
            // The folder icon toggles the picker, as in the Figma prototype.
            (.folder, "Add to folder", showFolderInput, { onShowFolderInput() }),
            (.share, shareFlash ? "Shared" : "Share", shareFlash, { sharePrompt() }),
            (.save, "Export markdown", false, { exportMD() }),
        ]
        if onRename != nil {
            items.append((.rename, "Rename", showRenameInput, {
                renameText = record.displayTitle
                showRenameInput.toggle()
            }))
        }
        items += [
            (.edit, editLabel, false, { onUse() }),
            (.delete, "Delete", false, { onDelete() }),
        ]
        return items
    }

    private var editLabel: String {
        record.recordKind == .skill ? "Edit in Skill" : "Edit in Prompt"
    }

    private var tags: [String] {
        [record.tone, record.style, record.folder]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func sharePrompt() {
        let text = shareText(goal: record.goal, role: record.role, tone: record.tone,
                             style: record.style, prompt: record.generated_prompt)
#if os(iOS)
        shareSheetText = text
        showShareSheet = true
#else
        copyToPasteboard(text)
#endif
        shareFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { shareFlash = false }
    }

    private func exportMD() {
        exporter.export(
            Markdown.document(goal: record.goal, title: record.title, role: record.role,
                              tone: record.tone, style: record.style,
                              prompt: record.generated_prompt,
                              date: record.displayDate),
            fileName: Markdown.fileName(for: record.displayTitle))
    }

    @ViewBuilder var folderChips: some View {
        ForEach(filteredFolders, id: \.self) { name in
            Button(action: { onSetFolder(name) }) {
                TagChip(text: name, isSelected: false)
            }
            .buttonStyle(.plain)
        }
    }
}
