//
//  NemsisVersion3Tests.swift
//  NemsisKit
//
//  Created by Francis Li on 4/16/26.
//

import Foundation
import Nodal
import Testing
@testable import NemsisKit

@Test func testNemsisV3() async throws {
    // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    // Swift Testing Documentation
    // https://developer.apple.com/documentation/testing
    let versionString = "3.5.1.251001CP2"
    let version = try NemsisV3(version: versionString)
    #expect(version.version == versionString)

    let testDataURL = Bundle.module.url(forResource: "Fixtures/XSDs/\(versionString)", withExtension: nil)
    let fileURLs = try FileManager.default.contentsOfDirectory(at: testDataURL!, includingPropertiesForKeys: nil)
    for fileURL in fileURLs {
        let destURL = version.xsdsDirectoryURL.appendingPathComponent(fileURL.lastPathComponent)
        if !FileManager.default.fileExists(atPath: destURL.path) {
            try FileManager.default.copyItem(at: fileURL, to: version.xsdsDirectoryURL.appendingPathComponent(fileURL.lastPathComponent))
        }
    }

    let emsDataSetXSD = try version.emsDataSetXsd()
    let query = try XPathQuery("/xs:schema/xs:element[@name='EMSDataSet']")
    let node = query.firstNodeResult(with: emsDataSetXSD.node)
    #expect(node != nil)
}
