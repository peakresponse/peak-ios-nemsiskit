//
//  PatientCareReport.swift
//  NemsisKit
//
//  Created by Francis Li on 4/15/26.
//

import Foundation
import Nodal

class PatientCareReportV3 {
    let version: NemsisV3
    let id: UUID
    private var doc: Document!

    init(version: NemsisV3) {
        self.version = version
        id = UUID()
        reset()
    }

    func reset() {
        doc = Document()
        let node = doc.makeDocumentElement(name: "PatientCareReport")
        node[attribute: "UUID"] = id.uuidString.lowercased()
    }

    func xmlString() throws -> String {
        return try doc.xmlString()
    }
}
