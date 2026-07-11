import Foundation

public final class PersistenceStore: @unchecked Sendable {
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    public private(set) var recoveryMessages: [String] = []

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    public func loadConfig() -> AppConfig {
        do {
            let url = try SupportPaths.configURL(fileManager: fileManager)
            guard fileManager.fileExists(atPath: url.path) else { return AppConfig() }
            let data = try Data(contentsOf: url)
            return try decoder.decode(AppConfig.self, from: data)
        } catch {
            quarantineConfig(reason: error.localizedDescription)
            return AppConfig()
        }
    }

    public func saveConfig(_ config: AppConfig) throws {
        let data = try encoder.encode(config)
        let url = try SupportPaths.configURL(fileManager: fileManager)
        try writeWithBackup(data, to: url)
    }

    public func loadManifest() -> LibraryManifest {
        do {
            let url = try SupportPaths.manifestURL(fileManager: fileManager)
            guard fileManager.fileExists(atPath: url.path) else { return LibraryManifest() }
            let data = try Data(contentsOf: url)
            return try decoder.decode(LibraryManifest.self, from: data)
        } catch {
            quarantineManifest(reason: error.localizedDescription)
            return LibraryManifest()
        }
    }

    public func loadDefaultManifest() -> LibraryManifest? {
        do {
            let url = try defaultManifestURL()
            guard fileManager.fileExists(atPath: url.path) else { return nil }
            let data = try Data(contentsOf: url)
            return try decoder.decode(LibraryManifest.self, from: data)
        } catch {
            recordRecovery("Default playlist could not be loaded and was ignored: \(error.localizedDescription)")
            return nil
        }
    }

    public func saveManifest(_ manifest: LibraryManifest) throws {
        let data = try encoder.encode(manifest)
        let url = try SupportPaths.manifestURL(fileManager: fileManager)
        try writeWithBackup(data, to: url)
    }

    public func saveDefaultManifest(_ manifest: LibraryManifest) throws {
        let data = try encoder.encode(manifest)
        let url = try defaultManifestURL()
        try writeWithBackup(data, to: url)
    }

    public func saveDefaultConfig(_ config: AppConfig) throws {
        let data = try encoder.encode(config)
        let url = try defaultConfigURL()
        try writeWithBackup(data, to: url)
    }

    public func loadDefaultConfig() -> AppConfig? {
        do {
            let url = try defaultConfigURL()
            guard fileManager.fileExists(atPath: url.path) else { return nil }
            let data = try Data(contentsOf: url)
            return try decoder.decode(AppConfig.self, from: data)
        } catch {
            recordRecovery("Default setup could not be loaded and was ignored: \(error.localizedDescription)")
            return nil
        }
    }

    public func exportPlaylist(_ manifest: LibraryManifest, to url: URL) throws {
        let data = try encoder.encode(manifest)
        try writeWithBackup(data, to: url)
    }

    public func importPlaylist(from url: URL) throws -> LibraryManifest {
        let data = try Data(contentsOf: url)
        return try decoder.decode(LibraryManifest.self, from: data)
    }

    public func saveNamedPlaylist(_ manifest: LibraryManifest, name: String) throws -> URL {
        let safeName = Self.safeFileName(name.isEmpty ? "Dead Air Playlist" : name)
        let url = try SupportPaths.playlistsDirectory(fileManager: fileManager)
            .appendingPathComponent("\(safeName).deadAirPlaylist.json")
        try exportPlaylist(manifest, to: url)
        return url
    }

    public func savedPlaylists() -> [URL] {
        do {
            let directory = try SupportPaths.playlistsDirectory(fileManager: fileManager)
            let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])
            return files
                .filter { $0.pathExtension == "json" }
                .sorted { lhs, rhs in
                    let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    return lhsDate > rhsDate
                }
        } catch {
            return []
        }
    }

    public func loadProfiles() -> [ShowProfile] {
        do {
            let url = try profilesURL()
            guard fileManager.fileExists(atPath: url.path) else { return [] }
            let data = try Data(contentsOf: url)
            return try decoder.decode(ShowProfileCollection.self, from: data).profiles
        } catch {
            quarantineProfiles(reason: error.localizedDescription)
            return []
        }
    }

    public func saveProfiles(_ profiles: [ShowProfile]) throws {
        let data = try encoder.encode(ShowProfileCollection(profiles: profiles))
        let url = try profilesURL()
        try writeWithBackup(data, to: url)
    }

    private func defaultManifestURL() throws -> URL {
        try SupportPaths.playlistsDirectory(fileManager: fileManager).appendingPathComponent("Default.deadAirPlaylist.json")
    }

    private func defaultConfigURL() throws -> URL {
        try SupportPaths.playlistsDirectory(fileManager: fileManager).appendingPathComponent("Default.deadAirConfig.json")
    }

    private func profilesURL() throws -> URL {
        try SupportPaths.applicationSupportDirectory(fileManager: fileManager).appendingPathComponent("ShowProfiles.json")
    }

    private func writeWithBackup(_ data: Data, to url: URL) throws {
        try backupExistingFile(at: url)
        try data.write(to: url, options: [.atomic])
    }

    private func backupExistingFile(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else { return }
        let backupURL = url.deletingLastPathComponent()
            .appendingPathComponent("\(url.lastPathComponent).backup-\(Self.timestamp())-\(UUID().uuidString.prefix(8))")
        try fileManager.copyItem(at: url, to: backupURL)
        pruneOldSiblings(of: url, marker: ".backup-", keeping: 10)
    }

    /// Keeps the most recent `limit` timestamped siblings for a given base
    /// file and marker, so `.backup-*` / `.corrupt-*` files can't accumulate
    /// without bound in Application Support. Best-effort; failures are ignored.
    private func pruneOldSiblings(of url: URL, marker: String, keeping limit: Int) {
        let directory = url.deletingLastPathComponent()
        let prefix = url.lastPathComponent + marker
        guard let entries = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        let matches = entries
            .filter { $0.lastPathComponent.hasPrefix(prefix) }
            .sorted { lhs, rhs in
                let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return lhsDate > rhsDate
            }
        guard matches.count > limit else { return }
        for stale in matches.dropFirst(limit) {
            try? fileManager.removeItem(at: stale)
        }
    }

    private func quarantineConfig(reason: String) {
        guard let url = try? SupportPaths.configURL(fileManager: fileManager) else {
            recordRecovery("Configuration could not be loaded: \(reason)")
            return
        }
        quarantineFile(at: url, label: "Configuration", reason: reason)
    }

    private func quarantineManifest(reason: String) {
        guard let url = try? SupportPaths.manifestURL(fileManager: fileManager) else {
            recordRecovery("Playlist library could not be loaded: \(reason)")
            return
        }
        quarantineFile(at: url, label: "Playlist library", reason: reason)
    }

    private func quarantineProfiles(reason: String) {
        guard let url = try? profilesURL() else {
            recordRecovery("Show profiles could not be loaded: \(reason)")
            return
        }
        quarantineFile(at: url, label: "Show profiles", reason: reason)
    }

    private func quarantineFile(at url: URL, label: String, reason: String) {
        guard fileManager.fileExists(atPath: url.path) else {
            recordRecovery("\(label) could not be loaded: \(reason)")
            return
        }
        let quarantineURL = url.deletingLastPathComponent()
            .appendingPathComponent("\(url.lastPathComponent).corrupt-\(Self.timestamp())-\(UUID().uuidString.prefix(8))")
        do {
            try fileManager.moveItem(at: url, to: quarantineURL)
            pruneOldSiblings(of: url, marker: ".corrupt-", keeping: 10)
            recordRecovery("\(label) was unreadable and was moved aside for recovery.")
        } catch {
            recordRecovery("\(label) was unreadable and could not be moved aside: \(error.localizedDescription)")
        }
    }

    private func recordRecovery(_ message: String) {
        recoveryMessages.append(message)
        Diagnostics.shared.record(LogEvent(source: "storage", message: "recovery warning", raw: message))
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }

    private static func safeFileName(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_"))
        let scalars = name.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let cleaned = String(scalars).trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Dead Air Playlist" : cleaned
    }
}
