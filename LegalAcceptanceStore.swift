import Foundation
import Combine

final class LegalAcceptanceStore: ObservableObject {
    static let shared = LegalAcceptanceStore()

    static let currentLegalVersion = 2

    @Published var acceptedVersion: Int {
        didSet {
            UserDefaults.standard.set(acceptedVersion, forKey: "dashcam.acceptedLegalVersion")
        }
    }

    var hasAcceptedCurrentVersion: Bool {
        acceptedVersion >= Self.currentLegalVersion
    }

    private init() {
        acceptedVersion = UserDefaults.standard.integer(forKey: "dashcam.acceptedLegalVersion")
    }

    func acceptCurrentVersion() {
        acceptedVersion = Self.currentLegalVersion
    }
}
