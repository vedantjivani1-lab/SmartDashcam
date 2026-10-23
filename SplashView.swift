import SwiftUI

struct SplashView: View {
    
    @Binding var isFinished: Bool


    @State private var logoScale: CGFloat = 0.7
    @State private var logoOpacity: Double = 0
    @State private var logoBlur: CGFloat = 14


    @State private var sweepOffset: CGFloat = -260


    @State private var ruleWidth: CGFloat = 0


    @State private var revealedLetters: Int = 0


    @State private var glowOpacity: Double = 0
    @State private var glowScale: CGFloat = 0.6


    @State private var contentOpacity: Double = 1
    @State private var contentScale: CGFloat = 1

    private let tagline = Array("Witness and Evidence")
    private let holdDuration: Double = 3.4

    var body: some View {
        ZStack {
            Color(red: 0.043, green: 0.071, blue: 0.125)
                .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color(red: 0.22, green: 0.45, blue: 0.85).opacity(0.28),
                    .clear
                ],
                center: .center,
                startRadius: 10,
                endRadius: 300
            )
            .scaleEffect(glowScale)
            .opacity(glowOpacity)
            .ignoresSafeArea()

            VStack(spacing: 38) {
                logoWithSweep

                VStack(spacing: 18) {
                    HStack(spacing: 12) {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .white.opacity(0.4)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: ruleWidth, height: 1)

                        Circle()
                            .fill(Color.white.opacity(0.5))
                            .frame(width: 3, height: 3)
                            .scaleEffect(ruleWidth > 0 ? 1 : 0)

                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.4), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: ruleWidth, height: 1)
                    }

                    letterByLetterTagline
                }
            }
           
            .opacity(contentOpacity)
            .scaleEffect(contentScale)
        }
        .onAppear(perform: runSequence)
    }

    private var logoWithSweep: some View {
        Image("SplashLogo")
            .resizable()
            .scaledToFit()
            .frame(width: 200, height: 200)
            .scaleEffect(logoScale)
            .opacity(logoOpacity)
            .blur(radius: logoBlur)
            .overlay(
            
                LinearGradient(
                    colors: [.clear, .white.opacity(0.75), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: 90)
                .rotationEffect(.degrees(22))
                .offset(x: sweepOffset)
                .mask(
                    Image("SplashLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                )
                .blendMode(.plusLighter)
            )
    }

    private var letterByLetterTagline: some View {
        HStack(spacing: 0) {
            ForEach(Array(tagline.enumerated()), id: \.offset) { index, character in
                Text(String(character))
                    .font(.system(size: 27, weight: .regular, design: .serif))
                    .kerning(1.2)
                    .foregroundColor(.white.opacity(0.88))
                    .opacity(index < revealedLetters ? 1 : 0)
                    .offset(y: index < revealedLetters ? 0 : 8)
                    .animation(
                        .easeOut(duration: 0.34),
                        value: revealedLetters
                    )
            }
        }
    }

    private func runSequence() {
  
        withAnimation(.easeOut(duration: 1.1)) {
            glowOpacity = 1
            glowScale = 1.0
        }


        withAnimation(.spring(response: 0.85, dampingFraction: 0.72)) {
            logoOpacity = 1
            logoScale = 1.0
        }
        withAnimation(.easeOut(duration: 0.7)) {
            logoBlur = 0
        }


        withAnimation(.easeInOut(duration: 1.0).delay(0.55)) {
            sweepOffset = 260
        }


        withAnimation(.easeOut(duration: 0.6).delay(0.95)) {
            ruleWidth = 40
        }


        for index in 0...tagline.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.15 + Double(index) * 0.034) {
                revealedLetters = index
            }
        }


        DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration - 0.35) {
            withAnimation(.easeIn(duration: 0.4)) {
                contentOpacity = 0
                contentScale = 1.04
            }
            withAnimation(.easeOut(duration: 0.5)) {
                glowOpacity = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration) {
            withAnimation(.easeInOut(duration: 0.6)) {
                isFinished = true
            }
        }
    }
}

#Preview {
    SplashView(isFinished: .constant(false))
}

