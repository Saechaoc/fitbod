//
//  ZIPWriter.swift
//  fitbod
//
//  Wave-5 plan 06-10 Task 2 — minimal PKWARE-format ZIP writer used
//  by `BackupArchiver` to compose the `.fitbodbackup` container.
//
//  ## Why hand-written (CONTEXT D-30 + RESEARCH §Pattern 5 REVISED)
//
//  CONTEXT D-30 line 169 explicitly permits "Apple Compression framework
//  with a tiny zip header writer." The trade is ~150 LOC of PKWARE
//  encoding vs an AppleArchive (`.aar`) container that Finder cannot
//  open. Cross-platform readability is the load-bearing decision —
//  users may want to inspect their own backup archives outside the
//  Fitbod app, so we ship a real ZIP file with the `.fitbodbackup`
//  extension.
//
//  ## STORE-only in v1
//
//  CONTEXT D-30 does NOT require compression. We use compressionMethod=0
//  (STORE) for every entry, which means `compressedSize == uncompressedSize`
//  and no Compression-framework call is needed. The Recommendation lock
//  in 06-10 Task 2 Interfaces: "If profiling later shows backup size is
//  a problem, swap to DEFLATE for store.json only — single-call-site
//  change inside ZIPWriter.write."
//
//  ## Format (PKWARE APPNOTE 6.3.10)
//
//  Layout:
//    [Local File Header 1][Payload 1]
//    [Local File Header 2][Payload 2]
//    ...
//    [Central Directory Header 1]
//    [Central Directory Header 2]
//    ...
//    [End Of Central Directory]
//
//  All multi-byte integers are little-endian.
//
//  Signatures:
//    Local-file-header:                 0x04034b50 ("PK\x03\x04")
//    Central-directory-header:          0x02014b50 ("PK\x01\x02")
//    End-of-central-directory:          0x06054b50 ("PK\x05\x06")
//
//  CRC-32 polynomial: 0xEDB88320 (reflected — same as zlib / PKWARE).
//
//  [CITED: CONTEXT D-30 + RESEARCH §Pattern 5 REVISED +
//   RFC 1952 (zlib CRC) + PKWARE APPNOTE 6.3.10]
//

import Foundation

internal enum ZIPWriter {

    struct Entry {
        let path: String
        let data: Data
        let lastModified: Date
    }

    static func write(entries: [Entry]) throws -> Data {
        var archive = Data()
        var centralDirectory = Data()

        for entry in entries {
            let crc = Self.crc32(entry.data)
            let (dosTime, dosDate) = Self.dosTimeAndDate(entry.lastModified)
            let nameBytes = Data(entry.path.utf8)
            let nameLen = UInt16(nameBytes.count)
            let payloadSize = UInt32(entry.data.count)
            let localHeaderOffset = UInt32(archive.count)

            // Local File Header (30 bytes header + filename + payload)
            archive.appendLE(UInt32(0x04034b50))  // signature
            archive.appendLE(UInt16(20))          // version needed
            archive.appendLE(UInt16(0))           // general purpose flag
            archive.appendLE(UInt16(0))           // compression method: 0 = STORE
            archive.appendLE(dosTime)             // last mod time
            archive.appendLE(dosDate)             // last mod date
            archive.appendLE(crc)                 // crc-32
            archive.appendLE(payloadSize)         // compressed size (== uncompressed under STORE)
            archive.appendLE(payloadSize)         // uncompressed size
            archive.appendLE(nameLen)             // file name length
            archive.appendLE(UInt16(0))           // extra field length
            archive.append(nameBytes)
            archive.append(entry.data)

            // Central Directory Header (46 bytes + filename)
            centralDirectory.appendLE(UInt32(0x02014b50))  // signature
            centralDirectory.appendLE(UInt16(20))          // version made by
            centralDirectory.appendLE(UInt16(20))          // version needed
            centralDirectory.appendLE(UInt16(0))           // gp flag
            centralDirectory.appendLE(UInt16(0))           // compression method
            centralDirectory.appendLE(dosTime)
            centralDirectory.appendLE(dosDate)
            centralDirectory.appendLE(crc)
            centralDirectory.appendLE(payloadSize)
            centralDirectory.appendLE(payloadSize)
            centralDirectory.appendLE(nameLen)
            centralDirectory.appendLE(UInt16(0))           // extra field length
            centralDirectory.appendLE(UInt16(0))           // comment length
            centralDirectory.appendLE(UInt16(0))           // disk number start
            centralDirectory.appendLE(UInt16(0))           // internal file attrs
            centralDirectory.appendLE(UInt32(0))           // external file attrs
            centralDirectory.appendLE(localHeaderOffset)
            centralDirectory.append(nameBytes)
        }

        let centralDirOffset = UInt32(archive.count)
        let centralDirSize = UInt32(centralDirectory.count)
        archive.append(centralDirectory)

        // End of Central Directory (22 bytes — no comment)
        archive.appendLE(UInt32(0x06054b50))               // signature
        archive.appendLE(UInt16(0))                        // disk number
        archive.appendLE(UInt16(0))                        // central dir start disk
        archive.appendLE(UInt16(entries.count))            // total entries on this disk
        archive.appendLE(UInt16(entries.count))            // total entries
        archive.appendLE(centralDirSize)
        archive.appendLE(centralDirOffset)
        archive.appendLE(UInt16(0))                        // comment length

        return archive
    }

    // MARK: - DOS time encoding

    /// Encode a Date into DOS time + date fields per PKWARE spec.
    /// DOS time: bits 0-4 second/2, 5-10 minute, 11-15 hour.
    /// DOS date: bits 0-4 day, 5-8 month, 9-15 year offset from 1980.
    static func dosTimeAndDate(_ date: Date) -> (time: UInt16, date: UInt16) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let comp = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let year = max(0, (comp.year ?? 1980) - 1980)
        let month = comp.month ?? 1
        let day = comp.day ?? 1
        let hour = comp.hour ?? 0
        let minute = comp.minute ?? 0
        let second = (comp.second ?? 0) / 2

        let dosTime = UInt16((hour & 0x1F) << 11) | UInt16((minute & 0x3F) << 5) | UInt16(second & 0x1F)
        let dosDate = UInt16((year & 0x7F) << 9) | UInt16((month & 0x0F) << 5) | UInt16(day & 0x1F)
        return (dosTime, dosDate)
    }

    // MARK: - CRC-32 (PKWARE / zlib polynomial 0xEDB88320 reflected)

    /// 256-entry CRC-32 lookup table — computed once at first use,
    /// cached in a static property. The reflected polynomial 0xEDB88320
    /// matches what PKWARE ZIP archives expect AND what zlib's `crc32()`
    /// produces — interchangeable.
    private static let crcTable: [UInt32] = {
        var table = [UInt32](repeating: 0, count: 256)
        for i in 0..<256 {
            var c = UInt32(i)
            for _ in 0..<8 {
                c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1)
            }
            table[i] = c
        }
        return table
    }()

    static func crc32(_ data: Data) -> UInt32 {
        var c: UInt32 = 0xFFFFFFFF
        data.withUnsafeBytes { (buf: UnsafeRawBufferPointer) in
            for byte in buf {
                let idx = Int((c ^ UInt32(byte)) & 0xFF)
                c = crcTable[idx] ^ (c >> 8)
            }
        }
        return c ^ 0xFFFFFFFF
    }
}

// MARK: - Data little-endian helpers

private extension Data {
    mutating func appendLE(_ value: UInt16) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }

    mutating func appendLE(_ value: UInt32) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }
}
