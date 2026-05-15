//
//  NemsisVersion.swift
//  NemsisKit
//
//  Created by Francis Li on 4/15/26.
//

import Foundation
import Nodal
import SwiftXMLLint
import WebKit

public enum NemsisV3Error: Error {
    case notFound
}

@MainActor
public class NemsisV3 {
    public let versionString: String
    public let versionDirectoryURL: URL
    public let xsdsDirectoryURL: URL
    public let schsDirectoryURL: URL

    public var emsDataSetXsdURL: URL {
        return xsdsDirectoryURL.appendingPathComponent("EMSDataSet_v3.xsd")
    }

    var xsds: [String: Document] = [:]
    var types: [String: Node] = [:]

    let schematronValidator: SchematronValidator
    public var webView: WKWebView {
        return schematronValidator.webView
    }

    public init(version: String) throws {
        self.versionString = version
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        versionDirectoryURL = appSupportURL
            .appendingPathComponent("NemsisKit", isDirectory: true)
            .appendingPathComponent("NemsisV3", isDirectory: true)
            .appendingPathComponent(version, isDirectory: true)
        try FileManager.default.createDirectory(at: versionDirectoryURL, withIntermediateDirectories: true)
        xsdsDirectoryURL = versionDirectoryURL.appendingPathComponent("xsds")
        try FileManager.default.createDirectory(at: xsdsDirectoryURL, withIntermediateDirectories: true)
        schsDirectoryURL = versionDirectoryURL.appendingPathComponent("schs")
        try FileManager.default.createDirectory(at: schsDirectoryURL, withIntermediateDirectories: true)

        let saxonURL = Bundle.module.url(forResource: "SaxonJS", withExtension: nil)!
        let saxonURLs = try FileManager.default.contentsOfDirectory(at: saxonURL, includingPropertiesForKeys: nil)
        for url in saxonURLs {
            let destURL = schsDirectoryURL.appendingPathComponent(url.lastPathComponent)
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: url, to: destURL)
        }

        schematronValidator = SchematronValidator(baseURL: schsDirectoryURL)
    }

    public func newPCR() throws -> PatientCareReportV3 {
        let pcr = try PatientCareReportV3(version: self)
        return pcr
    }

    public func xsd(named: String) throws -> Document {
        if let doc = xsds[named] {
            return doc
        }
        let doc = try Document(url: xsdsDirectoryURL.appendingPathComponent(named))
        xsds[named] = doc
        return doc
    }

    public func emsDataSetXsd() throws -> Document {
        return try xsd(named: "EMSDataSet_v3.xsd")
    }

    public func emsTypeXsd(named: String) throws -> Document {
        return try xsd(named: "\(named)_v3.xsd")
    }

    public func emsElement(in xsd: String, xPath: String) throws -> Node {
        let doc = try self.xsd(named: xsd)
        let query = try XPathQuery(xPath)
        if let result = query.firstNodeResult(with: doc.node), let node = result.node {
            return node
        }
        throw NemsisV3Error.notFound
    }

    public func emsTypeElement(in xsd: String, named: String) throws -> Node {
        // first check if in cache
        if let node = types[named] {
            return node
        }

        // helper function to process xpath query results and look for named node
        func process(_ results: [XPathNode]) -> Node? {
            var found: Node?
            for result in results {
                if let node = result.node, let name = node[attribute: "name"] {
                    types[name] = node
                    if name == named {
                        found = node
                    }
                }
            }
            return found
        }

        // next look in specified xsd
        var doc = try self.xsd(named: xsd)
        let query = try XPathQuery("/xs:schema/xs:simpleType")
        var results = query.nodesResult(with: doc.node)
        if let found = process(results) {
            return found
        }

        // finally look in common types
        doc = try self.xsd(named: "commonTypes_v3.xsd")
        results = query.nodesResult(with: doc.node)
        if let found = process(results) {
            return found
        }
        throw NemsisV3Error.notFound
    }

    public func validate(pcr: PatientCareReportV3) async throws -> [XMLValidationError] {
        let validator = try XMLValidator(xsdURL: emsDataSetXsdURL)
        let wrappedXML = try wrappedXml(pcr: pcr)
        var errors = try validator.validate(xml: wrappedXML)
        if errors.isEmpty {
            return try await schematronValidator.validate(xml: wrappedXML, with: "EMSDataSet.sch.xsl.sef.json")
        } else {
            errors = errors.map { XMLValidationError(message: $0.message, // swiftlint:disable:next line_length
                                                     location: $0.location.replacingOccurrences(of: "/EMSDataSet/Header", with: ""))}
        }
        return errors
    }

    private func wrappedXml(pcr: PatientCareReportV3) throws -> String {
        // swiftlint:disable line_length
        return """
<?xml version="1.0" encoding="UTF-8"?>
<EMSDataSet xmlns="http://www.nemsis.org"
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
            xsi:schemaLocation="http://www.nemsis.org https://nemsis.org/media/nemsis_v3/\(versionString)/XSDs/NEMSIS_NAT_XSDs/EMSDataSet_v3.xsd">
    <Header>
        <DemographicGroup>
            <dAgency.01>0</dAgency.01>
            <dAgency.02>0</dAgency.02>
            <dAgency.04>00</dAgency.04>
        </DemographicGroup>
        \(try pcr.xmlString())
    </Header>
</EMSDataSet>
"""
        // swiftlint:enable line_length
    }
}
