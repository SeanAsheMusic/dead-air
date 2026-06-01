import Foundation

public enum AudioFormatSupport {
    public static let supportedExtensions: Set<String> = [
        "wav", "wave", "aif", "aiff", "caf", "mp3", "m4a", "mp4", "aac", "alac", "flac"
    ]

    public static func isSupportedAudioURL(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }
}
