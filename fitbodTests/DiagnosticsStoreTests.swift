//
//  DiagnosticsStoreTests.swift
//  fitbodTests
//
//  RM-063: the MetricKit reports Settings shares. The store keeps the
//  newest 30, newest first, and never lets one report replace another.
//

import Foundation
import Testing
@testable import fitbod

struct DiagnosticsStoreTests {
    private let folder = URL.temporaryDirectory.appending(path: "DiagnosticsStoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    private let start = Date(timeIntervalSince1970: 1_794_380_100)

    @Test func keepsTheNewestThirtyReports() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        for n in 0...30 {
            DiagnosticsStore.save(Data("\(n)".utf8), kind: n.isMultiple(of: 2) ? "metrics" : "diagnostics",
                                  in: folder, at: start.addingTimeInterval(Double(n)))
        }

        let kept = try DiagnosticsStore.reports(in: folder).map { try String(decoding: Data(contentsOf: $0), as: UTF8.self) }
        #expect(kept == (1...30).reversed().map(String.init))
    }

    @Test func twoReportsSavedTogetherBothStay() {
        defer { try? FileManager.default.removeItem(at: folder) }
        DiagnosticsStore.save(Data("a".utf8), kind: "metrics", in: folder, at: start)
        DiagnosticsStore.save(Data("b".utf8), kind: "metrics", in: folder, at: start)

        #expect(DiagnosticsStore.reports(in: folder).count == 2)
    }
}
