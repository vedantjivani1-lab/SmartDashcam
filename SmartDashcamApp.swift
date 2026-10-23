import SwiftUI

@main
struct SmartDashcamApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var splashFinished = false
    @ObservedObject private var auth = AuthManager.shared
    @ObservedObject private var legalStore = LegalAcceptanceStore.shared

    var body: some Scene {
        WindowGroup {
            ZStack {
                if auth.isSignedIn {
                    // Signed in already — now check the legal gate.
                    if auth.displayName.isEmpty {
                        NameEntryView()
                    } else if legalStore.hasAcceptedCurrentVersion {
                        ContentView()
                    } else {
                        LegalDisclaimerView { }
                    }
                } else if splashFinished {
                    // Not signed in yet — phone screen comes first.
                    PhoneAuthView()
                }

                if !splashFinished {
                    SplashView(isFinished: $splashFinished)
                        .transition(
                            .opacity.combined(with: .scale(scale: 1.06))
                        )
                        .zIndex(1)
                }
            }
            .preferredColorScheme(.dark)
            .persistentSystemOverlays(.hidden)
        }
    }
}
