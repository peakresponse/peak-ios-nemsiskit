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

// swiftlint:disable:next force_try
let indexExpr = try! NSRegularExpression(pattern: #"([^\[]+)\[(\d+)\]"#, options: [.caseInsensitive])

func getTargetAndIndex(for xpath: String) -> (target: String, index: Int?) {
    var target = xpath
    var index: Int?
    if let match = indexExpr.firstMatch(in: xpath,
                                        options: [],
                                        range: NSRange(xpath.startIndex..<xpath.endIndex,
                                                       in: xpath)) {
        if match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: xpath) {
            target = String(xpath[range])
        }
        if match.numberOfRanges > 2, let range = Range(match.range(at: 2), in: xpath) {
            index = Int(String(xpath[range]))
            if index != nil {
                index = index! - 1
            }
        }
    }
    return (target, index)
}

@MainActor
public class PatientCareReport: NemsisXml {
    public private(set) var id: UUID!

    override public init(version: Nemsis) throws {
        id = UUID()
        try super.init(version: version)
    }

    override public init(version: Nemsis, url fileURL: URL) throws {
        try super.init(version: version, url: fileURL)
        if let uuid = UUID(uuidString: doc.documentElement?[attribute: "UUID"] ?? "") {
            id = uuid
        } else {
            throw PatientCareReportV3Error.missingUUID
        }
    }

    override public init(clone: PatientCareReport) throws {
        try super.init(clone: clone)
        id = clone.id
    }

    func traverse(schema: [XPathNode]? = nil,
                  with node: Node? = nil,
                  before: ((Node?, String, Node) throws -> Node?)? = nil,
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
                let child = try before?(node, name, schemaNode)
                if child == nil {
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
                    try traverse(schema: results, with: child, before: before, after: after)
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
                return nil
            }
            if let node = parentNode?.addElement(name) {
                if try isNillableNotRecorded(schemaNode: schemaNode) {
                    node[attribute: "xsi:nil"] = "true"
                    node[attribute: "NV"] = "7701003"
                    return nil
                }
            }
            return parentNode?[element: name]
        })
    }

    override public func insertNode(at xpath: String) throws -> Node {
        var target = xpath.split(separator: "/")
        var nextTarget = String(target.removeFirst())
        var nextIndex: Int?
        if nextTarget != "PatientCareReport" {
            throw NemsisError.unexpected
        }
        nextTarget = String(target.removeFirst())
        (nextTarget, nextIndex) = getTargetAndIndex(for: nextTarget)
        var isDone = false
        var stopNode: Node?
        var node: Node?
        var prevNode: Node?
        try traverse(before: { (parentNode, name, schemaNode) in
            if stopNode != nil {
                if isDone {
                    return nil
                }
                if let minOccurs = schemaNode[attribute: "minOccurs"], minOccurs == "0" {
                    return nil
                }
                if let node = parentNode?.addElement(name) {
                    if try isNillableNotRecorded(schemaNode: schemaNode) {
                        node[attribute: "xsi:nil"] = "true"
                        node[attribute: "NV"] = "7701003"
                        return nil
                    }
                }
                return parentNode?[element: name]
            }
            let nodes = parentNode?[elements: name]
            if name == nextTarget {
                if let nextIndex, nextIndex < (nodes?.count ?? 0) {
                    node = nodes?[nextIndex]
                } else {
                    node = nodes?.last
                }
                if node == nil {
                    node = parentNode?.addElement(name, at: prevNode != nil ? .after(prevNode!) : .first)
                } else if target.isEmpty {
                    node = parentNode?.addElement(name, at: .after(node!))
                }
                if target.isEmpty {
                    stopNode = parentNode
                    if try isNillableNotRecorded(schemaNode: schemaNode) {
                        isDone = true
                        node?[attribute: "xsi:nil"] = "true"
                        node?[attribute: "NV"] = "7701003"
                        return nil
                    }
                    return node
                }
                nextTarget = String(target.removeFirst())
                (nextTarget, nextIndex) = getTargetAndIndex(for: nextTarget)
                prevNode = nil
                return node
            } else {
                node = nodes?.last
            }
            if node != nil {
                prevNode = node
            }
            return nil
        }, after: { (parentNode, _, _) in
            if isDone {
                return true
            }
            if parentNode == stopNode {
                isDone = true
                return true
            }
            return false
        })
        if let node = node {
            return node
        }
        throw NemsisError.unexpected
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    override public func removeNodes(at xpath: String, insertNV: Bool = true) throws {
        var target = xpath.split(separator: "/")
        var nextTarget = String(target.removeFirst())
        var nextIndex: Int?
        if nextTarget != "PatientCareReport" {
            throw NemsisError.unexpected
        }
        nextTarget = String(target.removeFirst())
        (nextTarget, nextIndex) = getTargetAndIndex(for: nextTarget)
        var isFound = false
        try traverse(before: { (parentNode, name, schemaNode) in
            if isFound {
                return nil
            }
            let nodes = parentNode?[elements: name]
            if name == nextTarget {
                if target.isEmpty {
                    isFound = true
                    if !insertNV || schemaNode[attribute: "minOccurs"] == "0" {
                        for node in nodes ?? [] {
                            parentNode?.removeChild(node)
                        }
                    } else {
                        if let nodes, nodes.count > 1 {
                            for node in nodes[1...] {
                                parentNode?.removeChild(node)
                            }
                        }
                        if let node = nodes?.first {
                            node.removeAllChildren()
                            if try isNillableNotRecorded(schemaNode: schemaNode) {
                                node[attribute: "xsi:nil"] = "true"
                                node[attribute: "NV"] = "7701003"
                            }
                        }
                    }
                    return nil
                }
                var node: Node?
                if let nextIndex, nextIndex < (nodes?.count ?? 0) {
                    node = nodes?[nextIndex]
                }
                node = nodes?.last
                nextTarget = String(target.removeFirst())
                (nextTarget, nextIndex) = getTargetAndIndex(for: nextTarget)
                return node
            }
            return nil
        }, after: { (parentNode, name, schemaNode) in
            if let node = parentNode?[element: name], node.elements.isEmpty {
                if schemaNode[attribute: "minOccurs"] == "0" {
                    parentNode?.removeChild(node)
                }
            }
            return true
        })
    }

    override public func nemsisValues(at xpath: String) throws -> [NemsisValue] {
        let nodes = try nodes(at: xpath)
        guard let last = xpath.split(separator: "/").last else { throw NemsisError.unexpected }
        let name = String(last)
        var values: [NemsisValue] = []
        if nodes.count > 0 {
            let (baseType, enumeration, negatives) = try version.emsElementTypeInfo(named: name)
            let customElementNode = version.agencyEmsCustomElement(named: name) ??
                version.appEmsCustomElement(named: name)
            var customElementDescriptions: [String: String]?
            var customResultNodes: [Node]?
            if let customElementNode {
                customResultNodes = try self.nodes(at: "/PatientCareReport/eCustomResults/eCustomResults.ResultsGroup/" +
                                                   "eCustomResults.02[text()=\"\(name)\"]")
                customResultNodes = customResultNodes?.map { $0.parentElement! }

                let query = try XPathQuery("./seCustomConfiguration.06")
                let results = query.nodesResult(with: customElementNode)
                customElementDescriptions = [:]
                for result in results {
                    guard let resultNode = result.node,
                          let description = resultNode[attribute: "customValueDescription"] else { continue }
                    customElementDescriptions?[resultNode.textContent] = description
                }
            }
            for node in nodes {
                let value = NemsisValue(node: node)
                if value.isNil, let negative = negatives?.first(where: { $0.1 == value.negativeValue }) {
                    value.displayText = negative.0
                } else if let text = value.text, !text.isEmpty {
                    if let enumeration {
                        value.displayText = enumeration.first(where: { $0.1 == text })?.0
                        if let customResultNodes, let customResultNode = customResultNodes.first {
                            value.text = customResultNode[element: "eCustomResults.01"]?.textContent
                            value.displayText = customElementDescriptions?[value.text ?? ""]
                        }
                    } else if baseType == "xs:dateTime", let date = try? Date(text, strategy: .iso8601) {
                        value.displayText = date.formatted(date: .abbreviated, time: .shortened)
                    }
                }
                values.append(value)
            }
        }
        return values
    }

    override public func setNemsisValues(_ values: [NemsisValue], at xpath: String) throws {
        guard let last = xpath.split(separator: "/").last else { return }
        let name = String(last)
        // get valid enumeration/negatives, if any TODO validation check?
//        let (_, enumeration, negatives) = try version.emsElementTypeInfo(named: name)
        // check for a custom element definition
        let customElementNode = version.agencyEmsCustomElement(named: name) ?? version.appEmsCustomElement(named: name)
        var customElementValues: [String: String]?
        if let customElementNode {
            // gather any custom value mappings
            let query = try XPathQuery("./seCustomConfiguration.06")
            let results = query.nodesResult(with: customElementNode)
            customElementValues = [:]
            for result in results {
                guard let resultNode = result.node,
                      let nemsisValue = resultNode[attribute: "nemsisCode"] else { continue }
                customElementValues?[resultNode.textContent] = nemsisValue
            }
        }
        // check if we're just setting Not Recorded, which can be handled by the remove
        var isNotRecorded = false
        if values.count == 1, let value = values.first, value.isNil && value.negative == .notRecorded {
            isNotRecorded = true
        }
        // first remove existing nodes or set null with negative, per schema
        try removeNodes(at: xpath, insertNV: isNotRecorded)
        if customElementNode != nil {
            // remove custom results for this element
            var nodes = try nodes(at: "/PatientCareReport/eCustomResults/eCustomResults.ResultsGroup/" +
                                  "eCustomResults.02[text()=\"\(name)\"]")
            nodes = nodes.map { $0.parentElement! }
            if let parent = nodes.first?.parentElement {
                for node in nodes {
                    parent.removeChild(node)
                }
            }
        }
        if !isNotRecorded, values.count > 0 {
            var node = try firstNode(at: xpath)
            for value in values {
                if node == nil {
                    node = try insertNode(at: xpath)
                }
                let text = value.text ?? ""
                if let nemsisValue = customElementValues?[text] {
                    node?.textContent = nemsisValue
                    // insert custom results
                    var node = try firstNode(at: "/PatientCareReport/eCustomResults/eCustomResults.ResultsGroup/" +
                                             "eCustomResults.02[text()=\"\(name)\"]")
                    if node == nil {
                        node = try insertNode(at: "/PatientCareReport/eCustomResults/eCustomResults.ResultsGroup")
                        node?[element: "eCustomResults.01"]?.textContent = text
                        node?[element: "eCustomResults.02"]?.textContent = name
                        node = node?[element: "eCustomResults.01"]
                    }
                } else {
                    node?.textContent = text
                }
                node?.removeAllAttributes()
                if let attributes = value.attributes {
                    for (key, value) in attributes {
                        node?[attribute: key] = value
                    }
                }
                node = nil
            }
        }
    }
}
