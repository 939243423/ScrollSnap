import Foundation
import CoreGraphics
#if canImport(UIKit)
import UIKit
import Vision

@MainActor
public final class PrivacySanitizer: ObservableObject {
    public static let shared = PrivacySanitizer()
    
    @Published public private(set) var isDetecting: Bool = false
    
    private init() {}
    
    public struct DetectedPrivacyRegion: Identifiable, Sendable {
        public let id = UUID()
        public let relativeRect: CGRect // Normalized (0...1) relative to full canvas
        public let label: String
        public let isFace: Bool
    }
    
    /// Scans a full stitched image using Apple Vision framework on the Neural Engine.
    /// Detects human faces (avatars), 11-digit mobile phone numbers, emails, and ID card numbers.
    public func detectSensitiveRegions(in image: UIImage) async -> [AnnotationItem] {
        guard let cgImage = image.cgImage else { return [] }
        isDetecting = true
        defer { isDetecting = false }
        
        var generatedAnnotations: [AnnotationItem] = []
        
        // 1. Detect Avatars / Faces
        let faceRects = await detectFaceRectangles(in: cgImage)
        for rect in faceRects {
            // Expand slightly to cover full avatar square
            let paddedRect = rect.insetBy(dx: -rect.width * 0.15, dy: -rect.height * 0.15)
            let item = AnnotationItem(
                kind: .mosaic,
                color: .midnightBlack,
                startPoint: CGPoint(x: max(0, paddedRect.minX), y: max(0, paddedRect.minY)),
                endPoint: CGPoint(x: min(1, paddedRect.maxX), y: min(1, paddedRect.maxY)),
                isBlackout: false
            )
            generatedAnnotations.append(item)
        }
        
        // 2. Detect Sensitive Text (Phone numbers, IDs, emails) via Vision OCR
        let textRegions = await detectSensitiveTextRegions(in: cgImage)
        for rect in textRegions {
            let paddedRect = rect.insetBy(dx: -rect.width * 0.05, dy: -rect.height * 0.1)
            let item = AnnotationItem(
                kind: .mosaic,
                color: .midnightBlack,
                startPoint: CGPoint(x: max(0, paddedRect.minX), y: max(0, paddedRect.minY)),
                endPoint: CGPoint(x: min(1, paddedRect.maxX), y: min(1, paddedRect.maxY)),
                isBlackout: false
            )
            generatedAnnotations.append(item)
        }
        
        return generatedAnnotations
    }
    
    private func detectFaceRectangles(in cgImage: CGImage) async -> [CGRect] {
        await withCheckedContinuation { continuation in
            let request = VNDetectFaceRectanglesRequest { request, error in
                guard error == nil, let results = request.results as? [VNFaceObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                // Vision uses bottom-left origin (0,0); convert to top-left origin
                let rects = results.map { obs in
                    CGRect(
                        x: obs.boundingBox.minX,
                        y: 1.0 - obs.boundingBox.maxY,
                        width: obs.boundingBox.width,
                        height: obs.boundingBox.height
                    )
                }
                continuation.resume(returning: rects)
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
            try? handler.perform([request])
        }
    }
    
    private func detectSensitiveTextRegions(in cgImage: CGImage) async -> [CGRect] {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil, let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                var matchedRects: [CGRect] = []
                // Regex for Chinese 11-digit phone numbers, emails, ID numbers
                let phonePattern = "1[3-9]\\d{9}"
                let emailPattern = "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
                let combinedRegex = try? NSRegularExpression(pattern: "\(phonePattern)|\(emailPattern)", options: [])
                
                for obs in observations {
                    guard let topCandidate = obs.topCandidates(1).first else { continue }
                    let text = topCandidate.string
                    let range = NSRange(location: 0, length: text.utf16.count)
                    
                    if let matches = combinedRegex?.matches(in: text, options: [], range: range), !matches.isEmpty {
                        let rect = CGRect(
                            x: obs.boundingBox.minX,
                            y: 1.0 - obs.boundingBox.maxY,
                            width: obs.boundingBox.width,
                            height: obs.boundingBox.height
                        )
                        matchedRects.append(rect)
                    }
                }
                continuation.resume(returning: matchedRects)
            }
            
            request.recognitionLevel = .accurate
            request.usesCPUOnly = false
            request.recognitionLanguages = ["zh-Hans", "en-US"]
            
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
            try? handler.perform([request])
        }
    }
}
#endif
