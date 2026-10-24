// FolderViews.swift — Shared (macOS + iOS)
//
// Figma 04 (browse folders), 05 (folder detail), 06 (no folders yet),
// 08 (empty folder), 11 (signed out).

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
                           actionLabel: "Go to Profile") { appState.activeTab = AppTab.profile.rawValue }
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
                           message: "Open a prompt in History and tap the folder button to file it. The folder appears here.",
                           actionLabel: "Go to History") { appState.activeTab = AppTab.history.rawValue }
            } else {
                ScrollView {
                    VStack(spacing: 0) {
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
        VStack(spacing: QM.Space.s10) {
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
                           message: "File prompts here from History with the folder button.")
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(vm.folderRecords) { record in
                            FolderItemView(
                                record: record,
                                isExpanded: vm.expandedIDs.contains(record.id),
                                onToggle: { vm.toggleExpand(record.id) },
                                onRemove: { vm.removeFromFolder(record) }
                            )
                        }
                    }
                }
            }
        }
    }
}

// MARK: - FolderItemView (List/Saved Item inside a folder)

struct FolderItemView: View {
    let record: PromptRecord
    let isExpanded: Bool
    let onToggle: () -> Void
    let onRemove: () -> Void
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: QM.Space.s10) {
            Button(action: onToggle) {
                SavedItemHeader(title: record.goal, date: record.displayDate, tags: tags)
                    .background(isHovered ? QM.selected : Color.clear)
            }
            .buttonStyle(.plain)
#if os(macOS)
            .onHover { isHovered = $0 }
#endif

            if isExpanded {
                ResultTextArea(title: "Prompt", text: record.generated_prompt, maxHeight: 200)
                ResultToolbar(items: [
                    (.copy, "Copy", false, { copyToPasteboard(record.generated_prompt) }),
                    // In a folder, the folder action takes the prompt out (it stays in History).
                    (.folder, "Remove from folder", false, { onRemove() }),
                ])
            }
        }
        .padding(.horizontal, QM.Space.s20)
        .padding(.vertical, QM.Space.s10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(QM.borderDivider).frame(height: QM.stroke)
                .padding(.horizontal, QM.Space.s20)
        }
    }

    private var tags: [String] {
        [record.tone, record.style]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
