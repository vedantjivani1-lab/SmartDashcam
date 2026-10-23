import AVFoundation
import CoreImage
import UIKit
import Combine
final class CameraRecorder: NSObject, ObservableObject {

    @Published var isRecording = false
    @Published var lastError: String?
    @Published var lastCompletedSegmentURL: URL?// 

    @Published var activeSegmentURL: URL?
  
 
    @Published private(set) var isPausedByUser = false

    let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.smartdashcam.session")
    private let frameQueue = DispatchQueue(label: "com.smartdashcam.frames")
    private let ciContext = CIContext()

    private var assetWriter: AVAssetWriter?
    private var writerInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var currentSegmentURL: URL?
    private var running = false
    private var paused = false
    private var isFinishingSegment = false
    private var hasReceivedFrame = false

    private let segmentLength: TimeInterval = 5 * 60
    private var segmentTimer: Timer?

    
    private let minimumSegmentDuration: TimeInterval = 3.0
    private var segmentStartedAt: Date?

    
    private var frameWidth = 720
    private var frameHeight = 1280
    private var bitrate = 8_000_000

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    var onSegmentFinished: ((URL) -> Void)?

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleRuntimeError),
            name: AVCaptureSession.runtimeErrorNotification, object: session
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleInterruptionEnded),
            name: AVCaptureSession.interruptionEndedNotification, object: session
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func configureAndStart() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.configureSession()
            self.session.startRunning()
            self.frameQueue.async {
                self.running = true
                self.paused = false
                DispatchQueue.main.async { self.isPausedByUser = false }
                self.startNextSegment()
            }
        }
    }

  
    func pauseRecording() {
        frameQueue.async { [weak self] in
            guard let self = self, self.running, !self.paused else { return }
            self.paused = true

            DispatchQueue.main.async {
                self.isPausedByUser = true
                self.isRecording = false
                self.segmentTimer?.invalidate()
                self.segmentTimer = nil
            }

            self.finishCurrentSegment(nil)
        }
    }
/// told
    func resumeRecording() {
        frameQueue.async { [weak self] in
            guard let self = self, self.running, self.paused else { return }
            self.paused = false
            DispatchQueue.main.async { self.isPausedByUser = false }
            self.startNextSegment()
        }
    }

    func togglePause() {
        if isPausedByUser {
            resumeRecording()
        } else {
            pauseRecording()
        }
    }

  
    func stop(completion: (() -> Void)? = nil) {
        DispatchQueue.main.async { [weak self] in
            self?.segmentTimer?.invalidate()
            self?.segmentTimer = nil
            self?.isRecording = false
        }

        frameQueue.async { [weak self] in
            guard let self = self else {
                completion?()
                return
            }
            self.running = false
            self.finishCurrentSegment { [weak self] in
                guard let self = self else {
                    completion?()
                    return
                }
                self.sessionQueue.async {
                    if self.session.isRunning {
                        self.session.stopRunning()
                    }
                    DispatchQueue.main.async {
                        completion?()
                    }
                }
            }
        }
    }

   
    func saveCurrentSegmentNow(completion: @escaping (URL?, String?) -> Void) {
        frameQueue.async { [weak self] in
            guard let self = self, self.running else {
                DispatchQueue.main.async { completion(nil, "Recording isn't active right now.") }
                return
            }
            guard !self.paused else {
                DispatchQueue.main.async {
                    completion(nil, "Recording is paused — resume it to save a clip.")
                }
                return
            }
            guard self.hasReceivedFrame else {
                DispatchQueue.main.async {
                    completion(nil, "Camera is still starting up — try again in a second.")
                }
                return
            }

            let elapsed = self.segmentStartedAt.map { Date().timeIntervalSince($0) } ?? 0
            guard elapsed >= self.minimumSegmentDuration else {
                DispatchQueue.main.async {
                    completion(nil, "Just saved a clip — wait a moment before saving another.")
                }
                return
            }

            let urlBeingClosed = self.currentSegmentURL

            self.finishCurrentSegment { [weak self] in
                guard let self = self else {
                    DispatchQueue.main.async { completion(nil, "Something went wrong — try again.") }
                    return
                }
                if self.running && !self.paused {
                    self.startNextSegment()
                }
                DispatchQueue.main.async {
                    completion(urlBeingClosed, nil)
                }
            }
        }
    }

   

    private func configureSession() {
        let quality = SettingsStore.shared.quality
        frameWidth = quality.width
        frameHeight = quality.height
        bitrate = quality.bitrate

        session.beginConfiguration()
        session.sessionPreset = quality == .hd1080 ? .hd1920x1080 : .hd1280x720

        session.inputs.forEach { session.removeInput($0) }

        if let camera = selectCameraDevice(),
           let input = try? AVCaptureDeviceInput(device: camera),
           session.canAddInput(input) {
            session.addInput(input)
            configureFocus(for: camera)
        }

        if session.outputs.isEmpty {
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.setSampleBufferDelegate(self, queue: frameQueue)
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
            }
        }

        
        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        }

        session.commitConfiguration()
    }
//
    private func selectCameraDevice() -> AVCaptureDevice? {
        switch SettingsStore.shared.zoom {
        case .ultraWide:
            return AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        case .wide:
            return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        }
    }

 
    private func configureFocus(for device: AVCaptureDevice) {
        guard (try? device.lockForConfiguration()) != nil else { return }
        defer { device.unlockForConfiguration() }

        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        }
        if device.isAutoFocusRangeRestrictionSupported {
            device.autoFocusRangeRestriction = .far
        }
        if device.isSmoothAutoFocusSupported {
            device.isSmoothAutoFocusEnabled = false
        }
    }

   

    @objc private func handleRuntimeError(_ notification: Notification) {
        let errorText = (notification.userInfo?[AVCaptureSessionErrorKey] as? Error)?.localizedDescription
        DispatchQueue.main.async {
            self.lastError = "Camera error, recovering: \(errorText ?? "unknown")"
        }
        frameQueue.async { [weak self] in
            guard let self = self, self.running else { return }
            self.sessionQueue.async {
                self.session.startRunning()
            }
        }
    }

    @objc private func handleInterruptionEnded(_ notification: Notification) {
        frameQueue.async { [weak self] in
            guard let self = self, self.running else { return }
            self.sessionQueue.async {
                if !self.session.isRunning {
                    self.session.startRunning()
                }
            }
        }
    }

    

    private func startNextSegment() {
        guard running, !paused else { return }

        let outputURL = ClipStorage.shared.newSegmentURL()
        currentSegmentURL = outputURL
        DispatchQueue.main.async { self.activeSegmentURL = outputURL }

        guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .mov) else {
            DispatchQueue.main.async { self.lastError = "Could not create video file" }
            return
        }

        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: frameWidth,
            AVVideoHeightKey: frameHeight,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: bitrate]
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = true

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: frameWidth,
                kCVPixelBufferHeightKey as String: frameHeight
            ]
        )

        if writer.canAdd(input) {
            writer.add(input)
        }

        assetWriter = writer
        writerInput = input
        pixelBufferAdaptor = adaptor
        isFinishingSegment = false
        hasReceivedFrame = false
        segmentStartedAt = Date()

        DispatchQueue.main.async {
            self.isRecording = true
            self.lastError = nil
            self.segmentTimer?.invalidate()
            self.segmentTimer = Timer.scheduledTimer(withTimeInterval: self.segmentLength, repeats: false) { [weak self] _ in
                self?.frameQueue.async {
                    self?.finishCurrentSegment {
                        if self?.running == true && self?.paused == false {
                            self?.startNextSegment()
                        }
                    }
                }
            }
        }
    }

    private func finishCurrentSegment(_ completion: (() -> Void)? = nil) {
        guard !isFinishingSegment, let writer = assetWriter, let input = writerInput else {
            frameQueue.async { completion?() }
            return
        }
        isFinishingSegment = true
        let finishedURL = currentSegmentURL
        let startedAt = segmentStartedAt

    
        let elapsed = startedAt.map { Date().timeIntervalSince($0) } ?? 0
        let tooShort = elapsed < minimumSegmentDuration

        guard writer.status == .writing, !tooShort else {
            writer.cancelWriting()
            if let finishedURL {
                try? FileManager.default.removeItem(at: finishedURL)
            }
            cleanupWriter()
            frameQueue.async { completion?() }
            return
        }

        input.markAsFinished()

        writer.finishWriting { [weak self] in
            self?.frameQueue.async {
                guard let self = self else {
                    completion?()
                    return
                }

                let fileSize = finishedURL.flatMap { ClipStorage.shared.fileSize(for: $0) } ?? 0
                let isUsable = writer.status == .completed && fileSize > 200_000

                if let finishedURL = finishedURL, isUsable {
                    DispatchQueue.main.async {
                        self.lastCompletedSegmentURL = finishedURL
                        self.onSegmentFinished?(finishedURL)
                        ClipStorage.shared.enforceLoopLimit()
                    }
                } else {
                    if let error = writer.error {
                        DispatchQueue.main.async {
                            self.lastError = error.localizedDescription
                        }
                    }
                    if let finishedURL = finishedURL {
                        try? FileManager.default.removeItem(at: finishedURL)
                    }
                }

                self.cleanupWriter()
                completion?()
            }
        }
    }

    private func cleanupWriter() {
        assetWriter = nil
        writerInput = nil
        pixelBufferAdaptor = nil
        currentSegmentURL = nil
        segmentStartedAt = nil
        DispatchQueue.main.async { self.activeSegmentURL = nil }
    }
}



extension CameraRecorder: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        
        guard running,
              !paused,
              !isFinishingSegment,
              let input = writerInput,
              let writer = assetWriter,
              let adaptor = pixelBufferAdaptor,
              let sourceBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        else { return }

        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        if writer.status == .unknown {
            writer.startWriting()
            writer.startSession(atSourceTime: presentationTime)
        }

        guard writer.status == .writing, input.isReadyForMoreMediaData else { return }

        guard let pool = adaptor.pixelBufferPool else { return }

        var pixelBufferOut: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBufferOut)
        guard status == kCVReturnSuccess, let outputBuffer = pixelBufferOut else { return }

       
        let ciImage = CIImage(cvPixelBuffer: sourceBuffer)
        ciContext.render(ciImage, to: outputBuffer)

        burnTelemetry(into: outputBuffer)
        adaptor.append(outputBuffer, withPresentationTime: presentationTime)
        hasReceivedFrame = true
    }

    private func burnTelemetry(into pixelBuffer: CVPixelBuffer) {
        let telemetry = TelemetryProvider.shared.snapshot()

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return }

        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        UIGraphicsPushContext(context)

        let timeText = Self.dateFormatter.string(from: Date())
        let speedText = "\(Int(telemetry.speedKmh)) km/h"
        let gpsText = telemetry.hasFix
            ? String(format: "%.5f, %.5f", telemetry.lat, telemetry.lon)
            : "GPS: searching…"

        let fullText = "\(timeText)  ·  \(speedText)  ·  \(gpsText)"

       
        let fontSize = CGFloat(width) * 0.032

        var attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: fontSize),
            .foregroundColor: UIColor.white,
            .strokeColor: UIColor.black,
            .strokeWidth: -3.0
        ]
        var finalString = NSAttributedString(string: fullText, attributes: attributes)
        var finalSize = finalString.size()

        let padding = CGFloat(width) * 0.025
        let availableWidth = CGFloat(width) - (padding * 2)

        if finalSize.width > availableWidth {
            let shrinkFactor = availableWidth / finalSize.width
            attributes[.font] = UIFont.boldSystemFont(ofSize: fontSize * shrinkFactor * 0.98)
            finalString = NSAttributedString(string: fullText, attributes: attributes)
            finalSize = finalString.size()
        }

        let origin = CGPoint(x: padding, y: CGFloat(height) - finalSize.height - padding)
        finalString.draw(at: origin)

        UIGraphicsPopContext()
    }
}

