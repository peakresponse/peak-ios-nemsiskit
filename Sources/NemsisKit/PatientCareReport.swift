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

@MainActor // swiftlint:disable:next type_body_length
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

    override public func insertNode(at xpath: String) throws -> Node? {
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
                if let nextIndex {
                    if nextIndex < (nodes?.count ?? 0) {
                        node = nodes?[nextIndex]
                    } else {
                        throw NemsisError.unexpected
                    }
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
        return node
    }

    // swiftlint:disable:next cyclomatic_complexity
    override public func removeNodes(at xpath: String, insertNV: Bool = true) throws {
        var target = xpath.split(separator: "/")
        guard let last = target.last else { throw NemsisError.unexpected }
        let name = String(last)
        if let customElementNode = version.agencyEmsCustomElement(named: name) {
            // TODO handle multiple occurrences with correlation ID
            // remove custom results for this element
            var nodes = try nodes(at: "/PatientCareReport/eCustomResults/eCustomResults.ResultsGroup/" +
                                  "eCustomResults.02[text()=\"\(name)\"]")
            nodes = nodes.map { $0.parentElement! }
            if let parent = nodes.first?.parentElement {
                for node in nodes {
                    parent.removeChild(node)
                }
            }
            if customElementNode[attribute: "CustomElementID"] !=
                customElementNode[element: "seCustomConfiguration.01"]?[attribute: "nemsisElement"] {
                return
            }
        }
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
        guard let last = xpath.split(separator: "/").last else { throw NemsisError.unexpected }
        let name = String(last)
        let customElementNode = version.agencyEmsCustomElement(named: name)
        if let customElementNode,
           customElementNode[attribute: "CustomElementID"] !=
               customElementNode[element: "seCustomConfiguration.01"]?[attribute: "nemsisElement"] {
            // TODO handle multiple occurrences with correlation id
            var nodes = try nodes(at: "/PatientCareReport/eCustomResults/eCustomResults.ResultsGroup/" +
                                  "eCustomResults.02[text()=\"\(name)\"]")
            nodes = nodes.map { $0.parentElement! }
            if nodes.count > 1 {

            }
            var values: [NemsisValue] = []
            if let node = nodes.first {
                for node in node[elements: "eCustomResults.01"] {
                    values.append(NemsisValue(value: node.textContent))
                }
            }
            return values
        }
        let nodes = try nodes(at: xpath)
        var values: [NemsisValue] = []
        if nodes.count > 0 {
            let (baseType, enumeration, negatives) = try version.emsElementTypeInfo(named: name)
            var customElementDescriptions: [String: String]?
            var customResultNodes: [Node]?
            if let customElementNode {
                customResultNodes = try self.nodes(at: "/PatientCareReport/eCustomResults/eCustomResults.ResultsGroup/" +
                                                   "eCustomResults.02[text()=\"\(name)\"]")
                customResultNodes = customResultNodes?.map { $0.parentElement! }

                let results = customElementNode[elements: "seCustomConfiguration.06"]
                customElementDescriptions = [:]
                for resultNode in results {
                    guard let description = resultNode[attribute: "customValueDescription"] else { continue }
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
                        if let customResultNodes {
                            if let correlationId = try getCorrelationId(for: node, at: xpath),
                               let customResultNode = customResultNodes
                                .first(where: { $0[element: "eCustomResults.03"]?.textContent == correlationId }) {
                                value.text = customResultNode[element: "eCustomResults.01"]?.textContent
                                value.displayText = customElementDescriptions?[value.text ?? ""]
                            } else if customResultNodes.count == 1, let customResultNode = customResultNodes.first {
                                value.text = customResultNode[element: "eCustomResults.01"]?.textContent
                                value.displayText = customElementDescriptions?[value.text ?? ""]
                            } else {
                                throw NemsisError.unexpected
                            }
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

    func getCorrelationId(for node: Node?, at xpath: String, createIfMissing: Bool = false) throws -> String? {
        var correlationId: String?
        // first check if we're attaching to an existing repeating element
        if let node {
            // check if node already has a CorrelationID, if so, just return
            correlationId = node[attribute: "CorrelationID"]
            if correlationId != nil {
                return correlationId
            }
            // otherwise, check type info to see if allowed
            if let elementNode = version.emsElement(named: node.name) {
                let query = try XPathQuery("./xs:complexType/xs:simpleContent/xs:extension/xs:attribute[@name=\"CorrelationID\"]")
                if query.firstNodeResult(with: elementNode) != nil {
                    if createIfMissing {
                        let uuid = UUID().uuidString.lowercased()
                        node[attribute: "CorrelationID"] = uuid
                        correlationId = uuid
                    }
                    return correlationId
                }
            }
        }
        // otherwise, check for a repeating ancestor group in the xpath
        let regex = try NSRegularExpression(pattern: "\\[\\d+\\]")
        let matches = regex.matches(in: xpath, range: NSRange(location: 0, length: xpath.count))
        if let match = matches.last {
            let repeatingGroupXpath = String(xpath[Range(NSRange(location: 0,
                                                                 length: match.range.location + match.range.length),
                                                         in: xpath)!])
            if let correlationIdNode = try firstNode(at: repeatingGroupXpath) {
                correlationId = correlationIdNode[attribute: "CorrelationID"]
                if correlationId == nil && createIfMissing {
                    let uuid = UUID().uuidString.lowercased()
                    correlationId = uuid
                    correlationIdNode[attribute: "CorrelationID"] = uuid
                }
            } else {
                throw NemsisError.unexpected
            }
        }
        return correlationId
    }

    // swiftlint:disable:next cyclomatic_complexity
    override public func setNemsisValues(_ values: [NemsisValue], at xpath: String) throws {
        guard let last = xpath.split(separator: "/").last else { return }
        let name = String(last)
        // check for a custom element definition
        let customElementNode = version.agencyEmsCustomElement(named: name)
        var customElementValues: [String: String]?
        if let customElementNode {
            // gather any custom value mappings
            let results = customElementNode[elements: "seCustomConfiguration.06"]
            customElementValues = [:]
            for resultNode in results {
                guard let nemsisValue = resultNode[attribute: "nemsisCode"] else { continue }
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
        if !isNotRecorded, values.count > 0 {
            var node = try firstNode(at: xpath)
            for value in values {
                if node == nil {
                    node = try insertNode(at: xpath)
                }
                let text = value.text ?? ""
                if let nemsisValue = customElementValues?[text] {
                    node?.textContent = nemsisValue
                } else {
                    node?.textContent = text
                }
                node?.removeAllAttributes()
                if customElementNode != nil {
                    // check if this is a custom repeating group
                    if let customGroupingElement = version.customGroupingElement(for: name) {
                        // check if there's a CorrelationID specified or if we're inserting a new record
                        let regex = try NSRegularExpression(pattern: "\\[@CorrelationID=\"([^\"]+)\"\\]")
                        let matches = regex.matches(in: xpath, range: NSRange(location: 0, length: xpath.count))
                        if let match = matches.last, match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: xpath) {
                            // extract CorrelationID
                            let correlationId = String(xpath[range])
                            if name == customGroupingElement[element: "seCustomConfiguration.09"]?.textContent {
                                node = try firstNode(at: "/PatientCareReport/eCustomResults/eCustomResults.ResultsGroup[@CorrelationID=\"\(correlationId)\"]")
                                if let node {
                                    if let nemsisValue = customElementValues?[text] {
                                        node[element: "eCustomResults.01"]?.textContent = nemsisValue
                                    } else {
                                        node[element: "eCustomResults.01"]?.textContent = text
                                    }
                                }
                                node = node?[element: "eCustomResults.01"]
                            } else {
                                var nodes = try nodes(at: "/PatientCareReport/eCustomResults/eCustomResults.ResultsGroup/eCustomResults.03[text()=\"\(correlationId)\"]")
                                nodes = nodes.map { $0.parentElement! }
                                if let node = nodes.first(where: { $0[element: "eCustomResults.02"]?.textContent == name }) {

                                } else {
                                    node = try insertNode(at: "/PatientCareReport/eCustomResults/eCustomResults.ResultsGroup")
                                    if let nemsisValue = customElementValues?[text] {
                                        node?[element: "eCustomResults.01"]?.textContent = nemsisValue
                                    } else {
                                        node?[element: "eCustomResults.01"]?.textContent = text
                                    }
                                    node?[element: "eCustomResults.02"]?.textContent = name
                                    node?.addElement("eCustomResults.03", at: .last)
                                    node?[element: "eCustomResults.03"]?.textContent = correlationId
                                    node = node?[element: "eCustomResults.01"]
                                }
                            }
                        } else if name == customGroupingElement[attribute: "CustomElementID"] {
                            // insert new results group with new correlation ID
                            node = try insertNode(at: "/PatientCareReport/eCustomResults/eCustomResults.ResultsGroup")
                            node?[attribute: "CorrelationID"] = UUID().uuidString.lowercased()
                            if let nemsisValue = customElementValues?[text] {
                                node?[element: "eCustomResults.01"]?.textContent = nemsisValue
                            } else {
                                node?[element: "eCustomResults.01"]?.textContent = text
                            }
                            node?[element: "eCustomResults.02"]?.textContent = name
                            node = node?[element: "eCustomResults.01"]
                        } else {
                            throw NemsisError.unexpected
                        }
                    } else {
                        // find/set correlation id for nearest repeating element, if any
                        let correlationId = try getCorrelationId(for: node, at: xpath, createIfMissing: true)
                        // insert custom results
                        var nodes = try nodes(at: "/PatientCareReport/eCustomResults/eCustomResults.ResultsGroup/" +
                                              "eCustomResults.02[text()=\"\(name)\"]")
                        nodes = nodes.map { $0.parentElement! }
                        if let correlationId {
                            var isFound = false
                            for parentNode in nodes where parentNode[element: "eCustomResults.03"]?.textContent == correlationId {
                                isFound = true
                                if let prev = parentNode[elements: "eCustomResults.01"].last {
                                    node = parentNode.addElement("eCustomResults.01", at: .after(prev))
                                } else {
                                    node = parentNode.addElement("eCustomResults.01", at: .first)
                                }
                                break
                            }
                            if !isFound {
                                node = try insertNode(at: "/PatientCareReport/eCustomResults/eCustomResults.ResultsGroup")
                                node?[element: "eCustomResults.01"]?.textContent = text
                                node?[element: "eCustomResults.02"]?.textContent = name
                                let correlationIdNode = node?.addElement("eCustomResults.03", at: .last)
                                correlationIdNode?.textContent = correlationId
                                node = node?[element: "eCustomResults.01"]
                            }
                            node?.textContent = text
                        } else {
                            if nodes.isEmpty {
                                node = try insertNode(at: "/PatientCareReport/eCustomResults/eCustomResults.ResultsGroup")
                                node?[element: "eCustomResults.01"]?.textContent = text
                                node?[element: "eCustomResults.02"]?.textContent = name
                                node = node?[element: "eCustomResults.01"]
                            } else if nodes.count == 1 {
                                node = nodes.first
                                if let prev = node?[elements: "eCustomResults.01"].last {
                                    node = node?.addElement("eCustomResults.01", at: .after(prev))
                                } else {
                                    node = node?.addElement("eCustomResults.01", at: .first)
                                }
                                node?.textContent = text
                            } else {
                                throw NemsisError.unexpected
                            }
                        }
                    }
                    node?.removeAllAttributes()
                }
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
