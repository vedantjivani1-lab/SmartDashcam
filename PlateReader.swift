@preconcurrency import Vision
import UIKit
import AVFoundation

struct PlateCandidate: Identifiable {
    let id = UUID()
    let text: String
    let confidence: Float

    let boundingBox: CGRect

    var confidencePercent: Int { Int(confidence * 100) }

  
    var reliability: String {
        switch confidence {
        case 0.9...: return "High confidence"
        case 0.6..<0.9: return "Medium — verify manually"
        default: return "Low — likely unreliable"
        }
    }
}

enum PlateReader {

   
    static func frame(from url: URL, at seconds: Double) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        return await withCheckedContinuation { continuation in
            generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, cgImage, _, _, _ in
                if let cgImage {
                    continuation.resume(returning: UIImage(cgImage: cgImage))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    static func readText(in image: UIImage) async -> [PlateCandidate] {
        guard let cgImage = image.cgImage else { return [] }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let candidates: [PlateCandidate] = observations.compactMap { observation in
                    guard let top = observation.topCandidates(1).first else { return nil }
                    let cleaned = top.string.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !cleaned.isEmpty else { return nil }
                    return PlateCandidate(
                        text: cleaned,
                        confidence: top.confidence,
                        boundingBox: observation.boundingBox
                    )
                }
                continuation.resume(returning: candidates.sorted { $0.confidence > $1.confidence })
            }

        
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.recognitionLanguages = ["en-IN", "en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: [])
                }
            }
        }
    }


    static func crop(_ image: UIImage, to rect: CGRect) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let scale = image.scale
        let scaled = CGRect(
            x: rect.origin.x * scale,
            y: rect.origin.y * scale,
            width: rect.size.width * scale,
            height: rect.size.height * scale
        )
        guard let cropped = cgImage.cropping(to: scaled) else { return nil }
        return UIImage(cgImage: cropped, scale: scale, orientation: image.imageOrientation)
    }
}
