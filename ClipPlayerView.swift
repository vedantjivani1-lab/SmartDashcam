import SwiftUI
import AVKit
import Combine
import Photos

struct ClipPlayerView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    @State private var zoomLevel: CGFloat = 1.0
    @State private var playbackSpeed: Float = 1.0
    @State private var showControls = false
    @State private var showPlateReader = false
    @State private var saveMessage: String?
    /// Kept up to date by a periodic observer on the player, so the plate
    /// reader opens on the frame the user is actually looking at rather
    /// than always the start of the clip.
    @State private var currentPlaybackTime: Double = 0

    private let zoomOptions: [CGFloat] = [1.0, 1.25, 1.5, 2.0]
    private let speedOptions: [Float] = [1.0, 1.25, 1.5, 2.0]

    var body: some View {
        ZStack(alignment: .bottom) {
            FullScreenPlayer(
                url: url,
                playbackSpeed: playbackSpeed,
                currentTime: $currentPlaybackTime
            )
            .scaleEffect(zoomLevel)
            .ignoresSafeArea()

            // Soft gradient behind the top controls so white icons stay
            // legible over bright footage — a plain icon on a pale sky
            // washes out completely otherwise. 90%
            VStack {
                LinearGradient(
                    colors: [.black.opacity(0.55), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 130)
                .allowsHitTesting(false)
                Spacer()
            }
            .ignoresSafeArea()

            VStack {
                // All custom controls sit on the RIGHT. AVPlayerViewController
                // puts its own close button and playback chrome on the left,
                // so anything placed there collides with Apple's UI.
                HStack(spacing: 12) {
                    Spacer()

                    glassIconButton("square.and.arrow.down") {
                        saveToPhotos()
                    }

                    ShareLink(item: url) {
                        glassIcon("square.and.arrow.up")
                    }

                    glassIconButton("text.viewfinder") {
                        showPlateReader = true
                    }

                    glassIconButton("slider.horizontal.3", isActive: showControls) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                            showControls.toggle()
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)

                Spacer()
            }

            if let saveMessage {
                VStack {
                    Text(saveMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(.ultraThinMaterial))
                        .padding(.top, 70)
                    Spacer()
                }
                .transition(.opacity)
                .allowsHitTesting(false)
            }

            if showControls {
                controlPanel
                    .transition(
                        .move(edge: .bottom)
                        .combined(with: .opacity)
                    )
            }
        }
        .background(Color.black)
        .statusBarHidden()
        .onChange(of: zoomLevel) { _, _ in hideControlsAfterDelay() }
        .onChange(of: playbackSpeed) { _, _ in hideControlsAfterDelay() }
        .sheet(isPresented: $showPlateReader) {
            PlateReaderView(clipURL: url, startTime: currentPlaybackTime)
        }
    }

    /// Copies the clip into the user's Photos library so they own it
    /// regardless of what happens to the app.
    private func saveToPhotos() {
        // Without this Info.plist string iOS terminates the app on the
        // permission request, so fail gracefully instead.
        guard Bundle.main.object(forInfoDictionaryKey: "NSPhotoLibraryAddUsageDescription") != nil else {
            show("Photos permission text is missing in the app's Info settings.")
            return
        }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                show("Photos access is off. Enable it in iOS Settings → Focus.")
                return
            }
            PHPhotoLibrary.shared().performChanges({
                _ = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }) { success, _ in
                show(success ? "Saved to Photos." : "Couldn't save this clip.")
            }
        }
    }

    private func show(_ text: String) {
        DispatchQueue.main.async {
            withAnimation { saveMessage = text }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation { saveMessage = nil }
            }
        }
    }

    private func glassIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 17, weight: .medium))
            .foregroundColor(.white)
            .frame(width: 42, height: 42)
            .background(Circle().fill(.ultraThinMaterial))
            .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
            .shadow(color: .black.opacity(0.25), radius: 8, y: 2)
    }

    private func glassIconButton(
        _ systemName: String,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(isActive ? .black : .white)
                .frame(width: 42, height: 42)
                .background(
                    Circle()
                        .fill(isActive ? AnyShapeStyle(Color.white) : AnyShapeStyle(.ultraThinMaterial))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isActive ? 0 : 0.18), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var controlPanel: some View {
        VStack(spacing: 18) {
            presetRow(title: "ZOOM", options: zoomOptions, selection: $zoomLevel)

            Divider()
                .overlay(Color.white.opacity(0.12))

            presetRow(title: "SPEED", options: speedOptions, selection: $playbackSpeed)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.35), radius: 20, y: 8)
        .padding(.horizontal, 16)
        .padding(.bottom, 100) // clears AVPlayerViewController's own scrubber
    }

    private func presetRow<T: Hashable>(
        title: String,
        options: [T],
        selection: Binding<T>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .kerning(1.4)
                .foregroundColor(.white.opacity(0.5))

            HStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    let isSelected = selection.wrappedValue == option
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selection.wrappedValue = option
                        }
                    } label: {
                        Text(labelText(for: option))
                            .font(.system(
                                size: 15,
                                weight: isSelected ? .semibold : .regular,
                                design: .rounded
                            ))
                            .foregroundColor(isSelected ? .black : .white.opacity(0.85))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color.white : Color.white.opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// Gives a brief moment to see which option got selected, then
    /// auto-hides the panel so it doesn't sit over the video.
    private func hideControlsAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                showControls = false
            }
        }
    }

    private func labelText<T: Hashable>(for value: T) -> String {
        let doubleValue: Double
        if let v = value as? CGFloat { doubleValue = Double(v) }
        else if let v = value as? Float { doubleValue = Double(v) }
        else { return "\(value)" }

        if doubleValue == doubleValue.rounded() {
            return "\(Int(doubleValue))×"
        }
        return String(format: "%.2g×", doubleValue)
    }
}

/// Wraps AVPlayerViewController with .resizeAspectFill so dashcam footage
/// fills the entire screen edge-to-edge instead of being letterboxed.
/// Zoom is applied as a SwiftUI scaleEffect on this wrapper. Playback
/// speed maps to AVPlayer's `rate` — only applied while actively playing,
/// so selecting a speed while paused doesn't unexpectedly start playback.
///
/// Also reports the current playback position back up via a binding, so
/// the plate reader can pull the exact frame being viewed.
private struct FullScreenPlayer: UIViewControllerRepresentable {
    let url: URL
    var playbackSpeed: Float
    @Binding var currentTime: Double

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        let player = AVPlayer(url: url)
        controller.player = player
        controller.videoGravity = .resizeAspectFill
        controller.showsPlaybackControls = true
        player.play()
        player.rate = playbackSpeed

        context.coordinator.attachTimeObserver(to: player)
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        guard let player = uiViewController.player else { return }
        if player.timeControlStatus == .playing {
            player.rate = playbackSpeed
        }
    }

    static func dismantleUIViewController(
        _ uiViewController: AVPlayerViewController,
        coordinator: Coordinator
    ) {
        coordinator.detachTimeObserver(from: uiViewController.player)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(currentTime: $currentTime)
    }

    final class Coordinator {
        private let currentTime: Binding<Double>
        private var timeObserver: Any?

        init(currentTime: Binding<Double>) {
            self.currentTime = currentTime
        }

        func attachTimeObserver(to player: AVPlayer) {
            let interval = CMTime(seconds: 0.2, preferredTimescale: 600)
            timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
                self?.currentTime.wrappedValue = time.seconds
            }
        }

        func detachTimeObserver(from player: AVPlayer?) {
            if let timeObserver, let player {
                player.removeTimeObserver(timeObserver)
            }
            timeObserver = nil
        }

        deinit {
            timeObserver = nil
        }
    }
}
