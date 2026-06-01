import Foundation

public enum SupportPaths {
    public static let appFolderName = "Dead Air"

    public static func applicationSupportDirectory(fileManager: FileManager = .default) throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let url = base.appendingPathComponent(appFolderName, isDirectory: true)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    public static func bedsDirectory(fileManager: FileManager = .default) throws -> URL {
        let url = try applicationSupportDirectory(fileManager: fileManager)
            .appendingPathComponent("Beds", isDirectory: true)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    public static func playlistsDirectory(fileManager: FileManager = .default) throws -> URL {
        let url = try applicationSupportDirectory(fileManager: fileManager)
            .appendingPathComponent("Playlists", isDirectory: true)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    public static func logsDirectory(fileManager: FileManager = .default) throws -> URL {
        let url = try applicationSupportDirectory(fileManager: fileManager)
            .appendingPathComponent("Logs", isDirectory: true)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    public static func configURL(fileManager: FileManager = .default) throws -> URL {
        try applicationSupportDirectory(fileManager: fileManager).appendingPathComponent("config.json")
    }

    public static func manifestURL(fileManager: FileManager = .default) throws -> URL {
        try applicationSupportDirectory(fileManager: fileManager).appendingPathComponent("library.json")
    }
}
