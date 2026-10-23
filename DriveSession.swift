import Foundation


struct DriveSession: Identifiable {
    let clips: [DashcamClip]

    var id: String {
        clips.map(\.id).min() ?? "empty-session"
    }

    static let sessionGapThreshold: TimeInterval = 10 * 60

    var startedAt: Date { clips.map(\.modifiedAt).min() ?? Date() }
    var endedAt: Date { clips.map(\.modifiedAt).max() ?? Date() }

    var totalBytes: Int64 {
        clips.reduce(0) { $0 + $1.sizeBytes }
    }

    var totalDurationSeconds: Double {
        clips.compactMap(\.durationSeconds).reduce(0, +)
    }

    var savedCount: Int {
        clips.filter(\.isProtected).count
    }

    var sizeText: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }

    var durationText: String {
        let total = Int(totalDurationSeconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes)m \(seconds)s" }
        return "\(seconds)s"
    }


    var titleText: String {
        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        let dayLabel: String
        if calendar.isDateInToday(startedAt) {
            dayLabel = "Today"
        } else if calendar.isDateInYesterday(startedAt) {
            dayLabel = "Yesterday"
        } else {
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "d MMM"
            dayLabel = dayFormatter.string(from: startedAt)
        }

        let start = timeFormatter.string(from: startedAt)
        let end = timeFormatter.string(from: endedAt)
        return start == end
            ? "\(dayLabel), \(start)"
            : "\(dayLabel), \(start) – \(end)"
    }

    static func group(_ clips: [DashcamClip]) -> [DriveSession] {
        guard !clips.isEmpty else { return [] }


        let ordered = clips.sorted { $0.modifiedAt < $1.modifiedAt }

        var sessions: [DriveSession] = []
        var current: [DashcamClip] = [ordered[0]]

        for clip in ordered.dropFirst() {
            guard let previous = current.last else { continue }

        
            let previousEnd = previous.modifiedAt
                .addingTimeInterval(previous.durationSeconds ?? 0)
            let gap = clip.modifiedAt.timeIntervalSince(previousEnd)

            if gap > sessionGapThreshold {
                sessions.append(DriveSession(clips: current.reversed()))
                current = [clip]
            } else {
                current.append(clip)
            }
        }

        sessions.append(DriveSession(clips: current.reversed()))
        return sessions.reversed()
    }
}


