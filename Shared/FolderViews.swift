// FolderViews.swift — Shared (macOS + iOS)
//
// The SAVED tab, Figma 191:2968: desktop 04 (folder list, General pinned
// first), 05 (open General), 06 (open folder), 08 (signed out) and
// 09 (General empty). History and Folders used to be separate tabs.

import SwiftUI

// MARK: - SavedView

struct SavedView: View {
    @StateObject var vm = SavedViewModel()
    @EnvironmentObject var appState: AppState
    @ObservedObject private var auth = AuthService.shared
    @StateObject private var exporter = MarkdownExporter()
    @State private var showRenameFolder = false
    @State private var renameFolderText = ""
    @State private var isExportingAll = false

    var body: some View {
        VStack(spacing: 0) {
            if !auth.isSignedIn {
                EmptyState(title: "Sign in to see saved prompts",
                           message: "Saved prompts live in your account. Sign in on Profile and they show up here on every device.",
                           actionLabel: "Back to Sign In") { appState.activeTab = AppTab.profile.rawValue }
            } else if vm.selectedFolder != nil { drillView } else { folderListView }
        }
#if os(iOS)
        .sheet(isPresented: $exporter.isPresentingShare) {
            if let url = exporter.shareURL { ShareSheet(items: [url]) }
        }
#endif
        .onAppear { if auth.isSignedIn { vm.loadFolders() } }
        .onChangeCompat(of: auth.isSignedIn) { signedIn in
            if signedIn { vm.loadFolders() }
        }
    }

    /// Exports every saved prompt in every folder as one markdown document
    /// with a table of contents.
    private func exportAll() {
        isExportingAll = true
        exporter.errorMessage = ""
        Task { @MainActor in
            do {
                let all = try await CloudHistoryStore.shared.fetchAllHistory()
                exporter.export(
                    Markdown.collection(title: "PG-13 Prompt Library", records: all),
                    fileName: "pg13-prompt-library.md")
            } catch {
                exporter.errorMessage = ServiceError
                    .exportFailed(error.localizedDescription).localizedDescription
            }
            isExportingAll = false
        }
    }

    @ViewBuilder var collectionBar: some View {
        VStack(alignment: .leading, spacing: QM.Space.s4) {
            HStack(spacing: QM.Space.s8) {
                Text("\(vm.totalCount) SAVED")
                    .font(QM.labelControl).foregroundColor(QM.textSecondary)
                Spacer()
                SmallButton(label: isExportingAll ? "Exporting..." : "Export All MD") {
                    exportAll()
                }
                .disabled(isExportingAll)
            }
            if !exporter.errorMessage.isEmpty {
                FormMessage(text: exporter.errorMessage, kind: .error)
            }
        }
        .padding(.bottom, QM.Space.s10)
    }

    var folderListView: some View {
        VStack(spacing: 0) {
            if vm.isLoading {
                ProgressView().tint(QM.textAccentTeal)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !vm.errorMessage.isEmpty {
                FormMessage(text: vm.errorMessage, kind: .error)
                    .padding(.horizontal, QM.Space.s20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ScreenIntro(text: "Prompts and Skills saved to folders.")
                        if vm.totalCount > 0 { collectionBar }
                        // General is the default folder: always present, always first.
                        FolderRow(name: DefaultFolder.name, count: vm.generalCount, isDefault: true) {
                            vm.openFolder(DefaultFolder.name)
                        }
                        ForEach(vm.folders, id: \.name) { folder in
                            FolderRow(name: folder.name, count: folder.count) {
                                vm.openFolder(folder.name)
                            }
                        }
                    }
                    .padding(.horizontal, QM.Space.s20)
                }
            }
        }
    }

    var drillView: some View {
        VStack(spacing: QM.Space.s16) {
            BackBar(backLabel: "Saved",
                    title: vm.selectedFolder ?? "",
                    trailingLabel: vm.folderRecords.isEmpty ? nil : "MD",
                    onBack: { showRenameFolder = false; vm.back() },
                    onTrailing: {
                        exporter.export(
                            Markdown.collection(title: vm.selectedFolder ?? "Folder",
                                                records: vm.folderRecords),
                            fileName: Markdown.fileName(for: vm.selectedFolder ?? "",
                                                        prefix: "pg13-folder"))
                    })
                .padding(.horizontal, QM.Space.s20)

            // General cannot be renamed.
            if !vm.isGeneralOpen {
                if showRenameFolder {
                    InlineInput(placeholder: "New folder name...", text: $renameFolderText,
                                actionLabel: "Save") {
                        guard !renameFolderText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        vm.renameFolder(to: renameFolderText)
                        showRenameFolder = false
                    }
                    .padding(.horizontal, QM.Space.s20)
                } else {
                    TextLink(label: "Rename folder", color: QM.textAccentTeal) {
                        renameFolderText = vm.selectedFolder ?? ""
                        showRenameFolder = true
                    }
                    .padding(.horizontal, QM.Space.s20)
                }
            }

            if !exporter.errorMessage.isEmpty {
                FormMessage(text: exporter.errorMessage, kind: .error)
                    .padding(.horizontal, QM.Space.s20)
            }

            if vm.isLoading {
                ProgressView().tint(QM.textAccentTeal)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !vm.errorMessage.isEmpty {
                FormMessage(text: vm.errorMessage, kind: .error)
                    .padding(.horizontal, QM.Space.s20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.folderRecords.isEmpty {
                if vm.isGeneralOpen {
                    // Figma 09-general-empty-desktop: no action.
                    EmptyState(title: "No saved prompts yet",
                               message: "Prompts you save land here until you move them to another folder.")
                } else {
                    EmptyState(title: "Nothing in \(vm.selectedFolder ?? "this folder")",
                               message: "File prompts here from General with the folder button.")
                }
            } else {
                recordList
            }
        }
    }

    @ViewBuilder var recordList: some View {
#if os(iOS)
        List {
            ForEach(vm.folderRecords) { record in
                item(record)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) { vm.delete(record) } label: {
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
                ForEach(vm.folderRecords) { record in
                    item(record)
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

    private func item(_ record: PromptRecord) -> some View {
        HistoryItemView(
            record: record,
            isExpanded: vm.expandedIDs.contains(record.id),
            showFolderInput: vm.folderInputID == record.id,
            folderInputText: $vm.folderInputText,
            folderNames: vm.folderNames.filter { $0 != vm.selectedFolder },
            onToggle:          { vm.toggleExpand(record.id) },
            onDelete:          { vm.delete(record) },
            onSetFolder:       { vm.setFolder(record, folder: $0) },
            onShowFolderInput: { vm.toggleFolderInput(record.id) },
            onUse:             { appState.open(record) },
            // REMOVE sends a record back to General, so General has no REMOVE.
            onRemoveFromFolder: vm.isGeneralOpen
                ? nil : ({ vm.setFolder(record, folder: nil) } as () -> Void),
            onRename:          { vm.rename(record, to: $0) }
        )
    }
}
