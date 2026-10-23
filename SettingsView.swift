import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = SettingsStore.shared
    @ObservedObject var emergencyContact = EmergencyContactStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var appeared = false
    @ObservedObject private var auth = AuthManager.shared
    @Environment(\.openURL) private var openURL
    @State private var showingDeleteConfirm = false
    @State private var showingSignOutConfirm = false
    @State private var deleteError: String?
    @State private var needsRecentLogin = false
    @State private var nameDraft = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header

                    cameraCard
                    speedometerCard
                    qualityCard
                    storageCard
                    emergencyCard
                    batteryCard
                    accountCard
                    legalCard

                    footer
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(backgroundGradient.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(Color.white.opacity(0.14)))
                    }
                }
            }
        }
        .alert("Delete your account?", isPresented: $showingDeleteConfirm) {
            Button("Delete Account", role: .destructive) { performDelete() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This permanently deletes your account and all footage, clips and settings stored by Focus. This can't be undone.")
        }
        .alert("Sign out?", isPresented: $showingSignOutConfirm) {
            Button("Sign Out", role: .destructive) { dismiss(); auth.signOut() }
            Button("Cancel", role: .cancel) { }
        }
        .alert("Couldn't delete account", isPresented: Binding(
            get: { deleteError != nil }, set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: { Text(deleteError ?? "") }
        .alert("Please sign in again", isPresented: $needsRecentLogin) {
            Button("Sign Out", role: .destructive) { dismiss(); auth.signOut() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("For your security, sign in again and then retry deleting your account.")
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { appeared = true }
        }
    }

    /// A faint blue wash at the top rather than flat black — gives the
    /// screen some depth and ties it to the splash's palette.
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.055, green: 0.085, blue: 0.145),
                Color.black
            ],
            startPoint: .top,
            endPoint: .center
        )
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("Focus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)

            Text("Witness and Evidence")
                .font(.system(size: 13, weight: .regular, design: .serif))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .opacity(appeared ? 1 : 0)
    }

    private var footer: some View {
        VStack(spacing: 4) {
            Text("Footage stays on this device unless you enable cloud backup")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.3))
            Text("Version 1.0")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.2))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 18)
    }

    // MARK: - Cards

    private var cameraCard: some View {
        card(
            icon: "camera.aperture",
            tint: Color(red: 0.35, green: 0.65, blue: 1.0),
            title: "Camera Zoom",
            subtitle: settings.zoom == .ultraWide
                ? "Wider view, falls back to 1x if unsupported"
                : "Standard field of view"
        ) {
            optionRow(CameraZoomOption.allCases, selection: $settings.zoom) { $0.rawValue }
        }
    }

    private var speedometerCard: some View {
        card(
            icon: "gauge.with.needle",
            tint: Color(red: 0.45, green: 0.85, blue: 0.7),
            title: "Speedometer",
            subtitle: "On-screen only — burned-in speed is unaffected"
        ) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 82), spacing: 8)],
                spacing: 8
            ) {
                ForEach(SpeedometerStyleOption.allCases) { option in
                    pill(option.rawValue, isSelected: settings.speedometerStyle == option) {
                        select { settings.speedometerStyle = option }
                    }
                }
            }
        }
    }

    private var qualityCard: some View {
        card(
            icon: "film",
            tint: Color(red: 0.75, green: 0.55, blue: 1.0),
            title: "Video Quality",
            subtitle: settings.quality == .hd1080
                ? "Sharper, roughly double the file size"
                : "Balanced — more hours in the same storage"
        ) {
            VStack(spacing: 12) {
                optionRow(VideoQualityOption.allCases, selection: $settings.quality) { $0.rawValue }

                // Showing the bitrate makes the storage trade-off
                // concrete rather than something the user has to infer
                // from the resolution label alone.
                HStack {
                    Label(
                        "\(settings.quality.bitrate / 1_000_000) Mbps",
                        systemImage: "waveform"
                    )
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.45))

                    Spacer()

                    Text("\(settings.quality.width)×\(settings.quality.height)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.35))
                }
            }
        }
    }

    private var storageCard: some View {
        card(
            icon: "internaldrive",
            tint: Color(red: 0.4, green: 0.72, blue: 1.0),
            title: "Storage Limit",
            subtitle: storageSubtitle
        ) {
            VStack(spacing: 12) {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 74), spacing: 8)],
                    spacing: 8
                ) {
                    ForEach(StorageLimitOption.allCases) { option in
                        pill(option.rawValue, isSelected: settings.storageLimit == option) {
                            select { settings.storageLimit = option }
                        }
                    }
                }

                if let free = ClipStorage.shared.deviceFreeBytes() {
                    let freeText = ByteCountFormatter.string(fromByteCount: free, countStyle: .file)
                    let exceedsDevice = settings.storageLimit.bytes > free

                    // Letting someone pick a cap their phone can't
                    // accommodate would silently fail later — flagging it
                    // now is more useful than discovering it mid-drive.
                    noteRow(
                        icon: exceedsDevice ? "exclamationmark.triangle" : "info.circle",
                        text: exceedsDevice
                            ? "Only \(freeText) free on this device — the loop won't reach this limit."
                            : "\(freeText) free on this device.",
                        tint: exceedsDevice ? .orange.opacity(0.8) : .white.opacity(0.38)
                    )
                }

                noteRow(
                    icon: "arrow.triangle.2.circlepath",
                    text: "Lowering the limit deletes the oldest loop footage immediately. Saved clips are never affected."
                )
            }
        }
    }

    private var storageSubtitle: String {
        guard let hours = ClipStorage.shared.capacityHours(for: settings.storageLimit) else {
            return "Oldest footage rotates out when full"
        }
        return hours >= 1
            ? String(format: "About %.1f hours at %@", hours, settings.quality.rawValue)
            : String(format: "About %.0f minutes at %@", hours * 60, settings.quality.rawValue)
    }

    private var emergencyCard: some View {
        card(
            icon: "phone.arrow.up.right",
            tint: Color(red: 1.0, green: 0.45, blue: 0.45),
            title: "Emergency Contact",
            subtitle: emergencyContact.isConfigured
                ? "Message opens automatically after a hard crash"
                : "Not set — no message will be prepared"
        ) {
            VStack(spacing: 10) {
                field("Contact name (optional)", text: $emergencyContact.contactName, icon: "person")
                field("Phone number", text: $emergencyContact.contactPhone, icon: "phone", keyboard: .phonePad)

                noteRow(
                    icon: "info.circle",
                    text: "iOS requires you to tap Send yourself — no app can text someone without your confirmation."
                )
            }
        }
    }

    private var batteryCard: some View {
        card(
            icon: "moon.stars",
            tint: Color(red: 1.0, green: 0.75, blue: 0.35),
            title: "Battery Saving",
            subtitle: settings.screenDim == .off
                ? "Screen stays at full brightness"
                : "Screen dims after \(settings.screenDim.rawValue) idle"
        ) {
            VStack(spacing: 12) {
                optionRow(ScreenDimOption.allCases, selection: $settings.screenDim) { $0.rawValue }

                noteRow(
                    icon: "record.circle",
                    text: "Recording continues while dimmed. Tap anywhere to wake the screen."
                )
            }
        }
    }

    private var legalCard: some View {
        card(
            icon: "doc.text",
            tint: Color(red: 0.65, green: 0.65, blue: 0.7),
            title: "Legal",
            subtitle: "Privacy Policy and Terms of Service"
        ) {
            VStack(spacing: 8) {
                legalRow(title: "Privacy Policy") {
                    openURL(AppConfig.privacyPolicyURL)
                }
                legalRow(title: "Terms of Service") {
                    openURL(AppConfig.termsURL)
                }
                legalRow(title: "Contact Support") {
                    if let url = URL(string: "mailto:\(AppConfig.supportEmail)") { openURL(url) }
                }
            }
        }
    }

    private var accountCard: some View {
        card(
            icon: "person.crop.circle",
            tint: Color(red: 0.55, green: 0.8, blue: 1.0),
            title: "Account",
            subtitle: "Your name, sign out, or delete your account"
        ) {
            VStack(spacing: 8) {
                field("Your name", text: $nameDraft, icon: "person")
                    .onAppear { nameDraft = auth.displayName }
                    .onSubmit { auth.saveName(nameDraft) }
                let trimmed = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty && trimmed != auth.displayName {
                    legalRow(title: "Save Name") {
                        auth.saveName(nameDraft)
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
                legalRow(title: "Sign Out") { showingSignOutConfirm = true }
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showingDeleteConfirm = true
                } label: {
                    HStack {
                        if auth.isDeleting { ProgressView().tint(.red) }
                        Text("Delete Account")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.red)
                        Spacer()
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.black.opacity(0.25)))
                }
                .buttonStyle(.plain)
                .disabled(auth.isDeleting)
            }
        }
    }

    private func performDelete() {
        auth.deleteAccount { result in
            switch result {
            case .success: dismiss()
            case .needsRecentLogin: needsRecentLogin = true
            case .failure(let msg): deleteError = msg
            }
        }
    }

    // MARK: - Building blocks

    private func card<Content: View>(
        icon: String,
        tint: Color,
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(tint)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(tint.opacity(0.15))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.42))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.055))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.09), lineWidth: 1)
                )
        )
    }

    private func optionRow<T: Hashable & Identifiable>(
        _ options: [T],
        selection: Binding<T>,
        label: @escaping (T) -> String
    ) -> some View {
        HStack(spacing: 8) {
            ForEach(options) { option in
                pill(label(option), isSelected: selection.wrappedValue == option) {
                    select { selection.wrappedValue = option }
                }
            }
        }
    }

    private func pill(
        _ text: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .black : .white.opacity(0.78))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.white : Color.white.opacity(0.09))
                )
        }
        .buttonStyle(.plain)
    }

    private func field(
        _ placeholder: String,
        text: Binding<String>,
        icon: String,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.3))
                .frame(width: 16)

            TextField("", text: text, prompt:
                Text(placeholder).foregroundColor(.white.opacity(0.3))
            )
            .font(.system(size: 15))
            .foregroundColor(.white)
            .keyboardType(keyboard)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.25))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private func noteRow(
        icon: String,
        text: String,
        tint: Color = .white.opacity(0.38)
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(tint.opacity(0.75))
                .padding(.top, 1)

            Text(text)
                .font(.system(size: 11))
                .foregroundColor(tint)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func select(_ change: @escaping () -> Void) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            change()
        }
    }

    private func legalRow(title: String, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            HStack {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.25))
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView()
}
