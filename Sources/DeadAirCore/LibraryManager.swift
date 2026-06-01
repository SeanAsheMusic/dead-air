@preconcurrency import AVFAudio
import AudioToolbox
import Foundation

public final class LibraryManager: @unchecked Sendable {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func audioFiles(in urls: [URL]) -> [URL] {
        var result: [URL] = []
        for url in urls {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { continue }
            if isDirectory.boolValue {
                if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
                    for case let child as URL in enumerator where AudioFormatSupport.isSupportedAudioURL(child) {
                        result.append(child)
                    }
                }
            } else if AudioFormatSupport.isSupportedAudioURL(url) {
                result.append(url)
            }
        }
        return result.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    public func importFiles(_ urls: [URL], existing: [BedItem], storageMode: LibraryStorageMode = .managedCopy) throws -> [BedItem] {
        let bedsDirectory = try SupportPaths.bedsDirectory(fileManager: fileManager)
        let files = audioFiles(in: urls)
        var imported: [BedItem] = []
        var usedFileNames = Set(existing.map(\.fileName))

        for sourceURL in files {
            let accessGranted = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if accessGranted {
                    sourceURL.stopAccessingSecurityScopedResource()
                }
            }

            switch storageMode {
            case .managedCopy:
                let destinationFileName = uniqueFileName(for: sourceURL.lastPathComponent, used: &usedFileNames)
                let destination = bedsDirectory.appendingPathComponent(destinationFileName)
                if fileManager.fileExists(atPath: destination.path) {
                    try fileManager.removeItem(at: destination)
                }
                try fileManager.copyItem(at: sourceURL, to: destination)

                let metadata = readMetadata(destination)
                imported.append(
                    BedItem(
                        title: metadata.title ?? sourceURL.deletingPathExtension().lastPathComponent,
                        fileName: destinationFileName,
                        originalPath: sourceURL.path,
                        storageMode: .managedCopy,
                        durationSeconds: metadata.duration,
                        sampleRate: metadata.sampleRate,
                        channelCount: metadata.channelCount,
                        artist: metadata.artist,
                        musicalKey: metadata.key,
                        bpm: metadata.bpm,
                        metadataSource: metadata.hasTags ? .imported : .none
                    )
                )
            case .externalReference:
                let metadata = readMetadata(sourceURL)
                imported.append(
                    BedItem(
                        title: metadata.title ?? sourceURL.deletingPathExtension().lastPathComponent,
                        fileName: sourceURL.lastPathComponent,
                        originalPath: sourceURL.path,
                        bookmarkData: try bookmarkData(for: sourceURL),
                        storageMode: .externalReference,
                        durationSeconds: metadata.duration,
                        sampleRate: metadata.sampleRate,
                        channelCount: metadata.channelCount,
                        artist: metadata.artist,
                        musicalKey: metadata.key,
                        bpm: metadata.bpm,
                        metadataSource: metadata.hasTags ? .imported : .none
                    )
                )
            }
        }

        return imported
    }

    public func bedURL(for bed: BedItem) throws -> URL {
        switch bed.storageMode {
        case .managedCopy:
            return try SupportPaths.bedsDirectory(fileManager: fileManager).appendingPathComponent(bed.fileName)
        case .externalReference:
            if let bookmarkData = bed.bookmarkData {
                var isStale = false
                let url = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: [.withSecurityScope],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                return url
            }

            if let originalPath = bed.originalPath {
                return URL(fileURLWithPath: originalPath)
            }

            throw NSError(domain: "DeadAir.Library", code: 404, userInfo: [NSLocalizedDescriptionKey: "Referenced audio file is missing."])
        }
    }

    public func withSecurityScopedAccess<T>(to bed: BedItem, _ work: (URL) throws -> T) throws -> T {
        let url = try bedURL(for: bed)
        let shouldScope = bed.storageMode == .externalReference
        let didAccess = shouldScope && url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try work(url)
    }

    public func refreshedBookmarkDataIfNeeded(for bed: BedItem) throws -> Data? {
        guard bed.storageMode == .externalReference, let bookmarkData = bed.bookmarkData else {
            return nil
        }

        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        guard isStale else { return nil }

        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try self.bookmarkData(for: url)
    }

    public func relink(_ bed: BedItem, to url: URL) throws -> BedItem {
        let accessGranted = url.startAccessingSecurityScopedResource()
        defer {
            if accessGranted {
                url.stopAccessingSecurityScopedResource()
            }
        }

        var updated = bed
        let metadata = readMetadata(url)
        updated.fileName = url.lastPathComponent
        updated.originalPath = url.path
        updated.bookmarkData = try bookmarkData(for: url)
        updated.storageMode = .externalReference
        updated.durationSeconds = metadata.duration ?? updated.durationSeconds
        updated.sampleRate = metadata.sampleRate ?? updated.sampleRate
        updated.channelCount = metadata.channelCount ?? updated.channelCount
        if updated.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || updated.title == bed.fileName {
            updated.title = metadata.title ?? url.deletingPathExtension().lastPathComponent
        }
        updated.artist = metadata.artist ?? updated.artist
        updated.musicalKey = metadata.key ?? updated.musicalKey
        updated.bpm = metadata.bpm ?? updated.bpm
        updated.metadataSource = metadata.hasTags ? .imported : updated.metadataSource
        return updated
    }

    private func uniqueFileName(for original: String, used: inout Set<String>) -> String {
        let url = URL(fileURLWithPath: original)
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        var candidate = original
        var suffix = 2
        while used.contains(candidate) {
            candidate = ext.isEmpty ? "\(base)-\(suffix)" : "\(base)-\(suffix).\(ext)"
            suffix += 1
        }
        used.insert(candidate)
        return candidate
    }

    private func readMetadata(_ url: URL) -> (duration: Double?, sampleRate: Double?, channelCount: Int?, title: String?, artist: String?, bpm: Double?, key: String?, hasTags: Bool) {
        guard let file = try? AVAudioFile(forReading: url) else {
            return (nil, nil, nil, nil, nil, nil, nil, false)
        }
        let format = file.processingFormat
        let duration = Double(file.length) / format.sampleRate
        let tags = readFileTags(url)
        return (duration, format.sampleRate, Int(format.channelCount), tags.title, tags.artist, tags.bpm, tags.key, tags.hasTags)
    }

    private func readFileTags(_ url: URL) -> (title: String?, artist: String?, bpm: Double?, key: String?, hasTags: Bool) {
        let tags = audioInfoDictionary(for: url)
        let title = firstTagValue(in: tags, matching: ["title", "tit2"])
        let artist = firstTagValue(in: tags, matching: ["artist", "tpe1"])
        let bpm = firstTagValue(in: tags, matching: ["bpm", "tempo", "tbpm"]).flatMap(Double.init)
        let key = firstTagValue(in: tags, matching: ["initialkey", "initial key", "musicalkey", "musical key", "key", "tkey"])
        let hasTags = [title, artist, key].contains { $0 != nil } || bpm != nil
        return (title, artist, bpm, key, hasTags)
    }

    private func audioInfoDictionary(for url: URL) -> [String: String] {
        var audioFile: AudioFileID?
        guard AudioFileOpenURL(url as CFURL, .readPermission, 0, &audioFile) == noErr,
              let audioFile
        else {
            return [:]
        }
        defer { AudioFileClose(audioFile) }

        var dictionarySize: UInt32 = 0
        guard AudioFileGetPropertyInfo(audioFile, kAudioFilePropertyInfoDictionary, &dictionarySize, nil) == noErr,
              dictionarySize > 0
        else {
            return [:]
        }

        let dictionaryPointer = UnsafeMutableRawPointer.allocate(
            byteCount: MemoryLayout<CFDictionary?>.size,
            alignment: MemoryLayout<CFDictionary?>.alignment
        )
        defer { dictionaryPointer.deallocate() }
        dictionaryPointer.storeBytes(of: Optional<CFDictionary>.none, as: Optional<CFDictionary>.self)

        guard AudioFileGetProperty(audioFile, kAudioFilePropertyInfoDictionary, &dictionarySize, dictionaryPointer) == noErr,
              let dictionary = dictionaryPointer.load(as: Optional<CFDictionary>.self)
        else {
            return [:]
        }

        var tags: [String: String] = [:]
        for (key, value) in dictionary as NSDictionary {
            guard let value = "\(value)".trimmedNonEmpty else { continue }
            tags["\(key)".lowercased()] = value
        }
        return tags
    }

    private func firstTagValue(in tags: [String: String], matching needles: [String]) -> String? {
        for needle in needles {
            if let exact = tags[needle.lowercased()]?.trimmedNonEmpty {
                return exact
            }
        }

        for (key, value) in tags {
            let normalizedKey = key
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "_", with: "")
                .replacingOccurrences(of: "-", with: "")
                .lowercased()
            if needles.contains(where: { normalizedKey.contains($0.replacingOccurrences(of: " ", with: "").lowercased()) }) {
                return value.trimmedNonEmpty
            }
        }
        return nil
    }

    private func bookmarkData(for url: URL) throws -> Data {
        try url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
