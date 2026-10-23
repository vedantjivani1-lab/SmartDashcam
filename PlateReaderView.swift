import SwiftUI
struct PlateReaderView: View {
    let clipURL: URL
    let startTime: Double

    @Environment(\.dismiss) private var dismiss
    @State private var frameImage: UIImage?
    @State private var isLoading = true
    @State private var results: [PlateCandidate] = []
    @State private var isScanning = false
    @State private var hasScanned = false
    @State private var copiedID: UUID?


    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?
    @State private var displayedImageFrame: CGRect = .zero

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                imageArea
                controlsArea
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Read Plate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { await loadFrame() }
    }


    private var imageArea: some View {
        GeometryReader { geo in
            ZStack {
                Color.black

                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.white.opacity(0.5))
                        Text("Loading frame…")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.45))
                    }
                } else if let frameImage {
                    Image(uiImage: frameImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .background(
                         
                            GeometryReader { imageGeo in
                                Color.clear.onAppear {
                                    displayedImageFrame = imageGeo.frame(in: .named("imageArea"))
                                }
                            }
                        )
                        .overlay(selectionOverlay)
                        .gesture(
                            DragGesture(minimumDistance: 4)
                                .onChanged { value in
                                    if dragStart == nil { dragStart = value.startLocation }
                                    dragCurrent = value.location
                                }
                        )
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.system(size: 28, weight: .light))
                            .foregroundColor(.white.opacity(0.3))
                        Text("Couldn't load this frame.")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.45))
                    }
                }
            }
        }
        .coordinateSpace(name: "imageArea")
    }

    private var selectionOverlay: some View {
        GeometryReader { _ in
            if let rect = selectionRect {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.yellow.opacity(0.12))
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.yellow, lineWidth: 2)
                }
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
            }
        }
    }

    private var selectionRect: CGRect? {
        guard let start = dragStart, let current = dragCurrent else { return nil }
        return CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
    }


    private var controlsArea: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !hasScanned {
                HStack(spacing: 8) {
                    Image(systemName: "hand.draw")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                    Text("Drag a box around the plate, then tap Read. Selecting just the plate works far better than scanning the whole frame.")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.45))
                        .lineSpacing(2)
                }
            }

            HStack(spacing: 10) {
                actionButton(
                    title: isScanning ? "Reading…" : "Read Selection",
                    isPrimary: true,
                    isDisabled: isScanning || selectionRect == nil
                ) {
                    Task { await scan(useSelection: true) }
                }

                actionButton(
                    title: "Whole Frame",
                    isPrimary: false,
                    isDisabled: isScanning
                ) {
                    Task { await scan(useSelection: false) }
                }
            }

            if hasScanned {
                if results.isEmpty {
                    noResultsCard
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(results) { result in
                                resultRow(result)
                            }
                        }
                    }
                    .frame(maxHeight: 180)
                }
            }
        }
        .padding(18)
        .background(
            Color.white.opacity(0.04)
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1),
                    alignment: .top
                )
        )
    }

    private func actionButton(
        title: String,
        isPrimary: Bool,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isPrimary ? .black : .white.opacity(0.85))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(isPrimary
                              ? Color.white.opacity(isDisabled ? 0.3 : 1)
                              : Color.white.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    private var noResultsCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(.orange.opacity(0.8))

            Text("No readable text found. The plate is likely too small, too blurry, or at too steep an angle in this frame — try pausing at a different moment.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
                .lineSpacing(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.orange.opacity(0.22), lineWidth: 1)
                )
        )
    }

    private func resultRow(_ result: PlateCandidate) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(result.text)
                    .font(.system(size: 17, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .textSelection(.enabled)

                HStack(spacing: 6) {
                    Circle()
                        .fill(confidenceColor(result.confidence))
                        .frame(width: 5, height: 5)
                    Text("\(result.reliability) · \(result.confidencePercent)%")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            Spacer()

            Button {
                UIPasteboard.general.string = result.text
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.easeOut(duration: 0.15)) { copiedID = result.id }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                    withAnimation { if copiedID == result.id { copiedID = nil } }
                }
            } label: {
                Image(systemName: copiedID == result.id ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(copiedID == result.id ? .green : .white.opacity(0.7))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.white.opacity(0.09)))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.09), lineWidth: 1)
                )
        )
    }

    private func confidenceColor(_ confidence: Float) -> Color {
        switch confidence {
        case 0.9...: return .green
        case 0.6..<0.9: return .yellow
        default: return .orange
        }
    }



    private func loadFrame() async {
        frameImage = await PlateReader.frame(from: clipURL, at: startTime)
        isLoading = false
    }

    private func scan(useSelection: Bool) async {
        guard let frameImage else { return }
        isScanning = true
        results = []

        var target = frameImage
        if useSelection, let rect = selectionRect {
            if let cropped = mapAndCrop(frameImage, screenRect: rect) {
                target = cropped
            }
        }

        results = await PlateReader.readText(in: target)
        isScanning = false
        hasScanned = true

        UINotificationFeedbackGenerator().notificationOccurred(
            results.isEmpty ? .warning : .success
        )
    }

    private func mapAndCrop(_ image: UIImage, screenRect: CGRect) -> UIImage? {
        let displayedSize = displayedImageFrame.size
        guard displayedSize.width > 0, displayedSize.height > 0 else { return nil }

        let scaleX = image.size.width / displayedSize.width
        let scaleY = image.size.height / displayedSize.height

        let mapped = CGRect(
            x: screenRect.origin.x * scaleX,
            y: screenRect.origin.y * scaleY,
            width: screenRect.width * scaleX,
            height: screenRect.height * scaleY
        )
        let clamped = mapped.intersection(CGRect(origin: .zero, size: image.size))
        guard !clamped.isNull, clamped.width > 10, clamped.height > 10 else { return nil }
        return PlateReader.crop(image, to: clamped)
    }
}

/// famously the walls they are submerged the grat magest did you cover that again i didn't ak it's the actual porch skin 
