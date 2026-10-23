import SwiftUI
import Combine

struct PhoneAuthView: View {
    @ObservedObject private var auth = AuthManager.shared
 
    @State private var countryCode = "+91"
    @State private var digits = ""
    @State private var otpDigits = ["", "", "", "", "", ""]
    @State private var stage: Stage = .enterPhone
    @FocusState private var phoneFieldFocused: Bool
    @FocusState private var otpFieldFocused: Bool
 

    @State private var contentVisible = false
    @State private var glowOpacity: Double = 0
    @State private var shakeTrigger: CGFloat = 0
    @State private var verifiedPulse = false
 

    @State private var resendCountdown = 30
    private let countdownTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
 
    private enum Stage {
        case enterPhone
        case enterCode
    }
 
    private var fullPhoneNumber: String {
        let code = countryCode.hasPrefix("+") ? countryCode : "+\(countryCode)"
        return code + digits.filter(\.isNumber)
    }
 
    private var otpCode: String {
        otpDigits.joined()
    }
 
    var body: some View {
        ZStack {
            background
 
            VStack(spacing: 28) {
                logo
 
                Group {
                    switch stage {
                    case .enterPhone:
                        phoneEntry
                    case .enterCode:
                        codeEntry
                    }
                }
                .id(stage)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    )
                )
 
                Spacer()
            }
            .padding(.horizontal, 26)
            .padding(.top, 40)
            .opacity(contentVisible ? 1 : 0)
            .offset(y: contentVisible ? 0 : 12)
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.35), value: stage)
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) { glowOpacity = 1 }
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) { contentVisible = true }
        }
        .onReceive(countdownTimer) { _ in
            if stage == .enterCode && resendCountdown > 0 {
                resendCountdown -= 1
            }
        }
    }
 
  
 
    private var background: some View {
        ZStack {
            Color(red: 0.043, green: 0.071, blue: 0.125).ignoresSafeArea() // matches SplashView
 
            RadialGradient(
                colors: [
                    Color(red: 0.22, green: 0.45, blue: 0.85).opacity(0.26),
                    .clear
                ],
                center: .top,
                startRadius: 20,
                endRadius: 340
            )
            .opacity(glowOpacity)
            .ignoresSafeArea()
        }
    }
 
    private var logo: some View {
        Image("SplashLogo")
            .resizable()
            .scaledToFit()
            .frame(width: 56, height: 56)
            .shadow(color: .accentColor.opacity(0.35), radius: 12)
    }
 

 
    private var phoneEntry: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Verify Your Number")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                Text("We'll text you a one-time code to confirm it's really you.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
            }
 
            HStack(spacing: 0) {
                TextField("+91", text: $countryCode)
                    .frame(width: 52)
                    .keyboardType(.phonePad)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .font(.system(size: 17, weight: .semibold))
 
                Rectangle()
                    .fill(.white.opacity(0.15))
                    .frame(width: 1, height: 22)
                    .padding(.horizontal, 10)
 
                TextField("Phone number", text: $digits)
                    .keyboardType(.numberPad)
                    .foregroundStyle(.white)
                    .font(.system(size: 17, weight: .medium))
                    .focused($phoneFieldFocused)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        phoneFieldFocused ? Color.accentColor.opacity(0.7) : .white.opacity(0.12),
                        lineWidth: phoneFieldFocused ? 1.5 : 1
                    )
            )
            .animation(.easeOut(duration: 0.2), value: phoneFieldFocused)
            .modifier(ShakeEffect(shakes: shakeTrigger))
 
            if let error = auth.errorMessage {
                errorText(error)
            }
 
            primaryButton(
                title: "Send Code",
                isLoading: auth.isSendingCode,
                isEnabled: canSendCode,
                action: requestCode
            )
        }
        .onAppear { phoneFieldFocused = true }
    }
 
    private var canSendCode: Bool {
        digits.filter(\.isNumber).count >= 7 && !auth.isSendingCode
    }
 
    private func requestCode() {
        auth.sendCode(to: fullPhoneNumber) { success in
            if success {
                otpDigits = ["", "", "", "", "", ""]
                resendCountdown = 30
                stage = .enterCode
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    otpFieldFocused = true
                }
            } else {
                triggerShake()
            }
        }
    }
 

 
    private var codeEntry: some View {
        VStack(spacing: 22) {
            VStack(spacing: 8) {
                Text("Enter the Code")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                Text("Sent to \(fullPhoneNumber)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
            }
 
            otpBoxes
                .modifier(ShakeEffect(shakes: shakeTrigger))
 
            if let error = auth.errorMessage {
                errorText(error)
            }
 
            primaryButton(
                title: "Verify",
                isLoading: auth.isVerifying,
                isEnabled: otpCode.count == 6 && !auth.isVerifying,
                showsCheckmark: verifiedPulse,
                action: verify
            )
 
            HStack(spacing: 6) {
                Button("Change number") {
                    stage = .enterPhone
                    auth.errorMessage = nil
                }
                Text("·").foregroundStyle(.white.opacity(0.3))
                resendControl
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(.white.opacity(0.6))
        }
    }
 
  
    private var otpBoxes: some View {
        ZStack {
            TextField("", text: Binding(
                get: { otpCode },
                set: { newValue in
                    let filtered = String(newValue.filter(\.isNumber).prefix(6))
                    otpDigits = (0..<6).map { i in
                        i < filtered.count ? String(Array(filtered)[i]) : ""
                    }
                    if filtered.count == 6 {
                        verify()
                    }
                }
            ))
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .focused($otpFieldFocused)
            .opacity(0.01) // invisible but still the real input target
            .frame(height: 1)
 
            HStack(spacing: 10) {
                ForEach(0..<6, id: \.self) { index in
                    digitBox(otpDigits[index], isActive: index == otpCode.count && otpFieldFocused)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { otpFieldFocused = true }
    }
 
    private func digitBox(_ digit: String, isActive: Bool) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(.white.opacity(digit.isEmpty ? 0.06 : 0.1))
            .frame(width: 44, height: 54)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        isActive ? Color.accentColor.opacity(0.8) : .white.opacity(0.15),
                        lineWidth: isActive ? 1.5 : 1
                    )
            )
            .overlay(
                Text(digit)
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
            )
            .scaleEffect(digit.isEmpty ? 1 : 1.04)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: digit)
    }
 
    @ViewBuilder
    private var resendControl: some View {
        if resendCountdown > 0 {
            Text("Resend in \(resendCountdown)s")
        } else {
            Button(action: {
                resendCountdown = 30
                requestCode()
            }) {
                Text("Resend code")
            }
            .foregroundStyle(Color.accentColor)
        }
    }
 
    private func verify() {
        auth.verifyCode(otpCode) { success in
            if success {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    verifiedPulse = true
                }
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                triggerShake()
            }
        }
    }
 

 
    private func primaryButton(
        title: String,
        isLoading: Bool,
        isEnabled: Bool,
        showsCheckmark: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            ZStack {
                if showsCheckmark {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                } else if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(title).font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                Capsule().fill(isEnabled || showsCheckmark ? Color.accentColor : Color.white.opacity(0.12))
            )
            .foregroundStyle(.white)
        }
        .disabled(!isEnabled)
        .animation(.easeOut(duration: 0.2), value: isEnabled)
    }
 
    private func errorText(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.red.opacity(0.9))
            .multilineTextAlignment(.center)
            .transition(.opacity)
    }
 
    private func triggerShake() {
        withAnimation(.default) {
            shakeTrigger += 1
        }
    }
}
 
private struct ShakeEffect: ViewModifier {
    var shakes: CGFloat
 
    func body(content: Content) -> some View {
        content.modifier(_ShakeGeometry(animatableData: shakes))
    }
}
 
private struct _ShakeGeometry: GeometryEffect {
    var animatableData: CGFloat
 
    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = 8 * sin(animatableData * .pi * 6)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}
 
#Preview {
    PhoneAuthView()
}
 
