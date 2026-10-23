import SwiftUI

struct LegalDisclaimerView: View {
    @ObservedObject private var legalStore = LegalAcceptanceStore.shared

    @State private var hasAgreed = false
    @State private var showingPrivacyPolicy = false
    @State private var showingTerms = false


    @State private var headerVisible = false
    @State private var revealedBulletCount = 0
    @State private var checkedBulletCount = 0
    @State private var controlsVisible = false
    @State private var glowOpacity: Double = 0
    @State private var continuePressed = false

    private struct Point {
        let icon: String
        let title: String
        let detail: String
        let tint: Color
    }

    private let points: [Point] = [
        Point(icon: "camera.fill", title: "Camera & GPS",
              detail: "Records the road and overlays your speed/location. No audio, just video.",
              tint: Color(red: 0.35, green: 0.65, blue: 1.0)),
        Point(icon: "exclamationmark.shield.fill", title: "Not a certified safety device",
              detail: "Crash detection can miss real crashes or false trigger — always call emergency services yourself if somethings actually wrong.",
              tint: Color(red: 1.0, green: 0.45, blue: 0.45)),
        Point(icon: "message.fill", title: "Emergency contact",
              detail: "If you set one up, a text gets pre-filled after a detected crash, but you still gotta hit send yourself.",
              tint: Color(red: 0.45, green: 0.85, blue: 0.7)),
        Point(icon: "text.viewfinder", title: "License plate reader",
              detail: "Runs on your device only, shows a confidence score. Don't use it to stalk or spy on people.",
              tint: Color(red: 0.75, green: 0.55, blue: 1.0)),
        Point(icon: "icloud.fill", title: "Cloud backup",
              detail: "Off unless you turn it on — if you do, crash clips upload to your cloud storage.",
              tint: Color(red: 1.0, green: 0.75, blue: 0.35))
    ]

    var onAccept: () -> Void

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                background

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        pointList
                        readLinks
                        Divider().overlay(.white.opacity(0.12)).padding(.vertical, 2)
                        agreementToggle
                        continueButton
                    }
                    .padding(20)
                    .padding(.top, 28)
                }

                progressBar
            }
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            LegalDocumentView(title: "Privacy Policy", bodyText: LegalDocumentText.privacyPolicy)
        }
        .sheet(isPresented: $showingTerms) {
            LegalDocumentView(title: "Terms of Service", bodyText: LegalDocumentText.termsOfService)
        }
        .interactiveDismissDisabled()
        .onAppear(perform: runEntranceSequence)
    }

   

    private var background: some View {
        ZStack {
            Color(red: 0.043, green: 0.071, blue: 0.125)
                .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color(red: 0.22, green: 0.45, blue: 0.85).opacity(0.22),
                    .clear
                ],
                center: .topLeading,
                startRadius: 20,
                endRadius: 420
            )
            .opacity(glowOpacity)
            .ignoresSafeArea()
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.35, green: 0.65, blue: 1.0), Color(red: 0.75, green: 0.55, blue: 1.0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(
                    width: geo.size.width * CGFloat(revealedBulletCount) / CGFloat(points.count),
                    height: 3
                )
                .animation(.easeOut(duration: 0.4), value: revealedBulletCount)
        }
        .frame(height: 3)
    }



    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Text("Before You Start")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
            }

            Text("Focus records video while you drive. Quick rundown before you jump in:")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
        }
        .opacity(headerVisible ? 1 : 0)
        .offset(y: headerVisible ? 0 : 10)
    }



    private var pointList: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                pointRow(point, isChecked: index < checkedBulletCount)
                    .opacity(index < revealedBulletCount ? 1 : 0)
                    .offset(x: index < revealedBulletCount ? 0 : -14)
            }
        }
    }

    private func pointRow(_ point: Point, isChecked: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    Circle()
                        .fill(point.tint.opacity(0.16))
                        .frame(width: 36, height: 36)
                    Image(systemName: point.icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(point.tint)
                }

                
                Circle()
                    .fill(Color.black)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(point.tint)
                    )
                    .scaleEffect(isChecked ? 1 : 0.01)
                    .opacity(isChecked ? 1 : 0)
                    .offset(x: 4, y: 4)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(point.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(point.detail)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(point.tint.opacity(0.05))
        )
    }

    // MARK: - Read links

    private var readLinks: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                showingPrivacyPolicy = true
            } label: {
                Label("Read the full Privacy Policy", systemImage: "doc.text")
                    .font(.subheadline.weight(.medium))
            }
            Button {
                showingTerms = true
            } label: {
                Label("Read the full Terms of Service", systemImage: "doc.text")
                    .font(.subheadline.weight(.medium))
            }
        }
        .tint(.white.opacity(0.85))
        .opacity(controlsVisible ? 1 : 0)
        .offset(y: controlsVisible ? 0 : 8)
    }

    // MARK: - Agreement + Continue

    private var agreementToggle: some View {
        Toggle(isOn: $hasAgreed.animation(.easeOut(duration: 0.2))) {
            Text("I read and agree to the Privacy Policy and Terms of Service.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
        }
        .toggleStyle(.switch)
        .tint(Color(red: 0.35, green: 0.65, blue: 1.0))
        .opacity(controlsVisible ? 1 : 0)
        .offset(y: controlsVisible ? 0 : 8)
    }

    private var continueButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            legalStore.acceptCurrentVersion()
            onAccept()
        } label: {
            Text("Continue")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    Capsule()
                        .fill(
                            hasAgreed
                                ? AnyShapeStyle(
                                    LinearGradient(
                                        colors: [Color(red: 0.35, green: 0.65, blue: 1.0), Color(red: 0.75, green: 0.55, blue: 1.0)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                  )
                                : AnyShapeStyle(Color.white.opacity(0.12))
                        )
                )
                .foregroundStyle(.white)
                .scaleEffect(continuePressed ? 0.97 : 1)
        }
        .disabled(!hasAgreed)
        .animation(.easeOut(duration: 0.2), value: hasAgreed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in continuePressed = true }
                .onEnded { _ in continuePressed = false }
        )
        .opacity(controlsVisible ? 1 : 0)
        .offset(y: controlsVisible ? 0 : 10)
        .padding(.top, 4)
    }

    // MARK: - Entrance sequence

    private func runEntranceSequence() {
        withAnimation(.easeOut(duration: 0.9)) {
            glowOpacity = 1
        }
        withAnimation(.easeOut(duration: 0.45)) {
            headerVisible = true
        }

        for index in 0..<points.count {
            let revealDelay = 0.35 + Double(index) * 0.14
            DispatchQueue.main.asyncAfter(deadline: .now() + revealDelay) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    revealedBulletCount = index + 1
                }
            }
           
            DispatchQueue.main.asyncAfter(deadline: .now() + revealDelay + 0.25) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                    checkedBulletCount = index + 1
                }
            }
        }

        let controlsDelay = 0.35 + Double(points.count) * 0.14 + 0.4
        DispatchQueue.main.asyncAfter(deadline: .now() + controlsDelay) {
            withAnimation(.easeOut(duration: 0.4)) {
                controlsVisible = true
            }
        }
    }
}

#Preview {
    LegalDisclaimerView(onAccept: {})
}

