import Foundation
import Combine


final class EmergencyContactStore: ObservableObject {
    static let shared = EmergencyContactStore()

    @Published var contactName: String {
        didSet { UserDefaults.standard.set(contactName, forKey: "dashcam.emergencyContactName") }
    }
    @Published var contactPhone: String {
        didSet { UserDefaults.standard.set(contactPhone, forKey: "dashcam.emergencyContactPhone") }
    }

    var isConfigured: Bool {
        !contactPhone.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private init() {
        contactName = UserDefaults.standard.string(forKey: "dashcam.emergencyContactName") ?? ""
        contactPhone = UserDefaults.standard.string(forKey: "dashcam.emergencyContactPhone") ?? ""
    }
}

