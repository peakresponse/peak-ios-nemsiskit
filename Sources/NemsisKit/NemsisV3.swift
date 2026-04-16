//
//  NemsisVersion.swift
//  NemsisKit
//
//  Created by Francis Li on 4/15/26.
//

import Foundation
import Nodal

class NemsisV3 {
    let version: String
    let versionDirectoryURL: URL
    let xsdsDirectoryURL: URL

    var xsds: [String: Document] = [:]

    init(version: String) throws {
        self.version = version
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        versionDirectoryURL = appSupportURL
            .appendingPathComponent("NemsisKit", isDirectory: true)
            .appendingPathComponent("NemsisV3", isDirectory: true)
            .appendingPathComponent(version, isDirectory: true)
        try FileManager.default.createDirectory(at: versionDirectoryURL, withIntermediateDirectories: true)
        xsdsDirectoryURL = versionDirectoryURL.appendingPathComponent("xsds")
        try FileManager.default.createDirectory(at: xsdsDirectoryURL, withIntermediateDirectories: true)
    }

    func newPCR() throws -> PatientCareReportV3 {
        let pcr = try PatientCareReportV3(version: self)
        return pcr
    }

    func xsd(named: String) throws -> Document {
        if let doc = xsds[named] {
            return doc
        }
        let doc = try Document(url: xsdsDirectoryURL.appendingPathComponent(named))
        xsds[named] = doc
        return doc
    }

    func emsDataSetXsd() throws -> Document {
        return try xsd(named: "EMSDataSet_v3.xsd")
    }

    func emsTypeXsd(named: String) throws -> Document {
        return try xsd(named: "\(named)_v3.xsd")
    }
}
