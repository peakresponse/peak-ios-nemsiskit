//
//  NemsisXmlV3.swift
//  NemsisKit
//
//  Created by Francis Li on 5/21/26.
//

import Foundation
import Nodal

public enum NemsisXmlError: Error {
    case unimplemented
}

@MainActor
public class NemsisXml {
    public let version: Nemsis
    var doc: Document!

    public init(version: Nemsis) throws {
        self.version = version
        try reset()
    }

    public init(version: Nemsis, url fileURL: URL) throws {
        self.version = version
        doc = try Document(url: fileURL)
    }

    public init(clone: PatientCareReport) throws {
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

    public func insertNode(at xpath: String) throws -> Node? {
        throw NemsisXmlError.unimplemented
    }

    public func removeNodes(at xpath: String, insertNV: Bool = true) throws {
        throw NemsisXmlError.unimplemented
    }

    public func nemsisValues(at xpath: String) throws -> [NemsisValue] {
        throw NemsisXmlError.unimplemented
    }

    public func setNemsisValues(_ values: [NemsisValue], at xpath: String) throws {
        throw NemsisXmlError.unimplemented
    }
}
