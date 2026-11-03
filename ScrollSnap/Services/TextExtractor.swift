import Foundation
import CoreGraphics
#if canImport(UIKit)
import UIKit
import Vision

@MainActor
public final class TextExtractor: ObservableObject {
    public static let shared = TextExtractor()
    
    @Published public private(set) var isExtracting: Bool = false
    @Published public private(set) var lastExtractedText: String = ""
    
    public struct RecognizedTextBlock: Identifiable, Sendable {
        public let id = UUID()
        public let text: String
        public let relativeRect: CGRect // Normalized (0...1)
        public let confidence: Float
    }
    
    private init() {}
    
    /// Extracts all text in reading order from top to bottom
    public func extractFullText(from image: UIImage) async -> (plainText: String, blocks: [RecognizedTextBlock]) {
        guard let cgImage = image.cgImage else { return ("", []) }
        isExtracting = true
        defer { isExtracting = false }
        
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil, let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: ("", []))
                    return
                }
                
                var blocks: [RecognizedTextBlock] = []
                for obs in observations {
                    guard let topCandidate = obs.topCandidates(1).first else { continue }
                    let rect = CGRect(
                        x: obs.boundingBox.minX,
                        y: 1.0 - obs.boundingBox.maxY,
                        width: obs.boundingBox.width,
                        height: obs.boundingBox.height
                    )
                    blocks.append(RecognizedTextBlock(
                        text: topCandidate.string,
                        relativeRect: rect,
                        confidence: topCandidate.confidence
                    ))
                }
                
                // Sort top to bottom in chronological reading order
                blocks.sort(by: { $0.relativeRect.minY < $1.relativeRect.minY })
                let combinedText = blocks.map { $0.text }.joined(separator: "\n")
                
                continuation.resume(returning: (combinedText, blocks))
            }
            
            request.recognitionLevel = .accurate
            request.usesCPUOnly = false
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
            
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: ("", []))
            }
        }
    }
}
#endif
