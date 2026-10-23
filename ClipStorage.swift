import Foundation


final class ClipStorage {

    static let shared = ClipStorage()

    let loopDir: URL
    let protectedDir: URL

   
    var maxLoopBytes: Int64 {
        SettingsStore.shared.storageLimit.bytes
    }


    private let minimumUsableBytes: Int64 = 200_000

    private let fm = FileManager.default
    private let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
 
        f.dateFormat = "yyyyMMdd_HHmmss_SSS"
        return f
    }()

    private init() {
        let documents = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let root = documents.appendingPathComponent("SmartDashcam", isDirectory: true)
        loopDir = root.appendingPathComponent("loop", isDirectory: true)
        protectedDir = root.appendingPathComponent("protected", isDirectory: true)

        try? fm.createDirectory(at: loopDir, withIntermediateDirectories: true)
        try? fm.createDirectory(at: protectedDir, withIntermediateDirectories: true)
    }

    func newSegmentURL() -> URL {
        var name = "CLIP_\(timestampFormatter.string(from: Date())).mov"
        var url = loopDir.appendingPathComponent(name)
        while fm.fileExists(atPath: url.path) {
            name = "CLIP_\(timestampFormatter.string(from: Date()))_\(Int.random(in: 100...999)).mov"
            url = loopDir.appendingPathComponent(name)
        }
        return url
    }

  
    func enforceLoopLimit() {
        guard let files = try? fm.contentsOfDirectory(
            at: loopDir, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
        ) else { return }

        let sorted = files
            .filter { $0.pathExtension == "mov" }
            .sorted { a, b in
                let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                return da < db
            }

        var totalSize: Int64 = sorted.reduce(0) { sum, url in
            sum + Int64((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
        }

        let cap = maxLoopBytes
        for url in sorted {
            if totalSize <= cap { break }
            let size = Int64((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
            if (try? fm.removeItem(at: url)) != nil {
                totalSize -= size
            }
        }
    }


    func purgeUnplayableClips() {
        for directory in [loopDir, protectedDir] {
            guard let files = try? fm.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: [.fileSizeKey]
            ) else { continue }

            for file in files where file.pathExtension == "mov" {
                if fileSize(for: file) < minimumUsableBytes {
                    try? fm.removeItem(at: file)
                }
            }
        }
    }

    @discardableResult
    func protectClip(_ clip: URL) -> URL? {
        guard fm.fileExists(atPath: clip.path) else { return nil }
        let dest = protectedDir.appendingPathComponent(clip.lastPathComponent)

        if fm.fileExists(atPath: dest.path) {
            return dest
        }

        do {
            try fm.copyItem(at: clip, to: dest)
            return dest
        } catch {
            return nil
        }
    }

    func protectedClips() -> [URL] {
        let files = (try? fm.contentsOfDirectory(at: protectedDir, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "mov" }
    }

    func loopClips() -> [URL] {
        let files = (try? fm.contentsOfDirectory(
            at: loopDir, includingPropertiesForKeys: [.contentModificationDateKey]
        )) ?? []
        return files
            .filter { $0.pathExtension == "mov" }
            .sorted { a, b in
                let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                return da > db
            }
    }

    @discardableResult
    func deleteClip(_ url: URL) -> Bool {
        (try? fm.removeItem(at: url)) != nil
    }

    func modificationDate(for url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
    }

    func fileSize(for url: URL) -> Int64 {
        Int64((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
    }


   
    func loopBytesUsed() -> Int64 {
        loopClips().reduce(0) { $0 + fileSize(for: $1) }
    }

    func protectedBytesUsed() -> Int64 {
        protectedClips().reduce(0) { $0 + fileSize(for: $1) }
    }

   
    func deviceFreeBytes() -> Int64? {
        guard let values = try? loopDir.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
              let available = values.volumeAvailableCapacityForImportantUsage else { return nil }
        return Int64(available)
    }


    func estimatedRemainingHours() -> Double? {
        let bitsPerSecond = Double(SettingsStore.shared.quality.bitrate)
        guard bitsPerSecond > 0 else { return nil }

        let freeBytes = Double(maxLoopBytes - loopBytesUsed())
        guard freeBytes > 0 else { return 0 }

        return freeBytes / (bitsPerSecond / 8) / 3600
    }


    func capacityHours(for limit: StorageLimitOption) -> Double? {
        let bitsPerSecond = Double(SettingsStore.shared.quality.bitrate)
        guard bitsPerSecond > 0 else { return nil }
        return Double(limit.bytes) / (bitsPerSecond / 8) / 3600
    }

    func totalCapacityHours() -> Double? {
        capacityHours(for: SettingsStore.shared.storageLimit)
    }
}

