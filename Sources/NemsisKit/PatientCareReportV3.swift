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

func isNillableNotRecorded(schemaNode: Node) throws -> Bool {
    if schemaNode[attribute: "nillable"] == "true" {
        let query = try XPathQuery("./xs:complexType/xs:simpleContent/xs:extension" +
                                   "/xs:attribute[@name='NV']/xs:simpleType/xs:union")
        if let memberTypes = query.firstNodeResult(with: schemaNode)?.node?[attribute: "memberTypes"] {
            let notValues = memberTypes.split(separator: " ")
            if notValues.contains("NV.NotRecorded") {
                return true
            }
        }
    }
    return false
}

@MainActor
public class PatientCareReportV3: NemsisXmlV3 {
    public private(set) var id: UUID!

    override public init(version: NemsisV3) throws {
        id = UUID()
        try super.init(version: version)
    }

    override public init(version: NemsisV3, url fileURL: URL) throws {
        try super.init(version: version, url: fileURL)
        if let uuid = UUID(uuidString: doc.documentElement?[attribute: "UUID"] ?? "") {
            id = uuid
        } else {
            throw PatientCareReportV3Error.missingUUID
        }
    }

    override public init(clone: PatientCareReportV3) throws {
        try super.init(clone: clone)
        id = clone.id
    }

    func traverse(schema: [XPathNode]? = nil,
                  with node: Node? = nil,
                  before: ((Node?, String, Node) throws -> Bool)? = nil,
                  after: ((Node?, String, Node) throws -> Bool)? = nil) throws {
        var schema = schema
        var node = node
        if schema == nil {
            node = doc.documentElement
            let emsDataSetXsd = try version.emsDataSetXsd()
            let query = try XPathQuery("/xs:schema/xs:element[@name='EMSDataSet']" +
                                       "/xs:complexType/xs:sequence/xs:element[@name='Header']" +
                                       "/xs:complexType/xs:sequence/xs:element[@name='PatientCareReport']" +
                                       "/xs:complexType/xs:sequence/xs:element")
            schema = query.nodesResult(with: emsDataSetXsd.node)
        }
        if let schema {
            for result in schema {
                guard let schemaNode = result.node, let name = schemaNode[attribute: "name"] else { continue }
                if try before?(node, name, schemaNode) ?? false {
                    continue
                }
                var results: [XPathNode]?
                if let schemaType = schemaNode[attribute: "type"],
                   let schemaTypeNode = version.emsType(named: schemaType) {
                    let query = try XPathQuery("./xs:sequence/xs:element")
                    results = query.nodesResult(with: schemaTypeNode)
                } else {
                    let query = try XPathQuery("./xs:complexType/xs:sequence/xs:element")
                    results = query.nodesResult(with: schemaNode)
                }
                if let results, results.count > 0 {
                    try traverse(schema: results, with: node?[element: name], before: before, after: after)
                }
                if try after?(node, name, schemaNode) ?? false {
                    return
                }
            }
        }
    }

    override public func reset() throws {
        try super.reset()
        let root = doc.makeDocumentElement(name: "PatientCareReport")
        root[attribute: "UUID"] = id.uuidString.lowercased()
        try traverse(before: { (parentNode, name, schemaNode) in
            if let minOccurs = schemaNode[attribute: "minOccurs"], minOccurs == "0" {
                return true
            }
            if let node = parentNode?.addElement(name) {
                if try isNillableNotRecorded(schemaNode: schemaNode) {
                    node[attribute: "xsi:nil"] = "true"
                    node[attribute: "NV"] = "7701003"
                    return true
                }
            }
            return false
        })
    }

    override public func insertNode(at xpath: String) throws -> Node {
        var target = xpath.split(separator: "/")
        var nextTarget = String(target.removeFirst())
        if nextTarget != "PatientCareReport" {
            throw NemsisV3Error.unexpected
        }
        nextTarget = String(target.removeFirst())
        var isFound = false
        var node: Node?
        var prevNode: Node?
        try traverse(before: { (parentNode, name, schemaNode) in
            if isFound {
                return true
            }
            node = parentNode?[element: name]
            if name == nextTarget {
                if node == nil {
                    node = parentNode?.addElement(name, at: prevNode != nil ? .after(prevNode!) : .first)
                }
                if target.isEmpty {
                    isFound = true
                    if try isNillableNotRecorded(schemaNode: schemaNode) {
                        node?[attribute: "xsi:nil"] = "true"
                        node?[attribute: "NV"] = "7701003"
                    }
                    return true
                }
                nextTarget = String(target.removeFirst())
                prevNode = nil
                return false
            }
            prevNode = node
            return true
        }, after: { (_, _, _) in
            return true
        })
        if let node = node {
            return node
        }
        throw NemsisV3Error.unexpected
    }

    override public func removeNode(at xpath: String) throws {
        var target = xpath.split(separator: "/")
        var nextTarget = String(target.removeFirst())
        if nextTarget != "PatientCareReport" {
            throw NemsisV3Error.unexpected
        }
        nextTarget = String(target.removeFirst())
        var isFound = false
        try traverse(before: { (parentNode, name, schemaNode) in
            if isFound {
                return true
            }
            let node = parentNode?[element: name]
            if name == nextTarget {
                if target.isEmpty {
                    isFound = true
                    if let node {
                        if schemaNode[attribute: "minOccurs"] == "0" {
                            parentNode?.removeChild(node)
                        } else {
                            node.removeAllChildren()
                            if try isNillableNotRecorded(schemaNode: schemaNode) {
                                node[attribute: "xsi:nil"] = "true"
                                node[attribute: "NV"] = "7701003"
                            }
                        }
                    }
                    return true
                }
                nextTarget = String(target.removeFirst())
                return false
            }
            return true
        }, after: { (parentNode, name, schemaNode) in
            if let node = parentNode?[element: name], node.elements.isEmpty {
                if schemaNode[attribute: "minOccurs"] == "0" {
                    parentNode?.removeChild(node)
                }
            }
            return true
        })
    }
}
