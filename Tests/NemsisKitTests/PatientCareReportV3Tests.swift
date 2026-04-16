//
//  PatientCareReportV3Tests.swift
//  NemsisKit
//
//  Created by Francis Li on 4/16/26.
//

import Foundation
import Nodal
import Testing
@testable import NemsisKit

let versionString = "3.5.1.251001CP2"

struct PatientCareReportV3Tests {
    let version: NemsisV3

    init() throws {
        version = try NemsisV3(version: "3.5.1.251001CP2")
        let testDataURL = Bundle.module.url(forResource: "Fixtures/XSDs/\(versionString)", withExtension: nil)
        let fileURLs = try FileManager.default.contentsOfDirectory(at: testDataURL!, includingPropertiesForKeys: nil)
        for fileURL in fileURLs {
            let destURL = version.xsdsDirectoryURL.appendingPathComponent(fileURL.lastPathComponent)
            if !FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.copyItem(at: fileURL,
                                                 to: version.xsdsDirectoryURL
                                                            .appendingPathComponent(fileURL.lastPathComponent))
            }
        }
    }

    @Test
    func testNewPCR() throws {
        let pcr = PatientCareReportV3(version: version)
        print(try pcr.xmlString())
    }
}
