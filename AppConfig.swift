import Foundation

/// Single place for values that must match App Store Connect.
enum AppConfig {
    static let appName = "Focus"

    /// Hosted legal pages — these exact URLs must also be entered in
    /// App Store Connect (Privacy Policy URL) and be live before review.
    static let privacyPolicyURL = URL(string: "https://genzdigitalpl.site/privacy")!
    static let termsURL = URL(string: "https://genzdigitalpl.site/terms")!
    static let supportEmail = "genzdigitalprivatelimited@gmail.com"

}
