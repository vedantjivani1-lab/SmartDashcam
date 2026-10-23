import Foundation
#if canImport(FirebaseStorage)
import FirebaseStorage
import UIKit
#endif

final class CloudBackupManager {

    static let shared = CloudBackupManager()

    func uploadProtectedClips() {
        let clips = ClipStorage.shared.protectedClips()
        guard !clips.isEmpty else { return }

        #if canImport(FirebaseStorage)
        let storage = Storage.storage()
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown-device"

        for clip in clips {
            let ref = storage.reference()
                .child("dashcam_backups")
                .child(deviceId)
                .child(clip.lastPathComponent)

            ref.putFile(from: clip, metadata: nil) { _, error in
                if error == nil {
                    try? FileManager.default.removeItem(at: clip)
                }
            }
        }
        #else
        print("CloudBackupManager: Firebase not configured, \(clips.count) clip(s) left in protected/")
        #endif
    }

    func deleteAllBackups(completion: @escaping () -> Void) {
        #if canImport(FirebaseStorage)
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown-device"
        let folder = Storage.storage().reference().child("dashcam_backups").child(deviceId)
        folder.listAll { result, _ in
            let items = result?.items ?? []
            guard !items.isEmpty else { completion(); return }
            let group = DispatchGroup()
            for item in items {
                group.enter()
                item.delete { _ in group.leave() }
            }
            group.notify(queue: .main) { completion() }
        }
        #else
        completion()
        #endif
    }
}
