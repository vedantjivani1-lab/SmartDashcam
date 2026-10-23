import Foundation
import Combine
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

/// Handles phone number + SMS one-time-code sign-in.
///
/// Mirrors CloudBackupManager's pattern: if the Firebase Auth SDK isn't
/// added to the project yet, this falls back to a local mock flow so the
/// UI and navigation can be built and tested before Firebase is wired
/// up. In mock mode, the "code" that's always accepted is
/// `AuthManager.mockOTP` — nothing is actually sent by SMS.
///
/// Requires (once you're ready to go live):
///  1. Phone sign-in enabled in the Firebase console (Authentication →
///     Sign-in method → Phone)
///  2. The FirebaseAuth product added via Swift Package Manager
///  3. APNs (or a reCAPTCHA fallback) wired up — see AppDelegate.swift,
///     since Firebase needs a way to silently verify the device
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isSignedIn: Bool
    @Published var isSendingCode = false
    @Published var isVerifying = false
    @Published var errorMessage: String?
    /// The user's display name. Kept on-device and, when Firebase is
    /// present, on their account profile so it follows them across phones.
    @Published var displayName: String = UserDefaults.standard.string(forKey: "dashcam.userName") ?? ""

    /// Only relevant in mock mode (no Firebase Auth SDK present) —
    /// this is the one code the mock flow accepts.
    static let mockOTP = "123456"

    #if canImport(FirebaseAuth)
    private var verificationID: String?
    #endif

    #if canImport(FirebaseAuth)
    /// Turns Firebase's technical errors into plain language.
    private static func friendly(_ error: Error) -> String {
        let ns = error as NSError
        switch AuthErrorCode.Code(rawValue: ns.code) {
        case .invalidPhoneNumber, .missingPhoneNumber:
            return "That phone number doesn't look right. Check the country code and number."
        case .tooManyRequests:
            return "Too many attempts. Please wait a while and try again."
        case .invalidVerificationCode:
            return "Incorrect code. Please try again."
        case .sessionExpired, .invalidVerificationID:
            return "That code has expired. Please request a new one."
        case .quotaExceeded:
            return "We can't send codes right now. Please try again later."
        case .networkError:
            return "No internet connection. Please try again."
        default:
            return "Something went wrong. Please try again."
        }
    }
    #endif

    private init() {
        #if canImport(FirebaseAuth)
        isSignedIn = Auth.auth().currentUser != nil
        #elseif DEBUG
        isSignedIn = UserDefaults.standard.bool(forKey: "dashcam.mockSignedIn")
        #else
        isSignedIn = false
        #endif
    }

    /// Sends a one-time code to `phoneNumber`, which must be in E.164
    /// format (e.g. "+15551234567") — combining a country code with the
    /// digits the user typed is the UI's job, not this manager's.
    func sendCode(to phoneNumber: String, completion: @escaping (Bool) -> Void) {
        errorMessage = nil
        isSendingCode = true

        #if canImport(FirebaseAuth)
        PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil) { [weak self] verificationID, error in
            DispatchQueue.main.async {
                self?.isSendingCode = false
                if let error {
                    self?.errorMessage = Self.friendly(error)
                    completion(false)
                    return
                }
                self?.verificationID = verificationID
                completion(true)
            }
        }
        #elseif DEBUG
        // Debug-only simulation so the UI can be developed without Firebase.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.isSendingCode = false
            completion(true)
        }
        #else
        isSendingCode = false
        errorMessage = "Sign-in is temporarily unavailable. Please try again later."
        completion(false)
        #endif
    }

    /// Verifies the 6-digit code the user typed in and signs them in on success.
    func verifyCode(_ code: String, completion: @escaping (Bool) -> Void) {
        errorMessage = nil
        isVerifying = true

        #if canImport(FirebaseAuth)
        guard let verificationID else {
            isVerifying = false
            errorMessage = "Something went wrong — request a new code."
            completion(false)
            return
        }
        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: code
        )
        Auth.auth().signIn(with: credential) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isVerifying = false
                if let error {
                    self?.errorMessage = Self.friendly(error)
                    completion(false)
                    return
                }
                if let name = result?.user.displayName, !name.isEmpty {
                    self?.displayName = name
                    UserDefaults.standard.set(name, forKey: "dashcam.userName")
                }
                self?.isSignedIn = true
                completion(true)
            }
        }
        #elseif DEBUG
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.isVerifying = false
            guard code == Self.mockOTP else {
                self?.errorMessage = "Incorrect code. Please try again."
                completion(false)
                return
            }
            UserDefaults.standard.set(true, forKey: "dashcam.mockSignedIn")
            self?.isSignedIn = true
            completion(true)
        }
        #else
        isVerifying = false
        errorMessage = "Sign-in is temporarily unavailable. Please try again later."
        completion(false)
        #endif
    }

    /// Saves the user's name locally and to their account profile.
    func saveName(_ name: String) {
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(50))
        guard !trimmed.isEmpty else { return }
        displayName = trimmed
        UserDefaults.standard.set(trimmed, forKey: "dashcam.userName")
        #if canImport(FirebaseAuth)
        let request = Auth.auth().currentUser?.createProfileChangeRequest()
        request?.displayName = trimmed
        request?.commitChanges { _ in }
        #endif
    }

    func signOut() {
        #if canImport(FirebaseAuth)
        try? Auth.auth().signOut()
        #endif
        displayName = ""
        UserDefaults.standard.removeObject(forKey: "dashcam.userName")
        UserDefaults.standard.set(false, forKey: "dashcam.mockSignedIn")
        isSignedIn = false
    }

    // MARK: - Account deletion

    enum DeleteResult {
        case success
        /// Firebase requires a recent login to delete — user must sign in again.
        case needsRecentLogin
        case failure(String)
    }

    @Published var isDeleting = false

    /// Permanently deletes the account and all data tied to it: cloud
    /// backups, the auth user, and everything stored locally.
    func deleteAccount(completion: @escaping (DeleteResult) -> Void) {
        isDeleting = true

        let finishLocal: () -> Void = { [weak self] in
            LocalDataWiper.wipeAll()
            UserDefaults.standard.set(false, forKey: "dashcam.mockSignedIn")
            self?.isDeleting = false
            self?.isSignedIn = false
            completion(.success)
        }

        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else {
            finishLocal()
            return
        }
        CloudBackupManager.shared.deleteAllBackups { [weak self] in
            user.delete { error in
                DispatchQueue.main.async {
                    if let error = error as NSError? {
                        self?.isDeleting = false
                        if error.code == AuthErrorCode.Code.requiresRecentLogin.rawValue {
                            completion(.needsRecentLogin)
                        } else {
                            completion(.failure("We couldn't delete your account. Please try again."))
                        }
                        return
                    }
                    finishLocal()
                }
            }
        }
        #else
        finishLocal()
        #endif
    }
}

/// Removes every piece of user data stored on this device.
enum LocalDataWiper {
    static func wipeAll() {
        let fm = FileManager.default
        if let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first,
           let items = try? fm.contentsOfDirectory(at: docs, includingPropertiesForKeys: nil) {
            for item in items { try? fm.removeItem(at: item) }
        }
        if let id = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: id)
        }
        UserDefaults.standard.synchronize()
        EmergencyContactStore.shared.contactName = ""
        EmergencyContactStore.shared.contactPhone = ""
    }
}
