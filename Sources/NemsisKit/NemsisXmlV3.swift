//
//  NemsisXmlV3.swift
//  NemsisKit
//
//  Created by Francis Li on 5/21/26.
//

import Foundation
import Nodal

public enum NemsisXmlV3Error: Error {
    case unimplemented
}

@MainActor
public class NemsisXmlV3 {
    public let version: NemsisV3
    var doc: Document!

    public init(version: NemsisV3) throws {
        self.version = version
        try reset()
    }

    public init(version: NemsisV3, url fileURL: URL) throws {
        self.version = version
        doc = try Document(url: fileURL)
    }

    public init(clone: PatientCareReportV3) throws {
        version = clone.version
        doc = try Document(string: clone.xmlString())
    }

    public func reset() throws {
        doc = Document()
    }

    public func xmlString() throws -> String {
        return try doc.xmlString(options: [.indent, .noDeclaration])
    }

    public func firstNode(at xpath: String) throws -> Node? {
        let query = try XPathQuery(xpath)
        return query.firstNodeResult(with: doc.node)?.node
    }

    public func nodes(at xpath: String) throws -> [Node] {
        let query = try XPathQuery(xpath)
        let results = query.nodesResult(with: doc.node)
        var nodes: [Node] = []
        for result in results {
            if let node = result.node {
                nodes.append(node)
            }
        }
        return nodes
    }

    public func insertNode(at xpath: String) throws -> Node {
        throw NemsisXmlV3Error.unimplemented
    }

    public func removeNode(at xpath: String) throws {
        throw NemsisXmlV3Error.unimplemented
    }

    public func setValue(_ value: Any?,
                         negative: String? = nil,
                         attributes: [String: String]? = nil,
                         at xpath: String) throws {
        throw NemsisXmlV3Error.unimplemented
    }
}
