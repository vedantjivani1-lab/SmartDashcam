import SwiftUI
import AVFoundation
import Combine

struct ContentView: View {
    @StateObject private var recorder = CameraRecorder()
    @StateObject private var locationTracker = LocationTracker()
    @ObservedObject private var settings = SettingsStore.shared
    @ObservedObject private var emergencyContact = EmergencyContactStore.shared
    @State private var crashDetector: CrashDetector?
    @State private var cameraAuthorized = false
    @State private var isCrashSaved = false
    @State private var feedbackMessage: String?
    @State private var showClipList = false
    @State private var showSettings = false
    @State private var showEmergencyMessage = false
    @State private var emergencyMessageBody = ""
    @State private var lastInteraction = Date()
    @State private var isDimmed = false
    @State private var savedBrightness: CGFloat?
    @State private var isSaving = false
    @State private var recDotVisible = true
    @State private var dimClockText = ""
    @State private var hasStarted = false
    @Environment(\.scenePhase) private var scenePhase

    // Two-tier crash response: anything from 5.5g up gets the clip saved;
    // only 7g and above also triggers the emergency contact message.
    private let emergencyMessageThresholdG: Double = 7.0

    private let dimCheckTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let recBlinkTimer = Timer.publish(every: 0.9, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if cameraAuthorized {
                CameraPreviewView(session: recorder.session)
                    .ignoresSafeArea()
            } else {
                permissionPrompt
            }

            // Gradient scrims top and bottom so white controls stay
            // legible over bright footage — a plain icon against a pale
            // sky washes out completely otherwise.
            VStack {
                LinearGradient(
                    colors: [.black.opacity(0.5), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 150)
                Spacer()
                LinearGradient(
                    colors: [.clear, .black.opacity(0.45)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 190)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack {
                topBar
                Spacer()
                bottomBar
            }

            if isDimmed {
                dimOverlay
            }

            if let feedbackMessage {
                feedbackPill(feedbackMessage)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { registerInteraction() }
        .gesture(DragGesture(minimumDistance: 0).onChanged { _ in registerInteraction() })
        .onAppear(perform: requestPermissionsAndStart)
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            restoreBrightnessIfNeeded()
        }
        .onChange(of: feedbackMessage) { _, newValue in
            guard newValue != nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                withAnimation(.easeOut(duration: 0.3)) { feedbackMessage = nil }
            }
        }
        .onReceive(recBlinkTimer) { _ in
            withAnimation(.easeInOut(duration: 0.4)) {
                recDotVisible.toggle()
            }
        }
        .sheet(isPresented: $showClipList) {
            ClipListView(activeSegmentURL: recorder.activeSegmentURL)
        }
        .sheet(isPresented: $showSettings, onDismiss: {
            registerInteraction()
            if cameraAuthorized {
                recorder.stop {
                    recorder.configureAndStart()
                }
            }
        }) {
            SettingsView()
        }
        .sheet(isPresented: $showEmergencyMessage) {
            if EmergencyMessageComposer.canSendText() {
                EmergencyMessageComposer(
                    recipientPhone: emergencyContact.contactPhone,
                    messageBody: emergencyMessageBody
                ) {
                    showEmergencyMessage = false
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                recorder.stop()
                restoreBrightnessIfNeeded()
            case .active:
                registerInteraction()
                if cameraAuthorized && hasStarted
                    && !recorder.isRecording && !recorder.isPausedByUser {
                    recorder.configureAndStart()
                }
            default:
                break
            }
        }
        .onReceive(dimCheckTimer) { _ in
            checkAutoDim()
            if isDimmed {
                updateDimClock()
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                statusBadge
                Spacer()
                glassIconButton("gearshape") {
                    registerInteraction()
                    showSettings = true
                }
                glassIconButton("film.stack") {
                    registerInteraction()
                    showClipList = true
                }
                saveClipButton
            }

            if let error = recorder.lastError {
                errorPill(error)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    /// Doubles as the pause/resume control — the badge already shows
    /// recording state, so making it tappable keeps the controls compact
    /// rather than adding another button to a crowded bar.
    private var statusBadge: some View {
        Button {
            registerInteraction()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            recorder.togglePause()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                feedbackMessage = recorder.isPausedByUser
                    ? "Recording resumed."
                    : "Recording paused. Tap the badge to resume."
            }
        } label: {
            HStack(spacing: 7) {
                if recorder.isPausedByUser {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                } else {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .opacity(recDotVisible ? 1 : 0.25)
                }

                Text(badgeText)
                    .font(.system(size: 12, weight: .bold))
                    .kerning(1.2)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(badgeFill)
                    .overlay(
                        Capsule().stroke(badgeStroke, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.3), value: recorder.isPausedByUser)
        .animation(.easeInOut(duration: 0.3), value: isCrashSaved)
    }

    private var badgeText: String {
        if recorder.isPausedByUser { return "PAUSED" }
        return isCrashSaved ? "CRASH SAVED" : "REC"
    }

    private var badgeFill: Color {
        if recorder.isPausedByUser { return Color.white.opacity(0.14) }
        return Color.red.opacity(isCrashSaved ? 0.55 : 0.28)
    }

    private var badgeStroke: Color {
        recorder.isPausedByUser
            ? Color.white.opacity(0.25)
            : Color.red.opacity(0.6)
    }

    private func glassIconButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 42, height: 42)
                .background(Circle().fill(.ultraThinMaterial))
                .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
        }
    }

    private var saveClipButton: some View {
        Button {
            registerInteraction()
            saveClipNow()
        } label: {
            Text(isSaving ? "Saving…" : "Save Clip")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .frame(height: 42)
                .background(
                    Capsule()
                        .fill(Color.red.opacity(saveButtonDisabled ? 0.35 : 0.92))
                )
                .shadow(color: .red.opacity(saveButtonDisabled ? 0 : 0.3), radius: 8, y: 3)
        }
        .disabled(saveButtonDisabled)
        .animation(.easeOut(duration: 0.2), value: saveButtonDisabled)
    }

    private var saveButtonDisabled: Bool {
        isSaving || recorder.isPausedByUser
    }

    private func errorPill(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(2)
        }
        .foregroundColor(.orange)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.orange.opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.orange.opacity(0.35), lineWidth: 1)
                )
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(alignment: .bottom) {
            SpeedometerView(speedKmh: locationTracker.current?.speedKmh ?? 0)
                .animation(.easeInOut(duration: 0.25), value: settings.speedometerStyle)
            Spacer()
            gpsChip
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }

    private var gpsChip: some View {
        HStack(spacing: 7) {
            Image(systemName: locationTracker.current == nil ? "location.slash" : "location.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(locationTracker.current == nil ? .white.opacity(0.4) : .white.opacity(0.7))

            if let loc = locationTracker.current {
                Text(String(format: "%.5f, %.5f", loc.lat, loc.lon))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
            } else {
                Text("Searching…")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.55))
                .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
        )
    }

    // MARK: - Overlays

    private var permissionPrompt: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.metering.unknown")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(.white.opacity(0.4))
            Text("Camera access needed")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
            Text("Grant permission in Settings to start recording.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private var dimOverlay: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // A glance at the dimmed screen should still confirm the app
            // is doing its job, so show the essentials faintly rather
            // than leaving it completely blank.
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    if recorder.isPausedByUser {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.28))
                    } else {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 7, height: 7)
                            .opacity(recDotVisible ? 0.9 : 0.2)
                    }

                    Text(recorder.isPausedByUser ? "PAUSED" : "RECORDING")
                        .font(.system(size: 10, weight: .semibold))
                        .kerning(2)
                        .foregroundColor(.white.opacity(0.28))
                }

                Text(dimClockText)
                    .font(.system(size: 34, weight: .thin, design: .monospaced))
                    .foregroundColor(.white.opacity(0.16))

                Text("Tap to wake")
                    .font(.system(size: 10))
                    .kerning(0.5)
                    .foregroundColor(.white.opacity(0.12))
                    .padding(.top, 6)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { registerInteraction() }
        .transition(.opacity)
    }

    private func feedbackPill(_ message: String) -> some View {
        VStack {
            Text(message)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                )
                .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
                .padding(.top, 70)
            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .zIndex(1)
        .allowsHitTesting(false)
    }

    // MARK: - Auto-dim

    private func registerInteraction() {
        lastInteraction = Date()
        if isDimmed {
            restoreBrightnessIfNeeded()
            withAnimation(.easeOut(duration: 0.3)) {
                isDimmed = false
            }
        }
    }

    private func checkAutoDim() {
        guard let threshold = settings.screenDim.seconds,
              cameraAuthorized,
              !isDimmed,
              !showClipList,
              !showSettings
        else { return }

        if Date().timeIntervalSince(lastInteraction) >= threshold {
            if savedBrightness == nil {
                savedBrightness = UIScreen.main.brightness
            }
            UIScreen.main.brightness = 0.02
            updateDimClock()
            withAnimation(.easeIn(duration: 0.6)) {
                isDimmed = true
            }
        }
    }

    private func updateDimClock() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        dimClockText = formatter.string(from: Date())
    }

    private func restoreBrightnessIfNeeded() {
        if let saved = savedBrightness {
            UIScreen.main.brightness = saved
            savedBrightness = nil
        }
    }

    private func saveClipNow() {
        guard !isSaving else { return }
        isSaving = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        recorder.saveCurrentSegmentNow { url, reason in
            isSaving = false
            guard let url else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    feedbackMessage = reason ?? "Couldn't save right now — try again in a moment."
                }
                return
            }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                if ClipStorage.shared.protectClip(url) != nil {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    feedbackMessage = "Clip saved to My Clips."
                } else {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    feedbackMessage = "Couldn't save that clip — it may have already been moved or deleted."
                }
            }
        }
    }

    private func requestPermissionsAndStart() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                cameraAuthorized = granted
                startIfAllowed()
            }
        }
    }

    /// Starts recording once camera permission is granted (only once).
    private func startIfAllowed() {
        guard cameraAuthorized, !hasStarted else { return }
        hasStarted = true
        startEverything()
    }

    private func startEverything() {
        // Clear out any zero-length stubs left behind by earlier builds
        // before the recorder started rejecting them at write time.
        ClipStorage.shared.purgeUnplayableClips()

        UIApplication.shared.isIdleTimerDisabled = true
        lastInteraction = Date()

        recorder.onSegmentFinished = { _ in
            withAnimation { isCrashSaved = false }
        }
        recorder.configureAndStart()

        locationTracker.onUpdate = { loc in
            TelemetryProvider.shared.update(speedKmh: loc.speedKmh, lat: loc.lat, lon: loc.lon)
        }
        locationTracker.requestPermission()
        locationTracker.start()

        crashDetector = CrashDetector { magnitudeG in
            // Deliberately paused means the user has chosen not to
            // record — a crash shouldn't override that decision and
            // start capturing footage they asked not to have taken.
            guard !recorder.isPausedByUser else { return }

            // A crash is the one moment worth a distinctly heavier
            // haptic than anything else in the app.
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

            registerInteraction() // wake the screen if a crash happens while dimmed
            withAnimation { isCrashSaved = true }

            recorder.saveCurrentSegmentNow { url, _ in
                guard let url, ClipStorage.shared.protectClip(url) != nil else {
                    withAnimation {
                        feedbackMessage = String(format: "Crash detected (%.1fg) — couldn't save a clip right now.", magnitudeG)
                    }
                    return
                }

                CloudBackupManager.shared.uploadProtectedClips()

                if magnitudeG >= emergencyMessageThresholdG,
                   emergencyContact.isConfigured,
                   EmergencyMessageComposer.canSendText() {
                    let loc = locationTracker.current
                    let locationLine = loc != nil
                        ? "https://maps.apple.com/?ll=\(loc!.lat),\(loc!.lon)"
                        : "location unavailable"
                    emergencyMessageBody = "Possible car accident detected (\(String(format: "%.1f", magnitudeG))g impact). My last known location: \(locationLine)"
                    showEmergencyMessage = true
                } else {
                    withAnimation {
                        feedbackMessage = String(format: "Crash detected (%.1fg) — clip saved to My Clips.", magnitudeG)
                    }
                }
            }
        }
        crashDetector?.start()
    }
}

#Preview {
    ContentView()
}
