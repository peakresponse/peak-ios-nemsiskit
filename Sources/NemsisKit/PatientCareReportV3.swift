//
//  PatientCareReport.swift
//  NemsisKit
//
//  Created by Francis Li on 4/15/26.
//

import Foundation
import Nodal
import SwiftXMLLint

enum PatientCareReportV3Error: Error {
    case missingUUID
}

@MainActor
public class PatientCareReportV3 {
    public let version: NemsisV3
    public let id: UUID
    private var doc: Document!

    public init(version: NemsisV3) throws {
        self.version = version
        id = UUID()
        try reset()
    }

    public init(version: NemsisV3, url fileURL: URL) throws {
        self.version = version
        doc = try Document(url: fileURL)
        if let uuid = UUID(uuidString: doc.documentElement?[attribute: "UUID"] ?? "") {
            id = uuid
        } else {
            throw PatientCareReportV3Error.missingUUID
        }
    }

    public func reset() throws {
        doc = Document()
        let root = doc.makeDocumentElement(name: "PatientCareReport")
        root[attribute: "UUID"] = id.uuidString.lowercased()

        let emsDataSetXsd = try version.emsDataSetXsd()
        var query = try
            XPathQuery("/xs:schema/xs:element[@name='EMSDataSet']" +
                       "/xs:complexType/xs:sequence/xs:element[@name='Header']" +
                       "/xs:complexType/xs:sequence/xs:element[@name='PatientCareReport']" +
                       "/xs:complexType/xs:sequence/xs:element")
        let results = query.nodesResult(with: emsDataSetXsd.node)
        for result in results {
            if let name = result.node?[attribute: "name"], let type = result.node?[attribute: "type"] {
                if let minOccurs = result.node?[attribute: "minOccurs"], minOccurs == "0" {
                    continue
                }
                let node = root.addElement(name)
                let typeXsd = try version.emsTypeXsd(named: name)
                query = try XPathQuery("/xs:schema/xs:complexType[@name='\(type)']/xs:sequence/xs:element")
                let typeResults = query.nodesResult(with: typeXsd.node)
                try reset(parentNode: node, results: typeResults)
            }
        }
    }

    private func reset(parentNode: Node, results: [XPathNode]) throws {
        for result in results {
            guard let resultNode = result.node else { continue }
            if let minOccurs = resultNode[attribute: "minOccurs"], minOccurs == "0" {
                continue
            }
            guard let name = resultNode[attribute: "name"] else { continue }
            let node = parentNode.addElement(name)
            if resultNode[attribute: "type"] != nil {
                continue
            }
            var query = try XPathQuery("xs:complexType/xs:simpleContent")
            if query.firstNodeResult(with: resultNode) != nil {
                // check if nillable and can be Not Recorded
                if resultNode[attribute: "nillable"] == "true" {
                    query = try XPathQuery("xs:complexType/xs:simpleContent/xs:extension/xs:attribute[@name='NV']" +
                                           "/xs:simpleType/xs:union")
                    if let memberTypes = query.firstNodeResult(with: resultNode)?.node?[attribute: "memberTypes"] {
                        let notValues = memberTypes.split(separator: " ")
                        if notValues.contains("NV.NotRecorded") {
                            node[attribute: "xsi:nil"] = "true"
                            node[attribute: "NV"] = "7701003"
                        }
                    }
                }
                continue
            }
            query = try XPathQuery("xs:complexType/xs:sequence/xs:element")
            let subResults = query.nodesResult(with: resultNode)
            try reset(parentNode: node, results: subResults)
        }
    }

    public func xmlString() throws -> String {
        return try doc.xmlString(options: [.indent, .noDeclaration])
    }
}
