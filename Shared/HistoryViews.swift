// HistoryViews.swift — Shared (macOS + iOS)
//
// Figma desktop 04 (History) and 08 (signed out), mobile 03 (file to folder).
// Sign-in lives on the Profile tab (AppShell.swift).

import SwiftUI

// MARK: - HistoryView

struct HistoryView: View {
    @StateObject var vm = HistoryViewModel()
    @EnvironmentObject var appState: AppState
    @ObservedObject private var auth = AuthService.shared
    @StateObject private var exporter = MarkdownExporter()

    var body: some View {
        VStack(spacing: 0) {
            if !auth.isSignedIn {
                EmptyState(title: "Sign in to see saved prompts",
                           message: "Saved prompts live in your account. Sign in on Profile and they show up here on every device.",
                           actionLabel: "Back to Sign In") { appState.activeTab = AppTab.profile.rawValue }
            } else {
                if !vm.records.isEmpty {
                    ScreenIntro(text: "View your history of saved prompts and skills below.")
                        .padding(.horizontal, QM.Space.s20)
                    collectionBar
                }
                signedInContent
            }
        }
#if os(iOS)
        .sheet(isPresented: $exporter.isPresentingShare) {
            if let url = exporter.shareURL { ShareSheet(items: [url]) }
        }
#endif
        .onAppear { if auth.isSignedIn { vm.load() } }
        .onChangeCompat(of: auth.isSignedIn) { signedIn in
            if signedIn { vm.load() }
        }
    }

    /// Exports every loaded prompt as one markdown document with a table of contents.
    @ViewBuilder var collectionBar: some View {
        VStack(alignment: .leading, spacing: QM.Space.s4) {
            HStack(spacing: QM.Space.s8) {
                Text("\(vm.records.count) SAVED")
                    .font(QM.labelControl).foregroundColor(QM.textSecondary)
                Spacer()
                SmallButton(label: "Export All MD") {
                    exporter.export(
                        Markdown.collection(title: "PG-13 Prompt Library", records: vm.records),
                        fileName: "pg13-prompt-library.md")
                }
            }
            if !exporter.errorMessage.isEmpty {
                FormMessage(text: exporter.errorMessage, kind: .error)
            }
        }
        .padding(.horizontal, QM.Space.s20)
        .padding(.bottom, QM.Space.s10)
    }

    @ViewBuilder var signedInContent: some View {
        VStack(spacing: 0) {
            if vm.isLoading {
                ProgressView().tint(QM.textAccentTeal)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !vm.errorMessage.isEmpty {
                FormMessage(text: vm.errorMessage, kind: .error)
                    .padding(.horizontal, QM.Space.s20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.records.isEmpty {
                EmptyState(title: "No saved prompts yet",
                           message: "Generate a prompt or a skill, then tap save. It shows up here.",
                           actionLabel: "Go to Prompt") { appState.activeTab = AppTab.prompt.rawValue }
            } else {
#if os(iOS)
                List {
                    ForEach(vm.records) { record in
                        HistoryItemView(
                            record: record,
                            isExpanded: vm.expandedIDs.contains(record.id),
                            showFolderInput: vm.folderInputID == record.id,
                            folderInputText: Binding(
                                get: { vm.folderInputText },
                                set: { vm.folderInputText = $0 }),
                            folderNames: vm.folderNames,
                            onToggle:         { vm.toggleExpand(record.id) },
                            onDelete:         { vm.delete(record) },
                            onSetFolder:      { vm.setFolder(record, folder: $0) },
                            onShowFolderInput:{ vm.folderInputID = vm.folderInputID == record.id ? nil : record.id },
                            onUse: { appState.open(record) }
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                vm.delete(record)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
#else
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(vm.records) { record in
                            HistoryItemView(
                                record: record,
                                isExpanded: vm.expandedIDs.contains(record.id),
                                showFolderInput: vm.folderInputID == record.id,
                                folderInputText: Binding(
                                    get: { vm.folderInputText },
                                    set: { vm.folderInputText = $0 }),
                                folderNames: vm.folderNames,
                                onToggle:         { vm.toggleExpand(record.id) },
                                onDelete:         { vm.delete(record) },
                                onSetFolder:      { vm.setFolder(record, folder: $0) },
                                onShowFolderInput:{ vm.folderInputID = vm.folderInputID == record.id ? nil : record.id },
                                onUse: { appState.open(record) }
                            )
                            .contextMenu {
                                Button(role: .destructive) { vm.delete(record) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
#endif
            }
        }
    }
}

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

    @State private var isHovered = false
    @State private var shareFlash = false
    @State private var showShareSheet = false
    @State private var shareSheetText = ""
    @StateObject private var exporter = MarkdownExporter()

    var filteredFolders: [String] {
        folderInputText.isEmpty ? folderNames
            : folderNames.filter { $0.localizedCaseInsensitiveContains(folderInputText) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: QM.Space.s10) {
            HStack(spacing: QM.Space.s16) {
                Button(action: onToggle) {
                    SavedItemHeader(title: record.goal, kind: record.recordKind,
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
            .padding(.horizontal, QM.Space.s10)

            if isExpanded {
                PromptBox(text: record.generated_prompt, maxHeight: 200)
                ResultToolbar(items: [
                    (.copy, "Copy", false, { copyToPasteboard(record.generated_prompt) }),
                    // The folder icon toggles the picker, as in the Figma prototype.
                    (.folder, "Add to folder", showFolderInput, { onShowFolderInput() }),
                    (.share, shareFlash ? "Shared" : "Share", shareFlash, { sharePrompt() }),
                    (.save, "Export markdown", false, { exportMD() }),
                    (.edit, editLabel, false, { onUse() }),
                    (.delete, "Delete", false, { onDelete() }),
                ])
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
        // Figma List row: 16 above and below when collapsed.
        .padding(.vertical, isExpanded ? QM.Space.s10 : QM.Space.s16)
        .background(isHovered && !isExpanded ? QM.selected : Color.clear)
#if os(macOS)
        .onHover { isHovered = $0 }
#endif
        .overlay(alignment: .bottom) {
            Rectangle().fill(QM.borderDefault).frame(height: QM.stroke)
        }
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
            Markdown.document(goal: record.goal, role: record.role,
                              tone: record.tone, style: record.style,
                              prompt: record.generated_prompt,
                              date: record.displayDate),
            fileName: Markdown.fileName(for: record.goal))
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
