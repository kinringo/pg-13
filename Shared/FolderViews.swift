// FolderViews.swift — Shared (macOS + iOS)

import SwiftUI

// MARK: - FoldersView

struct FoldersView: View {
    @StateObject var vm = FoldersViewModel()
    @ObservedObject private var auth = AuthService.shared
    @StateObject private var exporter = MarkdownExporter()

    var body: some View {
        VStack(spacing: 0) {
            if !auth.isSignedIn {
                AuthGateView()
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
                ProgressView().tint(QM.accentCyan)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !vm.errorMessage.isEmpty {
                Text(vm.errorMessage)
                    .font(QM.mono(11)).foregroundColor(QM.accentRed)
                    .multilineTextAlignment(.center).padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.folders.isEmpty {
                Text("No folders yet.")
                    .font(QM.mono(12)).foregroundColor(QM.textMuted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(vm.folders, id: \.name) { folder in
                            FolderRowView(name: folder.name, count: folder.count) {
                                vm.openFolder(folder.name)
                            }
                            Rectangle().fill(QM.border).frame(height: 1)
                        }
                    }
                }
            }
        }
    }

    var drillView: some View {
        VStack(spacing: 0) {
            // Back bar
            HStack {
                Button(action: { vm.back() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left").font(.system(size: 10))
                        Text("Folders").font(QM.mono(11))
                    }
                    .foregroundColor(QM.accentCyan)
                }
                .buttonStyle(.plain)
                Spacer()
                Text(vm.selectedFolder ?? "")
                    .font(QM.mono(12)).foregroundColor(QM.textPrimary).tracking(0.5)
                if !vm.folderRecords.isEmpty {
                    QMButton(label: "MD") {
                        exporter.export(
                            Markdown.collection(title: vm.selectedFolder ?? "Folder",
                                                records: vm.folderRecords),
                            fileName: Markdown.fileName(for: vm.selectedFolder ?? "",
                                                        prefix: "pg13-folder"))
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(QM.bgElevated)
            .overlay(alignment: .bottom) { Rectangle().fill(QM.border).frame(height: 1) }

            if !exporter.errorMessage.isEmpty {
                Text(exporter.errorMessage)
                    .font(QM.mono(9)).foregroundColor(QM.accentRed)
                    .padding(.horizontal, 14).padding(.top, 6)
            }

            if vm.isLoading {
                ProgressView().tint(QM.accentCyan)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !vm.errorMessage.isEmpty {
                Text(vm.errorMessage)
                    .font(QM.mono(11)).foregroundColor(QM.accentRed)
                    .multilineTextAlignment(.center).padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.folderRecords.isEmpty {
                Text("No prompts in this folder.")
                    .font(QM.mono(12)).foregroundColor(QM.textMuted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                            Rectangle().fill(QM.border).frame(height: 1)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - FolderRowView

struct FolderRowView: View {
    let name: String
    let count: Int
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "folder").font(.system(size: 12)).foregroundColor(QM.accentAmber)
                Text(name).font(QM.mono(13)).foregroundColor(QM.textPrimary)
                Spacer()
                Text("\(count)")
                    .font(QM.mono(11)).foregroundColor(QM.textMuted)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .overlay(Rectangle().stroke(QM.border, lineWidth: 1))
                Image(systemName: "chevron.right").font(.system(size: 9)).foregroundColor(QM.textMuted)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(isHovered ? QM.bgHover : QM.bgBase)
        }
        .buttonStyle(.plain)
#if os(macOS)
        .onHover { isHovered = $0 }
#endif
    }
}

// MARK: - FolderItemView

struct FolderItemView: View {
    let record: PromptRecord
    let isExpanded: Bool
    let onToggle: () -> Void
    let onRemove: () -> Void
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack {
                    Text(record.goal)
                        .font(QM.mono(13)).foregroundColor(QM.textPrimary)
                        .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                    Text(record.displayDate).font(QM.mono(9)).foregroundColor(QM.textMuted)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(isHovered ? QM.bgHover : QM.bgBase)
            }
            .buttonStyle(.plain)
#if os(macOS)
            .onHover { isHovered = $0 }
#endif

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    ScrollView(.vertical, showsIndicators: true) {
                        Text(record.generated_prompt)
                            .font(QM.mono(11)).foregroundColor(QM.textPrimary)
                            .lineSpacing(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 140)
                    .padding(10).background(QM.bgElevated)
                    .overlay(Rectangle().stroke(QM.borderTeal.opacity(0.4), lineWidth: 1))

                    HStack(spacing: 6) {
                        QMButton(label: "Copy")  { copyToPasteboard(record.generated_prompt) }
                        QMButton(label: "Remove", style: .danger) { onRemove() }
                    }
                }
                .padding(.horizontal, 14).padding(.bottom, 12)
            }
        }
    }
}
