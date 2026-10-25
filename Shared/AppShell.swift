// AppShell.swift — Shared (macOS + iOS)
//
// The frame every Figma screen shares: Window/Header, Navigation/Primary Tabs,
// then the screen body (padding 10 top and bottom, 20 sides, 16 between groups).

import SwiftUI

struct AppShell: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            WindowHeader()
            VStack(spacing: QM.Space.s16) {
                // header-and-navigation: the tabs sit flush under the header, full width.
                PrimaryTabs(selection: $appState.activeTab)
                screen
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(QM.screen)
        .background(QM.canvas)
#if os(macOS)
        // The header is the title bar: draw it under the traffic lights.
        .ignoresSafeArea(.container, edges: .top)
#endif
        .preferredColorScheme(appState.lightMode ? .light : .dark)
    }

    @ViewBuilder private var screen: some View {
        switch AppTab(rawValue: appState.activeTab) ?? .prompt {
        case .prompt:  GenerateView(vm: appState.generateVM)
        case .skill:   SkillView(vm: appState.skillVM)
        case .history: HistoryView()
        case .folders: FoldersView()
        case .profile: ProfileView()
        }
    }
}

// MARK: - ProfileView (desktop 01 signed out, 07 signed in)

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var auth = AuthService.shared
    @State private var email = ""
    @State private var password = ""
    /// Desktop 01: the first CREATE ACCOUNT tap switches to create mode, which
    /// hides SIGN IN and asks for details; the second tap creates the account.
    @State private var createMode = false
    @State private var working: Action? = nil
    @State private var errorMessage = ""
    @State private var noticeMessage = ""

    private enum Action { case createAccount, signIn, update }

    var body: some View {
        ScrollView {
            VStack(spacing: QM.Space.s16) {
                if auth.isSignedIn { signedIn } else { signedOut }
                themeToggle
            }
            .padding(.horizontal, QM.Space.s20)
            .padding(.bottom, QM.Space.s20)
        }
        .onAppear { if auth.isSignedIn { email = auth.email ?? "" } }
        .onChangeCompat(of: auth.isSignedIn) { signedIn in
            email = signedIn ? (auth.email ?? "") : ""
            password = ""; createMode = false; errorMessage = ""; noticeMessage = ""
        }
    }

    // MARK: Signed out (01)

    @ViewBuilder private var signedOut: some View {
        ScreenTitle(title: "Create account / Sign in",
                    subtitle: "Enter your details to access your account")
        fields(passwordPlaceholder: "••••••••")
        VStack(spacing: QM.Space.s10) {
            if createMode {
                Text("Enter your information above.")
                    .font(QM.bodyPrompt)
                    .foregroundColor(QM.textAccentCoral)
                    .frame(maxWidth: .infinity)
                    .padding(QM.Space.s4)
            }
            messages
            LargeButton(label: "Create Account", style: .primary,
                        isLoading: working == .createAccount) {
                if createMode { submit(.createAccount) } else { enterCreateMode() }
            }
            if !createMode {
                LargeButton(label: "Sign In", style: .secondary,
                            isLoading: working == .signIn) { submit(.signIn) }
            }
        }
        .padding(.top, QM.Space.s8)
        if createMode {
            TextLink(label: "Back to Sign In", color: QM.textAccentCoral) {
                createMode = false; errorMessage = ""; noticeMessage = ""
            }
        }
        // "Forgot password?" waits on a reset page and Supabase auth email (Parking Lot).
    }

    // MARK: Signed in (07)

    @ViewBuilder private var signedIn: some View {
        ScreenTitle(title: "User profile", subtitle: "Edit your credentials below.")
        fields(passwordPlaceholder: "New password")
        VStack(spacing: QM.Space.s10) {
            messages
            LargeButton(label: "Sign Out", style: .primary) { auth.signOut() }
        }
        .padding(.top, QM.Space.s8)
        TextLink(label: working == .update ? "Saving..." : "Change Password") { updateAccount() }
            .disabled(working != nil)
    }

    private func fields(passwordPlaceholder: String) -> some View {
        VStack(alignment: .leading, spacing: QM.Space.s12) {
            AuthField(label: "Email", placeholder: "name@example.com", text: $email)
            AuthField(label: "Password", placeholder: passwordPlaceholder, text: $password, secure: true)
        }
        .padding(.vertical, QM.Space.s16)
    }

    @ViewBuilder private var messages: some View {
        if !errorMessage.isEmpty { FormMessage(text: errorMessage, kind: .error) }
        if !noticeMessage.isEmpty { FormMessage(text: noticeMessage, kind: .notice) }
    }

    private var themeToggle: some View {
        SmallButton(label: appState.lightMode ? "Dark mode" : "Light mode") {
            appState.lightMode.toggle()
        }
        .padding(.top, QM.Space.s8)
    }

    private func enterCreateMode() {
        createMode = true; errorMessage = ""; noticeMessage = ""
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
                appState.activeTab = AppTab.prompt.rawValue
            } catch ServiceError.emailConfirmationRequired {
                noticeMessage = ServiceError.emailConfirmationRequired.localizedDescription
                password = ""; createMode = false
            } catch ServiceError.accountAlreadyExists {
                // Keep the password: the SIGN IN tap that follows can use it.
                noticeMessage = ServiceError.accountAlreadyExists.localizedDescription
                createMode = false
            } catch {
                errorMessage = error.localizedDescription
            }
            working = nil
        }
    }

    /// Saves a new password, a new email, or both. An unchanged email is skipped.
    private func updateAccount() {
        let e = email.trimmingCharacters(in: .whitespaces)
        let newEmail = (!e.isEmpty && e.lowercased() != (auth.email ?? "").lowercased()) ? e : nil
        let newPassword = password.isEmpty ? nil : password
        guard newEmail != nil || newPassword != nil else {
            errorMessage = "Type a new password, or a new email, above."; noticeMessage = ""; return
        }
        if let p = newPassword, p.count < 6 {
            errorMessage = "Use at least 6 characters for the password."; noticeMessage = ""; return
        }
        working = .update; errorMessage = ""; noticeMessage = ""
        Task { @MainActor in
            do {
                switch try await auth.updateUser(email: newEmail, password: newPassword) {
                case .password:
                    noticeMessage = "Password changed."
                case .emailPending:
                    noticeMessage = "Check \(e) for a link to confirm the new email."
                case .both:
                    noticeMessage = "Password changed. Check \(e) for a link to confirm the new email."
                }
                password = ""
            } catch {
                errorMessage = error.localizedDescription
            }
            working = nil
        }
    }
}
