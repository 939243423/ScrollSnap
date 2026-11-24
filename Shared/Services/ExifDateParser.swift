import Foundation
import CoreGraphics
import ImageIO

/// High-performance metadata parser extracting embedded photo capture timestamps directly from image data bytes.
public enum ExifDateParser {
    
    private static let exifDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    private static let iso8601WithMillisFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    private static let simpleIso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    
    /// Extracts capture date from image data using CGImageSource metadata properties
    /// without decompressing or decoding pixel bitmaps into memory.
    public static func extractCaptureDate(from data: Data) -> Date? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return nil }
        
        // 1. Try Exif Dictionary (DateTimeOriginal or DateTimeDigitized)
        if let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            if let dateStr = exif[kCGImagePropertyExifDateTimeOriginal] as? String,
               let date = parseDateString(dateStr, subsec: exif[kCGImagePropertyExifSubsecTimeOriginal] as? String) {
                return date
            }
            if let dateStr = exif[kCGImagePropertyExifDateTimeDigitized] as? String,
               let date = parseDateString(dateStr, subsec: exif[kCGImagePropertyExifSubsecTimeDigitized] as? String) {
                return date
            }
        }
        
        // 2. Try TIFF Dictionary (DateTime)
        if let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            if let dateStr = tiff[kCGImagePropertyTIFFDateTime] as? String,
               let date = parseDateString(dateStr, subsec: nil) {
                return date
            }
        }
        
        return nil
    }
    
    /// Parses formatted date strings with optional sub-second fractions.
    public static func parseDateString(_ dateStr: String, subsec: String? = nil) -> Date? {
        var baseDate: Date?
        if let d = exifDateFormatter.date(from: dateStr) {
            baseDate = d
        } else if let d = iso8601WithMillisFormatter.date(from: dateStr) {
            baseDate = d
        } else if let d = simpleIso8601Formatter.date(from: dateStr) {
            baseDate = d
        }
        
        guard let date = baseDate else { return nil }
        
        if let subsec = subsec, let fraction = Double("0." + subsec) {
            return date.addingTimeInterval(fraction)
        }
        
        return date
    }
}
