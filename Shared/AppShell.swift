// AppShell.swift — Shared (macOS + iOS)
//
// The frame every Figma screen shares: Window/Header, Navigation/Primary Tabs,
// then the screen body (padding 10 top and bottom, 20 sides).

import SwiftUI

struct AppShell: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            WindowHeader()
            VStack(spacing: QM.Space.s10) {
                PrimaryTabs(selection: $appState.activeTab)
                    .padding(.horizontal, QM.Space.s20)
                    .padding(.top, QM.Space.s10)
                screen
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(QM.screen)
        .background(QM.canvas)
        .preferredColorScheme(appState.lightMode ? .light : .dark)
    }

    @ViewBuilder private var screen: some View {
        switch AppTab(rawValue: appState.activeTab) ?? .prompt {
        case .prompt:  GenerateView(vm: appState.generateVM)
        case .docs:    DocsView(vm: appState.docVM)
        case .history: HistoryView()
        case .folders: FoldersView()
        case .profile: ProfileView()
        }
    }
}

// MARK: - ProfileView (screens 12–15 signed out, 13 signed in)

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var auth = AuthService.shared
    @State private var email = ""
    @State private var password = ""
    @State private var working: Action? = nil
    @State private var errorMessage = ""
    @State private var noticeMessage = ""

    private enum Action { case createAccount, signIn }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: QM.Space.s16) {
                if auth.isSignedIn { signedIn } else { signedOut }
                themeToggle
            }
            .padding(.horizontal, QM.Space.s20)
            .padding(.vertical, QM.Space.s10)
        }
    }

    // MARK: Signed out (12, 14, 15)

    @ViewBuilder private var signedOut: some View {
        ScreenTitle(title: "Create account / Sign in",
                    subtitle: "Enter your details to access your account.")
        VStack(alignment: .leading, spacing: QM.Space.s12) {
            AuthField(label: "Email", placeholder: "name@example.com", text: $email)
            AuthField(label: "Password", placeholder: "••••••••", text: $password, secure: true)
        }
        if !errorMessage.isEmpty { FormMessage(text: errorMessage, kind: .error) }
        if !noticeMessage.isEmpty { FormMessage(text: noticeMessage, kind: .notice) }
        VStack(spacing: QM.Space.s10) {
            LargeButton(label: "Create Account", style: .primary,
                        isLoading: working == .createAccount) { submit(.createAccount) }
            LargeButton(label: "Sign In", style: .secondary,
                        isLoading: working == .signIn) { submit(.signIn) }
        }
    }

    // MARK: Signed in (13)

    @ViewBuilder private var signedIn: some View {
        ScreenTitle(title: "Profile", subtitle: "Signed in as \(auth.email ?? "")")
        Text("Saved prompts and folders sync to this account on every device.")
            .font(QM.bodyPrompt)
            .foregroundColor(QM.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        LargeButton(label: "Sign Out", style: .secondary) { auth.signOut() }
    }

    private var themeToggle: some View {
        SmallButton(label: appState.lightMode ? "Dark mode" : "Light mode") {
            appState.lightMode.toggle()
        }
        .padding(.top, QM.Space.s8)
    }

    private func submit(_ action: Action) {
        let e = email.trimmingCharacters(in: .whitespaces)
        guard !e.isEmpty, !password.isEmpty else {
            errorMessage = "Email and password are required."; return
        }
        guard SupabaseConfig.isConfigured else {
            errorMessage = "Sync backend not configured yet."; return
        }
        working = action; errorMessage = ""; noticeMessage = ""
        Task { @MainActor in
            do {
                if action == .createAccount { try await auth.signUp(email: e, password: password) }
                else                        { try await auth.signIn(email: e, password: password) }
                password = ""
            } catch ServiceError.emailConfirmationRequired {
                noticeMessage = ServiceError.emailConfirmationRequired.localizedDescription
                password = ""
            } catch ServiceError.accountAlreadyExists {
                // Keep the password: the SIGN IN tap that follows can use it.
                noticeMessage = ServiceError.accountAlreadyExists.localizedDescription
            } catch {
                errorMessage = error.localizedDescription
            }
            working = nil
        }
    }
}
