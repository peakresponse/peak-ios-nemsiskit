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

public enum NemsisError: Error {
    case notFound, unexpected
}

let emsDataSetFilename = "EMSDataSet_v3.xsd"
let agencyCustomElementsFilename = "agency.xml"
let appCustomElementsFilename = "app.xml"

func enumTuples(for typeNode: Node) throws -> [(label: String, value: String)]? {
    var query = try XPathQuery("./xs:restriction/xs:enumeration")
    let results = query.nodesResult(with: typeNode)
    if results.count > 0 {
        var enumeration: [(label: String, value: String)] = []
        query = try XPathQuery("./xs:annotation/xs:documentation")
        for result in results {
            guard let resultNode = result.node,
                  let value = resultNode[attribute: "value"],
                  let label = query.firstNodeResult(with: resultNode)?.node?.textContent else { continue }
            enumeration.append((label, value))
        }
        enumeration.sort(by: { $0.label < $1.label })
        return enumeration
    }
    return nil
}

@MainActor
public class Nemsis {
    public let versionString: String
    public let versionDirectoryURL: URL
    public let xsdsDirectoryURL: URL
    public let schsDirectoryURL: URL
    public let customDirectoryURL: URL

    public var emsDataSetXsdURL: URL {
        return xsdsDirectoryURL.appendingPathComponent(emsDataSetFilename)
    }

    public var agencyCustomElementsURL: URL {
        return customDirectoryURL.appendingPathComponent(agencyCustomElementsFilename)
    }

    public var appCustomElementsURL: URL {
        return customDirectoryURL.appendingPathComponent(appCustomElementsFilename)
    }

    var docs: [String: Document] = [:]
    var types: [String: [String: Node]] = [:]
    var elements: [String: [String: Node]] = [:]
    var agencyCustomElements: [String: [String: Node]] = [:]
    var appCustomElements: [String: [String: Node]] = [:]

    let schematronValidator: SchematronValidator
    public var webView: WKWebView {
        return schematronValidator.webView
    }

    public init(version: String) throws {
        self.versionString = version
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        versionDirectoryURL = appSupportURL
            .appendingPathComponent("NemsisKit", isDirectory: true)
            .appendingPathComponent("NemsisVersion", isDirectory: true)
            .appendingPathComponent(version, isDirectory: true)
        try FileManager.default.createDirectory(at: versionDirectoryURL, withIntermediateDirectories: true)
        xsdsDirectoryURL = versionDirectoryURL.appendingPathComponent("xsds")
        try FileManager.default.createDirectory(at: xsdsDirectoryURL, withIntermediateDirectories: true)
        schsDirectoryURL = versionDirectoryURL.appendingPathComponent("schs")
        try FileManager.default.createDirectory(at: schsDirectoryURL, withIntermediateDirectories: true)
        customDirectoryURL = versionDirectoryURL.appendingPathComponent("custom")
        try FileManager.default.createDirectory(at: customDirectoryURL, withIntermediateDirectories: true)

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

    public func newPCR() throws -> PatientCareReport {
        let pcr = try PatientCareReport(version: self)
        return pcr
    }

    public func xsd(_ filename: String) throws -> Document {
        if let doc = docs[filename] {
            return doc
        }
        let doc = try Document(url: xsdsDirectoryURL.appendingPathComponent(filename))
        docs[filename] = doc
        return doc
    }

    public func emsDataSetXsd() throws -> Document {
        if let doc = docs[emsDataSetFilename] {
            return doc
        }
        let doc = try Document(url: emsDataSetXsdURL)
        docs[emsDataSetFilename] = doc
        // also process all includes into types and elements caches
        types[emsDataSetFilename] = [:]
        elements[emsDataSetFilename] = [:]
        let query = try XPathQuery("/xs:schema/xs:include")
        let results = query.nodesResult(with: doc.node)
        func cacheTypes(from node: Node, xpath: String) throws {
            let query = try XPathQuery(xpath)
            let results = query.nodesResult(with: node)
            for result in results {
                guard let node = result.node, let name = node[attribute: "name"] else { continue }
                types[emsDataSetFilename]?[name] = node
            }
        }
        func cacheElements(from node: Node) throws {
            let query = try XPathQuery("//xs:element[@name]")
            let results = query.nodesResult(with: node)
            for result in results {
                guard let node = result.node, let name = node[attribute: "name"] else { continue }
                elements[emsDataSetFilename]?[name] = node
            }
        }
        try cacheElements(from: doc.node)
        for result in results {
            guard let node = result.node, let schemaLocation = node[attribute: "schemaLocation"] else { continue }
            let doc = try xsd(schemaLocation)
            try cacheTypes(from: doc.node, xpath: "/xs:schema/xs:simpleType[@name]")
            try cacheTypes(from: doc.node, xpath: "/xs:schema/xs:complexType[@name]")
            try cacheElements(from: doc.node)
        }
        // look for any agency and/or app custom elements
        if FileManager.default.fileExists(atPath: agencyCustomElementsURL.path) {
            let doc = try Document(url: agencyCustomElementsURL)
            docs[agencyCustomElementsFilename]  = doc
            let query = try XPathQuery("/StateDataSet/seCustomConfiguration/seCustomConfiguration.CustomGroup")
            let results = query.nodesResult(with: doc.node)
            agencyCustomElements[emsDataSetFilename] = [:]
            for result in results {
                guard let node = result.node, let name = node[attribute: "CustomElementID"] else { continue }
                agencyCustomElements[emsDataSetFilename]?[name] = node
            }
        }
        if FileManager.default.fileExists(atPath: appCustomElementsURL.path) {
            let doc = try Document(url: appCustomElementsURL)
            docs[appCustomElementsFilename] = doc
            let query = try XPathQuery("/StateDataSet/seCustomConfiguration/seCustomConfiguration.CustomGroup")
            let results = query.nodesResult(with: doc.node)
            appCustomElements[emsDataSetFilename] = [:]
            for result in results {
                guard let node = result.node, let name = node[attribute: "CustomElementID"] else { continue }
                appCustomElements[emsDataSetFilename]?[name] = node
            }
        }
        return doc
    }

    public func emsElement(in filename: String, xpath: String) throws -> Node? {
        let doc = try xsd(filename)
        let query = try XPathQuery(xpath)
        return query.firstNodeResult(with: doc.node)?.node
    }

    public func emsElement(named: String) -> Node? {
        return elements[emsDataSetFilename]?[named]
    }

    // swiftlint:disable:next large_tuple
    public func emsElementTypeInfo(named: String) throws -> (baseType: String?,
                                                             enumeration: [(label: String, value: String)]?,
                                                             negatives: [(label: String, value: String)]?) {
        guard let elementNode = emsElement(named: named) else { throw NemsisError.unexpected }
        var typeName = elementNode[attribute: "type"]
        var query = try XPathQuery("./xs:complexType/xs:simpleContent/xs:extension")
        let typeExtNode = query.firstNodeResult(with: elementNode)?.node
        if typeName == nil, let typeExtNode {
            typeName = typeExtNode[attribute: "base"]
        }
        guard let typeName, let typeNode = emsType(named: typeName) else { return (nil, nil, nil) }
        query = try XPathQuery("./xs:restriction")
        guard let restrictionNode = query.firstNodeResult(with: typeNode)?.node,
              let baseType = restrictionNode[attribute: "base"] else {
            throw NemsisError.unexpected
        }

        var enumeration = try enumTuples(for: typeNode)
        // check for custom element additions
        if let customElementNode = agencyCustomElements[emsDataSetFilename]?[named] {
            let query = try XPathQuery("./seCustomConfiguration.06")
            let results = query.nodesResult(with: customElementNode)
            for result in results {
                guard let resultNode = result.node,
                      let label = resultNode[attribute: "customValueDescription"] else { continue }
                enumeration?.append((label, resultNode.textContent.trimmingCharacters(in: .whitespacesAndNewlines)))
            }
            enumeration?.sort(by: {$0.label < $1.label})
        }

        var negatives: [(String, String)]?
        if let typeExtNode {
            func addNegatives(name: String) throws {
                query = try XPathQuery("./xs:attribute[@name='\(name)']/xs:simpleType/xs:union")
                if let unionNode = query.firstNodeResult(with: typeExtNode)?.node,
                   let memberTypes = unionNode[attribute: "memberTypes"]?.split(separator: " "),
                   memberTypes.count > 0 {
                    if negatives == nil {
                        negatives = []
                    }
                    for memberType in memberTypes {
                        guard let memberTypeNode = emsType(named: String(memberType)),
                              let values = try enumTuples(for: memberTypeNode) else { continue }
                        negatives?.append(contentsOf: values)
                    }
                }
            }
            try addNegatives(name: "PN")
            try addNegatives(name: "NV")
        }
        return (baseType, enumeration, negatives)
    }

    public func emsType(named: String) -> Node? {
        return types[emsDataSetFilename]?[named]
    }

    public func validate(pcr: PatientCareReport) async throws -> [XMLValidationError] {
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

    private func wrappedXml(pcr: PatientCareReport) throws -> String {
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
