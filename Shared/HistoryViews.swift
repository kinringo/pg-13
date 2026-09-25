// HistoryViews.swift — Shared (macOS + iOS)

import SwiftUI

// MARK: - AuthGateView

struct AuthGateView: View {
    @ObservedObject private var auth = AuthService.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isWorking = false
    @State private var errorMessage = ""
    @State private var noticeMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Spacer()

            Text(isSignUp ? "CREATE ACCOUNT" : "SIGN IN")
                .font(QM.mono(10)).foregroundColor(QM.accentCyan).tracking(2)
            Text("History syncs privately across your devices.\nPrompts are only visible to your account.")
                .font(QM.mono(10)).foregroundColor(QM.textMuted).lineSpacing(3)

            PlatformTextField(placeholder: "Email", text: $email)

            SecureField("Password", text: $password)
                .font(QM.mono(12))
                .foregroundColor(QM.textPrimary)
                .textFieldStyle(.plain)
                .padding(.horizontal, 10)
                .frame(height: 34)
                .background(QM.bgElevated)
                .overlay(Rectangle().stroke(QM.borderTeal.opacity(0.4), lineWidth: 1))

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(QM.mono(10)).foregroundColor(QM.accentRed).lineSpacing(2)
            }
            // A sign-up that needs email confirmation succeeded. Showing it in
            // red alongside real failures is what made it read as a bug.
            if !noticeMessage.isEmpty {
                Text(noticeMessage)
                    .font(QM.mono(10)).foregroundColor(QM.accentCyan).lineSpacing(2)
            }

            QMButton(label: isSignUp ? "Create Account" : "Sign In",
                     style: .primary, height: 30, isLoading: isWorking, flexible: true) { submit() }

            Button(action: { isSignUp.toggle(); errorMessage = ""; noticeMessage = "" }) {
                Text(isSignUp ? "Have an account? Sign in" : "New here? Create an account")
                    .font(QM.mono(10)).foregroundColor(QM.textSecondary).underline()
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func submit() {
        let e = email.trimmingCharacters(in: .whitespaces)
        guard !e.isEmpty, !password.isEmpty else {
            errorMessage = "Email and password are required."; return
        }
        guard SupabaseConfig.isConfigured else {
            errorMessage = "Sync backend not configured yet."; return
        }
        isWorking = true; errorMessage = ""; noticeMessage = ""
        Task { @MainActor in
            do {
                if isSignUp { try await AuthService.shared.signUp(email: e, password: password) }
                else        { try await AuthService.shared.signIn(email: e, password: password) }
            } catch ServiceError.emailConfirmationRequired {
                // Drop the form back to Sign In so the next tap is the one
                // that will actually work once the link is clicked.
                noticeMessage = ServiceError.emailConfirmationRequired.localizedDescription
                isSignUp = false
                password = ""
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }
}

// MARK: - Account footer (email + sign out)

struct AccountRow: View {
    @ObservedObject private var auth = AuthService.shared

    var body: some View {
        HStack {
            Text(auth.email ?? "")
                .font(QM.mono(9)).foregroundColor(QM.textMuted)
            Spacer()
            Button(action: { auth.signOut() }) {
                Text("Sign out")
                    .font(QM.mono(9)).foregroundColor(QM.textSecondary).underline()
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .background(QM.bgElevated)
        .overlay(alignment: .top) { Rectangle().fill(QM.border).frame(height: 1) }
    }
}

// MARK: - HistoryView

struct HistoryView: View {
    @StateObject var vm = HistoryViewModel()
    @EnvironmentObject var appState: AppState
    @ObservedObject private var auth = AuthService.shared
    @StateObject private var exporter = MarkdownExporter()

    var body: some View {
        VStack(spacing: 0) {
            if !auth.isSignedIn {
                AuthGateView()
            } else {
                if !vm.records.isEmpty { collectionBar }
                signedInContent
                AccountRow()
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
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("\(vm.records.count) SAVED")
                    .font(QM.mono(9)).foregroundColor(QM.textMuted).tracking(1.5)
                Spacer()
                QMButton(label: "Export All MD") {
                    exporter.export(
                        Markdown.collection(title: "PG-13 Prompt Library", records: vm.records),
                        fileName: "pg13-prompt-library.md")
                }
            }
            if !exporter.errorMessage.isEmpty {
                Text(exporter.errorMessage)
                    .font(QM.mono(9)).foregroundColor(QM.accentRed)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(QM.bgElevated)
        .overlay(alignment: .bottom) { Rectangle().fill(QM.border).frame(height: 1) }
    }

    @ViewBuilder var signedInContent: some View {
        VStack(spacing: 0) {
            if vm.isLoading {
                ProgressView().tint(QM.accentCyan)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !vm.errorMessage.isEmpty {
                Text(vm.errorMessage)
                    .font(QM.mono(11)).foregroundColor(QM.accentRed)
                    .multilineTextAlignment(.center).padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.records.isEmpty {
                Text("No history yet.")
                    .font(QM.mono(12)).foregroundColor(QM.textMuted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        .listRowSeparatorTint(QM.border)
                        .listRowBackground(QM.bgBase)
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
                .background(QM.bgBase)
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
                            Rectangle().fill(QM.border).frame(height: 1)
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
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            Button(action: onToggle) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(record.goal.uppercased())
                        .font(QM.mono(10)).foregroundColor(QM.textPrimary)
                        .tracking(0.8)
                        .lineLimit(isExpanded ? nil : 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 6) {
                        if let t = record.tone,   !t.isEmpty { tagPill(t, color: QM.textMuted) }
                        if let s = record.style,  !s.isEmpty { tagPill(s, color: QM.textMuted) }
                        if let f = record.folder              { tagPill(f, color: QM.accentCyan) }
                        Spacer()
                        Text(record.displayDate)
                            .font(QM.mono(9)).foregroundColor(QM.textMuted)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(isHovered ? QM.bgHover : QM.bgBase)
            }
            .buttonStyle(.plain)
#if os(macOS)
            .onHover { isHovered = $0 }
#endif

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    ScrollView(.vertical, showsIndicators: true) {
                        Text(record.generated_prompt)
                            .font(QM.mono(11)).foregroundColor(QM.textPrimary)
                            .lineSpacing(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 160)
                    .padding(10)
                    .background(QM.bgElevated)
                    .overlay(Rectangle().stroke(QM.borderTeal.opacity(0.4), lineWidth: 1))

                    HStack(spacing: 5) { actionButtons }

                    if showFolderInput {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 4) {
                                PlatformTextField(placeholder: "Folder name…", text: $folderInputText)
                                QMButton(label: "Save", style: .primary) {
                                    guard !folderInputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                                    onSetFolder(folderInputText)
                                }
                            }
                            if !filteredFolders.isEmpty {
                                FlowLayout(spacing: 4) { folderChips }
                            }
                        }
                    }
                }
                .padding(.horizontal, 14).padding(.bottom, 12)
                .background(QM.bgBase)
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
        }
    }

    @ViewBuilder var actionButtons: some View {
        QMButton(label: "Copy", flexible: true) { copyToPasteboard(record.generated_prompt) }
        QMButton(label: shareFlash ? "Shared" : "Share", style: shareFlash ? .active : .ghost, flexible: true) {
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
        QMButton(label: "MD", flexible: true) {
            exporter.export(
                Markdown.document(goal: record.goal, role: record.role,
                                  tone: record.tone, style: record.style,
                                  prompt: record.generated_prompt,
                                  date: record.displayDate),
                fileName: Markdown.fileName(for: record.goal))
        }
        QMButton(label: "+ Folder", flexible: true) { onShowFolderInput() }
        QMButton(label: "Edit", style: .active, flexible: true) { onUse() }
    }

    @ViewBuilder var folderChips: some View {
        ForEach(filteredFolders, id: \.self) { name in
            Button(action: { onSetFolder(name) }) {
                Text(name)
                    .font(QM.mono(10)).foregroundColor(QM.accentCyan)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(QM.accentCyan.opacity(0.08))
                    .overlay(Rectangle().stroke(QM.accentCyan.opacity(0.35), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    func tagPill(_ text: String, color: Color) -> some View {
        Text(text.trimmingCharacters(in: .whitespaces))
            .font(QM.mono(9)).foregroundColor(color)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .overlay(Rectangle().stroke(color.opacity(0.4), lineWidth: 1))
    }
}
