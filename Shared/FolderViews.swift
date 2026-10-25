// FolderViews.swift — Shared (macOS + iOS)
//
// Figma desktop 05 (folders), 06 (open folder), 09 (signed out);
// mobile 06 (no folders yet) and 08 (empty folder).

import SwiftUI

// MARK: - FoldersView

struct FoldersView: View {
    @StateObject var vm = FoldersViewModel()
    @EnvironmentObject var appState: AppState
    @ObservedObject private var auth = AuthService.shared
    @StateObject private var exporter = MarkdownExporter()

    var body: some View {
        VStack(spacing: 0) {
            if !auth.isSignedIn {
                EmptyState(title: "Sign in to see folders",
                           message: "Folders live in your account. Sign in on Profile to see and organize them.",
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

    var folderListView: some View {
        VStack(spacing: 0) {
            if vm.isLoading {
                ProgressView().tint(QM.textAccentTeal)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !vm.errorMessage.isEmpty {
                FormMessage(text: vm.errorMessage, kind: .error)
                    .padding(.horizontal, QM.Space.s20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.folders.isEmpty {
                EmptyState(title: "No folders yet",
                           message: "Open a prompt in Saved and tap the folder button to file it. The folder appears here.",
                           actionLabel: "Go to Saved") { appState.activeTab = AppTab.history.rawValue }
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ScreenIntro(text: "Prompts and Skills saved to folders.")
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
            BackBar(backLabel: "Folders",
                    title: vm.selectedFolder ?? "",
                    trailingLabel: vm.folderRecords.isEmpty ? nil : "MD",
                    onBack: { vm.back() },
                    onTrailing: {
                        exporter.export(
                            Markdown.collection(title: vm.selectedFolder ?? "Folder",
                                                records: vm.folderRecords),
                            fileName: Markdown.fileName(for: vm.selectedFolder ?? "",
                                                        prefix: "pg13-folder"))
                    })
                .padding(.horizontal, QM.Space.s20)

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
                EmptyState(title: "Nothing in \(vm.selectedFolder ?? "this folder")",
                           message: "File prompts here from Saved with the folder button.")
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(vm.folderRecords) { record in
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
                                onRemoveFromFolder: { vm.setFolder(record, folder: nil) }
                            )
                        }
                    }
                }
            }
        }
    }
}
