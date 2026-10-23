import Foundation
import AVFoundation
import UIKit


struct DashcamClip: Identifiable {
    let url: URL
    let isProtected: Bool
    let modifiedAt: Date
    let sizeBytes: Int64
    
    var durationSeconds: Double?

    var id: String { url.path }

    var displayName: String {
        url.deletingPathExtension().lastPathComponent
    }

    var sizeText: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }

    var durationText: String? {
        guard let durationSeconds, durationSeconds.isFinite, durationSeconds > 0 else { return nil }
        let total = Int(durationSeconds.rounded())
        let minutes = total / 60
        let seconds = total % 60
        return minutes > 0
            ? String(format: "%d:%02d", minutes, seconds)
            : String(format: "0:%02d", seconds)
    }

    var dateText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: modifiedAt)
    }

    static func load() -> (protected: [DashcamClip], loop: [DashcamClip]) {
        let storage = ClipStorage.shared


        let minimumUsableBytes: Int64 = 200_000

        func build(_ urls: [URL], isProtected: Bool) -> [DashcamClip] {
            urls.compactMap { url in
                let size = storage.fileSize(for: url)
                guard size >= minimumUsableBytes else { return nil }
                return DashcamClip(
                    url: url,
                    isProtected: isProtected,
                    modifiedAt: storage.modificationDate(for: url),
                    sizeBytes: size,
                    durationSeconds: nil
                )
            }
            .sorted { $0.modifiedAt > $1.modifiedAt }
        }

        return (
            build(storage.protectedClips(), isProtected: true),
            build(storage.loopClips(), isProtected: false)
        )
    }
}

enum ClipThumbnailGenerator {
    static func thumbnail(for url: URL) async -> UIImage? {
        await withTaskGroup(of: UIImage?.self) { group in
            group.addTask {
                await generate(for: url)
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                return nil
            }
            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }
    }

    private static func generate(for url: URL) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 400, height: 400)

        return await withCheckedContinuation { continuation in
            generator.generateCGImagesAsynchronously(
                forTimes: [NSValue(time: .init(seconds: 1.5, preferredTimescale: 600))]
            ) { _, cgImage, _, _, _ in
                if let cgImage {
                    continuation.resume(returning: UIImage(cgImage: cgImage))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }


    static func duration(for url: URL) async -> Double? {
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration) else { return nil }
        let seconds = duration.seconds
        guard seconds.isFinite, seconds > 0 else { return nil }
        return seconds
    }

    static func isPlayable(_ url: URL) async -> Bool {
        await duration(for: url) != nil
    }
}

