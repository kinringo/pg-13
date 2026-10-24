// HistoryViews.swift — Shared (macOS + iOS)
//
// Figma 02 (History), 03 (file to folder), 10 (signed out).
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
                           actionLabel: "Go to Profile") { appState.activeTab = AppTab.profile.rawValue }
            } else {
                if !vm.records.isEmpty { collectionBar }
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
                           message: "Generate a prompt, then tap save. It shows up here.",
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
                            onShowFolderInput:{ vm.folderInputID = record.id },
                            onUse: {
                                appState.generateVM.populate(from: record)
                                appState.activeTab = 0
                            }
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
                                onShowFolderInput:{ vm.folderInputID = record.id },
                                onUse: {
                                    appState.generateVM.populate(from: record)
                                    appState.activeTab = 0
                                }
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
            Button(action: onToggle) {
                SavedItemHeader(title: record.goal, date: record.displayDate, tags: tags)
                    .background(isHovered ? QM.selected : Color.clear)
            }
            .buttonStyle(.plain)
            .accessibilityHint(isExpanded ? "Collapses the prompt" : "Shows the full prompt")
#if os(macOS)
            .onHover { isHovered = $0 }
#endif

            if isExpanded {
                ResultTextArea(title: "Prompt", text: record.generated_prompt, maxHeight: 200)
                ResultToolbar(items: [
                    (.copy, "Copy", false, { copyToPasteboard(record.generated_prompt) }),
                    (.folder, "Add to folder", showFolderInput, { onShowFolderInput() }),
                    (.share, shareFlash ? "Shared" : "Share", shareFlash, { sharePrompt() }),
                    (.save, "Export markdown", false, { exportMD() }),
                    (.edit, "Edit in Prompt", false, { onUse() }),
                    (.delete, "Delete", false, { onDelete() }),
                ])
                if showFolderInput {
                    InlineInput(placeholder: "Folder name...", text: $folderInputText,
                                actionLabel: "Save") {
                        guard !folderInputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        onSetFolder(folderInputText)
                    }
                    if !filteredFolders.isEmpty {
                        FlowLayout(spacing: QM.Space.s4) { folderChips }
                    }
                }
            }
        }
        .padding(.horizontal, QM.Space.s20)
        .padding(.vertical, QM.Space.s10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(QM.borderDivider).frame(height: QM.stroke)
                .padding(.horizontal, QM.Space.s20)
        }
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
