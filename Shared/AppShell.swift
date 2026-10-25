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
    /// Desktop 11: set to the email that just signed up, while it waits for the
    /// 8-digit code from the "Confirm signup" email.
    @State private var codeEmail: String? = nil
    @State private var code = ""
    /// Desktop 12 (enter email) and 13 (code and new password).
    private enum Reset: Equatable { case email, code(String) }
    @State private var reset: Reset? = nil
    @State private var working: Action? = nil
    @State private var errorMessage = ""
    @State private var noticeMessage = ""

    private enum Action { case createAccount, signIn, update, verify, resend, sendReset, saveReset }

    var body: some View {
        ScrollView {
            VStack(spacing: QM.Space.s16) {
                if auth.isSignedIn { signedIn }
                else if let codeEmail { confirmCode(email: codeEmail) }
                else if reset == .email { forgotPassword }
                else if case .code(let e) = reset { newPassword(email: e) }
                else { signedOut }
                themeToggle
            }
            .padding(.horizontal, QM.Space.s20)
            .padding(.bottom, QM.Space.s20)
        }
        .onAppear { if auth.isSignedIn { email = auth.email ?? "" } }
        .onChangeCompat(of: auth.isSignedIn) { signedIn in
            email = signedIn ? (auth.email ?? "") : ""
            password = ""; createMode = false; errorMessage = ""; noticeMessage = ""
            codeEmail = nil; code = ""; reset = nil
        }
    }

    // MARK: Signed out (01)

    @ViewBuilder private var signedOut: some View {
        ScreenTitle(title: "Create account / Sign in",
                    subtitle: "Enter your details to access your account")
        fields(passwordPlaceholder: "••••••••")
        SectionDivider()
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
        if !createMode {
            TextLink(label: "Forgot Password?", color: QM.textAccentTeal) {
                reset = .email; code = ""; password = ""
                errorMessage = ""; noticeMessage = ""
            }
        }
    }

    // MARK: Confirm code (11, 11b wrong code, 11c code resent)

    @ViewBuilder private func confirmCode(email: String) -> some View {
        ScreenTitle(title: "Confirm your email",
                    subtitle: "We sent an 8-digit code to \(email)")
        AuthField(label: "Code", placeholder: "12345678", text: $code)
            .padding(.vertical, QM.Space.s16)
        SectionDivider()
        VStack(spacing: QM.Space.s10) {
            if !errorMessage.isEmpty { FormMessage(text: errorMessage, kind: .error, centered: true) }
            if !noticeMessage.isEmpty { FormMessage(text: noticeMessage, kind: .notice, centered: true) }
            LargeButton(label: "Verify", style: .primary,
                        isLoading: working == .verify) { verifyCode(email: email) }
        }
        .padding(.top, QM.Space.s8)
        TextLink(label: working == .resend ? "Sending..." : "Resend code",
                 color: QM.textAccentTeal) { resendCode(email: email) }
            .disabled(working != nil)
        TextLink(label: "Back to Sign In", color: QM.textAccentCoral) {
            codeEmail = nil; code = ""; createMode = false
            errorMessage = ""; noticeMessage = ""
        }
    }

    // MARK: Forgot password (12, then 13 and 13b)

    @ViewBuilder private var forgotPassword: some View {
        ScreenTitle(title: "Reset password",
                    subtitle: "Enter your email and we'll send you a code.")
        AuthField(label: "Email", placeholder: "name@example.com", text: $email)
            .padding(.vertical, QM.Space.s16)
        SectionDivider()
        VStack(spacing: QM.Space.s10) {
            centeredMessages
            LargeButton(label: "Send Code", style: .primary,
                        isLoading: working == .sendReset) { sendResetCode() }
        }
        .padding(.top, QM.Space.s8)
        backToSignIn
    }

    @ViewBuilder private func newPassword(email: String) -> some View {
        ScreenTitle(title: "Set a new password",
                    subtitle: "We sent an 8-digit code to \(email)")
        VStack(alignment: .leading, spacing: QM.Space.s12) {
            AuthField(label: "Code", placeholder: "12345678", text: $code)
            AuthField(label: "New Password", placeholder: "••••••••", text: $password, secure: true)
        }
        .padding(.vertical, QM.Space.s16)
        SectionDivider()
        VStack(spacing: QM.Space.s10) {
            centeredMessages
            LargeButton(label: "Save Password", style: .primary,
                        isLoading: working == .saveReset) { saveNewPassword(email: email) }
        }
        .padding(.top, QM.Space.s8)
        TextLink(label: working == .sendReset ? "Sending..." : "Resend code",
                 color: QM.textAccentTeal) { sendResetCode(resend: true) }
            .disabled(working != nil)
        backToSignIn
    }

    @ViewBuilder private var centeredMessages: some View {
        if !errorMessage.isEmpty { FormMessage(text: errorMessage, kind: .error, centered: true) }
        if !noticeMessage.isEmpty { FormMessage(text: noticeMessage, kind: .notice, centered: true) }
    }

    private var backToSignIn: some View {
        TextLink(label: "Back to Sign In", color: QM.textAccentCoral) {
            reset = nil; codeEmail = nil; code = ""; password = ""; createMode = false
            errorMessage = ""; noticeMessage = ""
        }
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
                showCodeStep(for: e)
            } catch ServiceError.emailNotConfirmed {
                // Signed up earlier but never entered the code: send a fresh one.
                showCodeStep(for: e)
                try? await auth.resendSignUpCode(email: e)
            } catch ServiceError.accountAlreadyExists {
                // Keep the password: the SIGN IN tap that follows can use it.
                noticeMessage = ServiceError.accountAlreadyExists.localizedDescription
                createMode = false
            } catch {
                errorMessage = Self.message(for: error)
            }
            working = nil
        }
    }

    private func sendResetCode(resend: Bool = false) {
        let e: String
        if case .code(let sent) = reset { e = sent } else { e = email.trimmingCharacters(in: .whitespaces) }
        guard !e.isEmpty else { errorMessage = "Enter your email."; noticeMessage = ""; return }
        working = .sendReset; errorMessage = ""; noticeMessage = ""
        Task { @MainActor in
            do {
                try await auth.sendPasswordResetCode(email: e)
                reset = .code(e); code = ""
                if resend { noticeMessage = "New code sent. Check your email." }
            } catch {
                errorMessage = Self.message(for: error)
            }
            working = nil
        }
    }

    private func saveNewPassword(email: String) {
        let c = code.filter(\.isNumber)
        guard (6...10).contains(c.count) else {
            errorMessage = "Enter the code from your email."; noticeMessage = ""; return
        }
        // Check the project's rule first: a rejected password after /verify
        // would use up the code.
        let p = password
        guard p.count >= 6, p.contains(where: \.isLowercase), p.contains(where: \.isUppercase),
              p.contains(where: \.isNumber) else {
            errorMessage = "Use at least 6 characters, with a lowercase letter, an uppercase letter and a number."
            noticeMessage = ""; return
        }
        working = .saveReset; errorMessage = ""; noticeMessage = ""
        Task { @MainActor in
            do {
                try await auth.resetPassword(email: email, code: c, newPassword: p)
                appState.activeTab = AppTab.prompt.rawValue
            } catch {
                errorMessage = Self.message(for: error)
            }
            working = nil
        }
    }

    private func showCodeStep(for email: String) {
        codeEmail = email; code = ""; password = ""; createMode = false
        errorMessage = ""; noticeMessage = ""
    }

    private func verifyCode(email: String) {
        // Supabase's Email OTP Length can be 6 to 10 digits; accept any of them.
        let c = code.filter(\.isNumber)
        guard (6...10).contains(c.count) else {
            errorMessage = "Enter the code from your email."; noticeMessage = ""; return
        }
        working = .verify; errorMessage = ""; noticeMessage = ""
        Task { @MainActor in
            do {
                try await auth.verifySignUpCode(email: email, code: c)
                appState.activeTab = AppTab.prompt.rawValue
            } catch {
                errorMessage = Self.message(for: error)
            }
            working = nil
        }
    }

    private func resendCode(email: String) {
        working = .resend; errorMessage = ""; noticeMessage = ""
        Task { @MainActor in
            do {
                try await auth.resendSignUpCode(email: email)
                code = ""
                noticeMessage = "New code sent. Check your email."
            } catch {
                errorMessage = Self.message(for: error)
            }
            working = nil
        }
    }

    /// Supabase auth errors read as plain sentences, as in the Figma error frame
    /// ("Invalid login credentials."), without the "HTTP 400:" prefix.
    private static func message(for error: Error) -> String {
        guard case ServiceError.httpError(_, let msg) = error else {
            return error.localizedDescription
        }
        // Supabase lists every allowed character; say the rule instead.
        if msg.hasPrefix("Password should contain at least one character of each") {
            return "Use at least one lowercase letter, one uppercase letter and one number."
        }
        if msg == "Error sending confirmation email" {
            return "We couldn't send the code email. Try again in a minute."
        }
        return msg.hasSuffix(".") ? msg : msg + "."
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
                errorMessage = Self.message(for: error)
            }
            working = nil
        }
    }
}
