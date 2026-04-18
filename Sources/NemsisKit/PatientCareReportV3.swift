//
//  PatientCareReport.swift
//  NemsisKit
//
//  Created by Francis Li on 4/15/26.
//

import Foundation
import Nodal
import SwiftXMLLint

class PatientCareReportV3 {
    let version: NemsisV3
    let id: UUID
    private var doc: Document!

    init(version: NemsisV3) throws {
        self.version = version
        id = UUID()
        try reset()
    }

    func reset() throws {
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

    func validate() throws -> [XMLValidationError] {
        let validator = try XMLValidator(xsdURL: version.emsDataSetXsdURL)
        // swiftlint:disable line_length
        let xml = """
<?xml version="1.0" encoding="UTF-8"?>
<EMSDataSet xmlns="http://www.nemsis.org"
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
            xsi:schemaLocation="http://www.nemsis.org https://nemsis.org/media/nemsis_v3/3.5.0.211008CP3/XSDs/NEMSIS_NAT_XSDs/EMSDataSet_v3.xsd">
    <Header>
        <DemographicGroup>
            <dAgency.01>0</dAgency.01>
            <dAgency.02>0</dAgency.02>
            <dAgency.04>00</dAgency.04>
        </DemographicGroup>
        \(try xmlString())
    </Header>
</EMSDataSet>
"""
        // swiftlint:enable line_length
        return try validator.validate(xml: xml)
    }

    func xmlString() throws -> String {
        return try doc.xmlString(options: [.indent, .noDeclaration])
    }
}
