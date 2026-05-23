//
//  ZIPReader.swift
//  fitbod
//
//  Wave-5 plan 06-10 Task 2 — minimal PKWARE-format ZIP reader,
//  symmetric to `ZIPWriter`. Used by `BackupRestorer.preflight` and
//  `BackupRestorer.performRestore` to parse `.fitbodbackup` archives.
//
//  ## Security gates enforced here (defense-in-depth per RESEARCH §V10)
//
//  1. Path traversal — entry paths must NOT contain ".." NOR start
//     with "/"; must be exactly "manifest.json" / "store.json" OR
//     start with "images/". Reject with .pathTraversalDetected.
//  2. Decompression bomb — total decoded bytes capped at
//     `maxTotalUncompressed` (default 100 MB). Reject with
//     .totalSizeExceeded.
//  3. Compression method — STORE (0) only in v1. Other methods
//     rejected with .unsupportedCompressionMethod.
//  4. CRC-32 mismatch — per-entry payload CRC must match the value
//     in the central-directory record AND local-file-header.
//
//  ## EOCD scan
//
//  PKWARE specifies the end-of-central-directory may have up to
//  65535 bytes of optional comment data trailing it. We scan
//  backwards from the archive end for the EOCD signature within
//  the last 65536+22 bytes; throw .missingEndOfCentralDirectory
//  if not found (the archive is not a valid ZIP).
//
//  [CITED: CONTEXT D-30 + RESEARCH §Pattern 5 REVISED + §Security
//   Domain §V10 + PKWARE APPNOTE 6.3.10]
//

import Foundation

internal enum ZIPReader {

    struct Entry {
        let path: String
        let data: Data
    }

    enum ReadError: Error, Equatable {
        case missingEndOfCentralDirectory
        case malformedCentralDirectory
        case malformedLocalFileHeader
        case unsupportedCompressionMethod(UInt16)
        case crc32Mismatch(path: String)
        case totalSizeExceeded
        case pathTraversalDetected(entry: String)
    }

    static func read(
        data: Data,
        maxTotalUncompressed: Int = 100 * 1024 * 1024
    ) throws -> [Entry] {
        // 1. Locate End-of-Central-Directory signature (0x06054b50)
        //    by scanning backwards within the last 65536 + 22 bytes.
        guard let eocdOffset = Self.findEndOfCentralDirectory(in: data) else {
            throw ReadError.missingEndOfCentralDirectory
        }

        guard eocdOffset + 22 <= data.count else {
            throw ReadError.missingEndOfCentralDirectory
        }

        let totalEntries = data.readU16LE(at: eocdOffset + 10)
        let centralDirSize = data.readU32LE(at: eocdOffset + 12)
        let centralDirOffset = Int(data.readU32LE(at: eocdOffset + 16))

        guard centralDirOffset + Int(centralDirSize) <= data.count else {
            throw ReadError.malformedCentralDirectory
        }

        var entries: [Entry] = []
        var cdCursor = centralDirOffset
        var totalDecoded = 0

        for _ in 0..<totalEntries {
            // Central Directory Header — signature 0x02014b50
            guard cdCursor + 46 <= centralDirOffset + Int(centralDirSize) else {
                throw ReadError.malformedCentralDirectory
            }
            let cdSig = data.readU32LE(at: cdCursor)
            guard cdSig == 0x02014b50 else {
                throw ReadError.malformedCentralDirectory
            }

            let compressionMethod = data.readU16LE(at: cdCursor + 10)
            let crcExpected = data.readU32LE(at: cdCursor + 16)
            let compressedSize = data.readU32LE(at: cdCursor + 20)
            let uncompressedSize = data.readU32LE(at: cdCursor + 24)
            let nameLen = Int(data.readU16LE(at: cdCursor + 28))
            let extraLen = Int(data.readU16LE(at: cdCursor + 30))
            let commentLen = Int(data.readU16LE(at: cdCursor + 32))
            let localHeaderOffset = Int(data.readU32LE(at: cdCursor + 42))

            guard cdCursor + 46 + nameLen <= data.count else {
                throw ReadError.malformedCentralDirectory
            }
            let nameData = data.subdata(in: (cdCursor + 46)..<(cdCursor + 46 + nameLen))
            guard let path = String(data: nameData, encoding: .utf8) else {
                throw ReadError.malformedCentralDirectory
            }

            // Path-traversal gate (RESEARCH V10) — reject before
            // doing any further work on the entry.
            try Self.validatePath(path)

            // Decompression-bomb gate.
            totalDecoded += Int(uncompressedSize)
            if totalDecoded > maxTotalUncompressed {
                throw ReadError.totalSizeExceeded
            }

            // Compression-method gate (STORE only in v1).
            if compressionMethod != 0 {
                throw ReadError.unsupportedCompressionMethod(compressionMethod)
            }

            // Parse the corresponding Local File Header.
            guard localHeaderOffset + 30 <= data.count else {
                throw ReadError.malformedLocalFileHeader
            }
            let lfhSig = data.readU32LE(at: localHeaderOffset)
            guard lfhSig == 0x04034b50 else {
                throw ReadError.malformedLocalFileHeader
            }
            let lfhCompressionMethod = data.readU16LE(at: localHeaderOffset + 8)
            if lfhCompressionMethod != 0 {
                throw ReadError.unsupportedCompressionMethod(lfhCompressionMethod)
            }
            let lfhNameLen = Int(data.readU16LE(at: localHeaderOffset + 26))
            let lfhExtraLen = Int(data.readU16LE(at: localHeaderOffset + 28))
            let payloadStart = localHeaderOffset + 30 + lfhNameLen + lfhExtraLen
            let payloadEnd = payloadStart + Int(compressedSize)
            guard payloadEnd <= data.count else {
                throw ReadError.malformedLocalFileHeader
            }
            let payload = data.subdata(in: payloadStart..<payloadEnd)

            // CRC-32 validation.
            let crcComputed = ZIPWriter.crc32(payload)
            if crcComputed != crcExpected {
                throw ReadError.crc32Mismatch(path: path)
            }

            entries.append(Entry(path: path, data: payload))

            cdCursor += 46 + nameLen + extraLen + commentLen
        }

        return entries
    }

    // MARK: - Helpers

    /// Scan backward from `data.endIndex` for the EOCD signature
    /// 0x06054b50 within the last 65536+22 bytes (per PKWARE).
    /// Returns the byte offset of the signature, or nil if not found.
    private static func findEndOfCentralDirectory(in data: Data) -> Int? {
        let minHeaderSize = 22
        guard data.count >= minHeaderSize else { return nil }
        let scanStart = max(0, data.count - 65536 - minHeaderSize)
        let scanEnd = data.count - minHeaderSize

        var i = scanEnd
        while i >= scanStart {
            // Check signature little-endian: 0x50 0x4B 0x05 0x06
            if data[i] == 0x50 && data[i + 1] == 0x4B &&
                data[i + 2] == 0x05 && data[i + 3] == 0x06 {
                return i
            }
            i -= 1
        }
        return nil
    }

    /// Reject paths that escape the archive's logical root.
    /// Allowed: "manifest.json", "store.json", "images/*".
    private static func validatePath(_ path: String) throws {
        // Empty path — invalid.
        if path.isEmpty {
            throw ReadError.pathTraversalDetected(entry: path)
        }
        // Absolute path — never allowed.
        if path.hasPrefix("/") {
            throw ReadError.pathTraversalDetected(entry: path)
        }
        // Contains ".." segment — reject.
        if path.contains("..") {
            throw ReadError.pathTraversalDetected(entry: path)
        }
        // Whitelist: manifest.json / store.json / images/*.
        if path == "manifest.json" || path == "store.json" {
            return
        }
        if path.hasPrefix("images/") && path.count > "images/".count {
            return
        }
        throw ReadError.pathTraversalDetected(entry: path)
    }
}

// MARK: - Data little-endian readers

private extension Data {
    func readU16LE(at offset: Int) -> UInt16 {
        let lo = UInt16(self[offset])
        let hi = UInt16(self[offset + 1])
        return lo | (hi << 8)
    }

    func readU32LE(at offset: Int) -> UInt32 {
        let b0 = UInt32(self[offset])
        let b1 = UInt32(self[offset + 1])
        let b2 = UInt32(self[offset + 2])
        let b3 = UInt32(self[offset + 3])
        return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
    }
}
