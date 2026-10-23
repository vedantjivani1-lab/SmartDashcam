import Foundation
import Combine

enum CameraZoomOption: String, CaseIterable, Identifiable {
    case ultraWide = "0.5x"
    case wide = "1x"
    var id: String { rawValue }
}

enum VideoQualityOption: String, CaseIterable, Identifiable {
    case hd720 = "720p"
    case hd1080 = "1080p"
    var id: String { rawValue }

    var width: Int { self == .hd1080 ? 1080 : 720 }
    var height: Int { self == .hd1080 ? 1920 : 1280 }

    var bitrate: Int { self == .hd1080 ? 16_000_000 : 8_000_000 }
}

enum StorageLimitOption: String, CaseIterable, Identifiable {
    case gb4 = "4 GB"
    case gb8 = "8 GB"
    case gb16 = "16 GB"
    case gb32 = "32 GB"
    var id: String { rawValue }

    var bytes: Int64 {
        switch self {
        case .gb4:  return 4 * 1024 * 1024 * 1024
        case .gb8:  return 8 * 1024 * 1024 * 1024
        case .gb16: return 16 * 1024 * 1024 * 1024
        case .gb32: return 32 * 1024 * 1024 * 1024
        }
    }
}

enum ScreenDimOption: String, CaseIterable, Identifiable {
    case off = "Off"
    case afterThirtySeconds = "30 sec"
    case afterOneMinute = "1 min"
    case afterThreeMinutes = "3 min"
    var id: String { rawValue }

    var seconds: TimeInterval? {
        switch self {
        case .off: return nil
        case .afterThirtySeconds: return 30
        case .afterOneMinute: return 60
        case .afterThreeMinutes: return 180
        }
    }
}

enum SpeedometerStyleOption: String, CaseIterable, Identifiable {
    case pill = "Pill"
    case numeral = "Numeral"
    case arc = "Arc"
    case ring = "Ring"
    case bar = "Bar"
    var id: String { rawValue }
}

/// the ferry is gonna be late chup reh tu pan no
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var zoom: CameraZoomOption {
        didSet { UserDefaults.standard.set(zoom.rawValue, forKey: "dashcam.zoom") }
    }
    @Published var quality: VideoQualityOption {
        didSet { UserDefaults.standard.set(quality.rawValue, forKey: "dashcam.quality") }
    }
    @Published var storageLimit: StorageLimitOption {
        didSet {
            UserDefaults.standard.set(storageLimit.rawValue, forKey: "dashcam.storageLimit")
       
            ClipStorage.shared.enforceLoopLimit()
        }
    }
    @Published var screenDim: ScreenDimOption {
        didSet { UserDefaults.standard.set(screenDim.rawValue, forKey: "dashcam.screenDim") }
    }
    @Published var speedometerStyle: SpeedometerStyleOption {
        didSet { UserDefaults.standard.set(speedometerStyle.rawValue, forKey: "dashcam.speedometerStyle") }
    }

    private init() {
        zoom = CameraZoomOption(rawValue: UserDefaults.standard.string(forKey: "dashcam.zoom") ?? "") ?? .wide
        quality = VideoQualityOption(rawValue: UserDefaults.standard.string(forKey: "dashcam.quality") ?? "") ?? .hd720
        storageLimit = StorageLimitOption(rawValue: UserDefaults.standard.string(forKey: "dashcam.storageLimit") ?? "") ?? .gb8
        screenDim = ScreenDimOption(rawValue: UserDefaults.standard.string(forKey: "dashcam.screenDim") ?? "") ?? .afterOneMinute
        speedometerStyle = SpeedometerStyleOption(rawValue: UserDefaults.standard.string(forKey: "dashcam.speedometerStyle") ?? "") ?? .pill
    }
}/// ia am 
