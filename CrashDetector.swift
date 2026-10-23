import CoreMotion
import Combine


final class CrashDetector: ObservableObject {

    private let motionManager = CMMotionManager()
    private let triggerThresholdG: Double
    private let onCrashDetected: (Double) -> Void

   private var lastTriggerAt: Date = .distantPast
    private let debounceInterval: TimeInterval = 15

    init(triggerThresholdG: Double = 5.5, onCrashDetected: @escaping (Double) -> Void) {
        self.triggerThresholdG = triggerThresholdG
        self.onCrashDetected = onCrashDetected
    }

    func start() {
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = 1.0 / 50.0 
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data = data else { return }
            let x = data.acceleration.x
            let y = data.acceleration.y
            let z = data.acceleration.z
            let magnitudeG = (x * x + y * y + z * z).squareRoot()

            if magnitudeG >= self.triggerThresholdG {
                let now = Date()
                if now.timeIntervalSince(self.lastTriggerAt) > self.debounceInterval {
                    self.lastTriggerAt = now
                    self.onCrashDetected(magnitudeG)
                }
            }
        }
    }

    func stop() {
        motionManager.stopAccelerometerUpdates()
    }
}
