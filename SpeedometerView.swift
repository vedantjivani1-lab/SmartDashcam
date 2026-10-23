import SwiftUI
import Combine

struct SpeedometerView: View {
    var speedKmh: Double
    var maxSpeed: Double = 180

    @ObservedObject private var settings = SettingsStore.shared

    @State private var displayedSpeed: Double = 0
    @State private var recordingDotVisible = true

    private let dotTimer = Timer.publish(every: 0.9, on: .main, in: .common).autoconnect()

    private var clamped: Double { min(max(displayedSpeed, 0), maxSpeed) }
    private var fraction: Double { clamped / maxSpeed }
    private var displayNumber: String { "\(Int(clamped.rounded()))" }

    var body: some View {
        Group {
            switch settings.speedometerStyle {
            case .pill:    pillStyle
            case .numeral: numeralStyle
            case .arc:     arcStyle
            case .ring:    ringStyle
            case .bar:     barStyle
            }
        }
        .onChange(of: speedKmh) { _, newValue in
            withAnimation(.easeOut(duration: 0.4)) {
                displayedSpeed = min(max(newValue, 0), maxSpeed)
            }
        }
        .onAppear {
            displayedSpeed = min(max(speedKmh, 0), maxSpeed)
        }
        .onReceive(dotTimer) { _ in
            withAnimation(.easeInOut(duration: 0.35)) {
                recordingDotVisible.toggle()
            }
        }
    }
    private var pillStyle: some View {
        HStack(spacing: 10) {
            Text(displayNumber)
          
                .font(.system(size: 40, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                .frame(minWidth: 72, alignment: .trailing)

            Text("km/h")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.55))

            Circle()
                .fill(Color.red)
                .frame(width: 9, height: 9)
                .opacity(recordingDotVisible ? 1 : 0.25)
                .padding(.leading, 2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
        .background(glassContainer)
    }

    private var numeralStyle: some View {
        VStack(spacing: 2) {
            Text(displayNumber)
                .font(.system(size: 62, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 6, y: 2)

            Rectangle()
                .fill(Color.white.opacity(0.25))
                .frame(width: 62, height: 1)

            Text("km/h")
                .font(.system(size: 12, weight: .medium))
                .kerning(1.5)
                .foregroundColor(.white.opacity(0.6))
                .padding(.top, 3)
        }
    }

    private var arcStyle: some View {
        ZStack {

            Circle()
                .trim(from: 0, to: 0.5)
                .stroke(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(180))

            Circle()
                .trim(from: 0, to: 0.5 * fraction)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(180))

            VStack(spacing: 0) {
                Text(displayNumber)
                    .font(.system(size: 34, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                Text("km/h")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.55))
            }
            .offset(y: 12)
        }
        .frame(width: 140, height: 140)
       
        .padding(.bottom, -58)
    }

    private var ringStyle: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.5))

            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 6)

            Circle()
                .trim(from: 0, to: fraction)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text(displayNumber)
                    .font(.system(size: 30, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                Text("km/h")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.55))
            }
        }
        .frame(width: 108, height: 108)
        .overlay(
            Circle().stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var barStyle: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(displayNumber)
                    .font(.system(size: 42, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                Text("km/h")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.55))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                    Capsule()
                        .fill(Color.white)
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 5)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(width: 190)
        .background(glassContainer)
    }

    private var glassContainer: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.black.opacity(0.55))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
    }
}

#Preview {
    SpeedometerView(speedKmh: 62)
        .padding()
        .background(Color.black)
}

