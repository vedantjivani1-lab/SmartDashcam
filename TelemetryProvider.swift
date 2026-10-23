import Foundation

final class TelemetryProvider {
    static let shared = TelemetryProvider()

    private let lock = NSLock()// i go p
    private var _speedKmh: Double = 0
    private var _lat: Double = 0
    private var _lon: Double = 0
    private var _hasFix: Bool = false

    func update(speedKmh: Double, lat: Double, lon: Double) {
        lock.lock()
        _speedKmh = speedKmh
        _lat = lat
        _lon = lon
        _hasFix = true
        lock.unlock()
    }

    func snapshot() -> (speedKmh: Double, lat: Double, lon: Double, hasFix: Bool) {
        lock.lock()
        defer { lock.unlock() }
        return (_speedKmh, _lat, _lon, _hasFix)
    }
}
///p
///hello ha apad kemm ene kemm sudhi 2027 sudhi etlu lambu toh nai 
