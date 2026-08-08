//
//  PatientCareReport+CustomElements.swift
//  NemsisKit
//
//  Created by Francis Li on 7/12/26.
//

import Foundation
import Nodal

extension PatientCareReport {
    public func appXmlString() throws -> String? {
        return try appDoc?.xmlString(options: [.indent, .noDeclaration])
    }

    func appNodes(at xpath: String) throws -> [Node] {
        var nodes: [Node] = []
        if let appDoc {
            let query = try XPathQuery(xpath)
            let results = query.nodesResult(with: appDoc.node)
            for result in results {
                if let node = result.node {
                    nodes.append(node)
                }
            }
        }
        return nodes
    }

    func firstAppNode(at xpath: String) throws -> Node? {
        var node: Node?
        if let appDoc {
            let query = try XPathQuery(xpath)
            node = query.firstNodeResult(with: appDoc.node)?.node
        }
        return node
    }

    func insertAppNode(at xpath: String) throws -> Node? {
        if appDoc == nil {
            appDoc = Document()
            let root = appDoc?.makeDocumentElement(name: "PatientCareReport")
            root?[attribute: "UUID"] = id.uuidString.lowercased()
        }
        guard let appDoc else { throw NemsisError.unexpected }
        return try insertNode(at: xpath, in: appDoc)
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
        if let repeatingAncestorXpath = xpath.extractRepeatingAncestorXpath() {
            if let correlationIdNode = try firstNode(at: repeatingAncestorXpath) {
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

    func nemsisValuesForCustomResults(at xpath: String) throws -> [NemsisValue] {
        guard let last = xpath.split(separator: "/").last else { throw NemsisError.unexpected }
        let name = String(last)

        var values: [NemsisValue] = []
        guard let elementType = version.emsElementType(named: name),
              case let .custom(customElementType, isGrouped) = elementType else {
            throw NemsisError.unexpected
        }
        let (_, enumeration, _) = try version.emsElementTypeInfo(named: name)
        var nodesXpath: String!
        let correlationId = try getCorrelationId(for: nil, at: xpath)
        if let correlationId {
            nodesXpath = "/PatientCareReport/eCustomResults/eCustomResults.ResultsGroup[@CorrelationID=\"\(correlationId)\"]/" +
                "eCustomResults.02[text()=\"\(name)\"]/.. | " +
                "/PatientCareReport/eCustomResults/eCustomResults.ResultsGroup/eCustomResults.03[text()=\"\(correlationId)\"]" +
                "/preceding-sibling::eCustomResults.02[text()=\"\(name)\"]/.."
        } else {
            nodesXpath = "/PatientCareReport/eCustomResults/eCustomResults.ResultsGroup/" +
                "eCustomResults.02[text()=\"\(name)\"]/.."
        }
        let nodes = customElementType == .agency ? try nodes(at: nodesXpath) : try appNodes(at: nodesXpath)
        for node in nodes {
            for subnode in node[elements: "eCustomResults.01"] {
                let value = NemsisValue(value: subnode.textContent)
                if isGrouped,
                   let correlationId = node[attribute: "CorrelationID"] ?? node[element: "eCustomResults.03"]?.textContent {
                    if value.attributes == nil {
                        value.attributes = [:]
                    }
                    value.attributes?["CorrelationID"] = correlationId
                }
                for attr in subnode.attributes {
                    if value.attributes == nil {
                        value.attributes = [:]
                    }
                    value.attributes?[attr.name] = attr.value
                }
                if let enumeration, let enumValue = enumeration.first(where: { $0.value == subnode.textContent }) {
                    value.displayText = enumValue.label
                }
                values.append(value)
            }
        }
        return values
    }

    func insertCustomResultValue(_ value: String, for node: Node?, at xpath: String) throws -> Node {
        guard let last = xpath.split(separator: "/").last else { throw NemsisError.unexpected }
        let name = String(last)
        let elementType = version.emsElementType(named: name)
        var customElementType: NemsisCustomElementType = .agency
        var isGrouped = false
        if case .custom(let cCustomElementType, let cIsGrouped) = elementType {
            customElementType = cCustomElementType
            isGrouped = cIsGrouped
        }
        let customGroupingElement = version.customGroupingElement(for: name)

        var resultsPath = "/PatientCareReport/eCustomResults/eCustomResults.ResultsGroup"
        var correlationId: String?
        if isGrouped,
           name == customGroupingElement?[attribute: "CustomElementID"] {
            correlationId = xpath.extractCorrelationId()
            if let correlationId {
                resultsPath += "[@CorrelationID=\"\(correlationId)\"]"
                resultsPath += "/eCustomResults.02[text()=\"\(name)\"]"
            }
        } else {
            resultsPath += "/eCustomResults.02[text()=\"\(name)\"]"
            if isGrouped {
                correlationId = xpath.extractCorrelationId()
            } else {
                correlationId = try getCorrelationId(for: node, at: xpath, createIfMissing: true)
            }
            if let correlationId {
                resultsPath += "/following-sibling::eCustomResults.03[text()=\"\(correlationId)\"]"
            }
        }
        resultsPath += "/.."
        var node = customElementType == .agency ? try firstNode(at: resultsPath) : try firstAppNode(at: resultsPath)
        if node == nil {
            node = customElementType == .agency
                ? try insertNode(at: "/PatientCareReport/eCustomResults/eCustomResults.ResultsGroup")
                : try insertAppNode(at: "/PatientCareReport/eCustomResults/eCustomResults.ResultsGroup")
            node?[element: "eCustomResults.02"]?.textContent = name
            if isGrouped,
               name == customGroupingElement?[attribute: "CustomElementID"],
               let correlationId {
                node?[attribute: "CorrelationID"] = correlationId
            } else if let correlationId {
                node?.addElement("eCustomResults.03").textContent = correlationId
            }
            node = node?[element: "eCustomResults.01"]
        } else {
            if let prev = node?[elements: "eCustomResults.01"].last {
                node = node?.addElement("eCustomResults.01", at: .after(prev))
            } else {
                node = node?.addElement("eCustomResults.01", at: .first)
            }
        }
        node?.textContent = value
        return node!
    }

    func removeCustomResults(for xpath: String, insertNV: Bool) throws {
        guard let last = xpath.split(separator: "/").last else { throw NemsisError.unexpected }
        let name = String(last)
        switch version.emsElementType(named: name) {
        case .standard:
            return
        case .extended:
            // check for correlation ids on the elements themselves
            var correlationIds = (try nodes(at: xpath)).compactMap { $0[attribute: "CorrelationID"] }
            if correlationIds.isEmpty, let correlationId = try getCorrelationId(for: nil, at: xpath, createIfMissing: true) {
                // check for a correlation id on an ancestor
                correlationIds.append(correlationId)
            }
            var results: [Node] = []
            if correlationIds.isEmpty {
                var resultsPath = "/PatientCareReport/eCustomResults/eCustomResults.ResultsGroup"
                resultsPath += "/eCustomResults.02[text()=\"\(name)\"]/.."
                results = try nodes(at: resultsPath)
            } else {
                for correlationId in correlationIds {
                    var resultsPath = "/PatientCareReport/eCustomResults/eCustomResults.ResultsGroup"
                    resultsPath += "/eCustomResults.02[text()=\"\(name)\"]"
                    resultsPath += "/following-sibling::eCustomResults.03[text()=\"\(correlationId)\"]/.."
                    results.append(contentsOf: try nodes(at: resultsPath))
                }
            }
            for result in results {
                result.parentElement?.removeChild(result)
            }
        case .custom(let customElementType, let isGrouped):
            if !isGrouped {
                let correlationId = try getCorrelationId(for: nil, at: xpath, createIfMissing: true)
                var resultsPath = "/PatientCareReport/eCustomResults/eCustomResults.ResultsGroup"
                resultsPath += "/eCustomResults.02[text()=\"\(name)\"]"
                if let correlationId {
                    resultsPath += "/following-sibling::eCustomResults.03[text()=\"\(correlationId)\"]"
                }
                resultsPath += "/.."
                let results = customElementType == .agency ? try nodes(at: resultsPath) : try appNodes(at: resultsPath)
                for result in results {
                    result.parentElement?.removeChild(result)
                }
            } else {
                guard let customGroupingElement = version.customGroupingElement(for: name) else { throw NemsisError.unexpected }
                if let correlationId = xpath.extractCorrelationId() {
                    var resultsPath = "/PatientCareReport/eCustomResults"
                    if name == customGroupingElement[attribute: "CustomElementID"] {
                        resultsPath += "/eCustomResults.ResultsGroup[@CorrelationID=\"\(correlationId)\"]"
                    } else {
                        resultsPath += "/eCustomResults.ResultsGroup/eCustomResults.03[text()=\"\(correlationId)\"]"
                        resultsPath += "/preceding-sibling::eCustomResults.02[text()=\"\(name)\"]/.."
                    }
                    let results = customElementType == .agency ? try nodes(at: resultsPath) : try appNodes(at: resultsPath)
                    for result in results {
                        result.parentElement?.removeChild(result)
                    }
                }
            }
        default:
            throw NemsisError.unexpected
        }
    }
}
