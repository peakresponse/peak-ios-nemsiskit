//
//  PatientCareReportTests.swift
//  NemsisKit
//
//  Created by Francis Li on 8/5/26.
//

import Foundation
import Nodal
import SemVer
import Testing

@testable import NemsisKit

@MainActor
struct PatientCareReportTests {
    let version: Nemsis
    let pcr: PatientCareReport
    var nodes: [Node] = []
    var node: Node?
    var values: [NemsisValue] = []

    init() throws {
        version = try Nemsis(version: versionString)
        try loadFixtures(version: version)
        pcr = try PatientCareReport(version: version)
    }

    @Test
    mutating func testRequiredValue() throws {
        nodes = try pcr.nodes(at: "/PatientCareReport/ePatient/ePatient.09")
        try #require(nodes.count == 1)
        #expect(nodes[0][attribute: "xsi:nil"] == "true")
        #expect(nodes[0][attribute: "NV"] == NemsisNegative.notRecorded.rawValue)

        values = try pcr.nemsisValues(at: "/PatientCareReport/ePatient/ePatient.09")
        try #require(values.count == 1)
        #expect(values[0].isNil)
        #expect(values[0].negative == .notRecorded)
        #expect(values[0].displayText == "Not Recorded")

        try pcr.setNemsisValues([
            NemsisValue(value: "94103")
        ], at: "/PatientCareReport/ePatient/ePatient.09")

        nodes = try pcr.nodes(at: "/PatientCareReport/ePatient/ePatient.09")
        try #require(nodes.count == 1)
        #expect(nodes[0].attributes.isEmpty)
        #expect(nodes[0].textContent == "94103")

        values = try pcr.nemsisValues(at: "/PatientCareReport/ePatient/ePatient.09")
        try #require(values.count == 1)
        #expect(!values[0].isNil)
        #expect(values[0].text == "94103")
        #expect(values[0].displayText == nil)

        try pcr.setNemsisValues([], at: "/PatientCareReport/ePatient/ePatient.09")

        nodes = try pcr.nodes(at: "/PatientCareReport/ePatient/ePatient.09")
        try #require(nodes.count == 1)
        #expect(nodes[0][attribute: "xsi:nil"] == "true")
        #expect(nodes[0][attribute: "NV"] == NemsisNegative.notRecorded.rawValue)

        values = try pcr.nemsisValues(at: "/PatientCareReport/ePatient/ePatient.09")
        try #require(values.count == 1)
        #expect(values[0].isNil)
        #expect(values[0].negative == .notRecorded)
        #expect(values[0].displayText == "Not Recorded")
    }

    @Test
    mutating func testOptionalValue() throws {
        nodes = try pcr.nodes(at: "/PatientCareReport/ePatient/ePatient.PatientNameGroup")
        #expect(nodes.isEmpty)

        values = try pcr.nemsisValues(at: "/PatientCareReport/ePatient/ePatient.PatientNameGroup/ePatient.02")
        #expect(values.isEmpty)

        try pcr.setNemsisValues([
            NemsisValue(value: "Doe")
        ], at: "/PatientCareReport/ePatient/ePatient.PatientNameGroup/ePatient.02")

        nodes = try pcr.nodes(at: "/PatientCareReport/ePatient/ePatient.PatientNameGroup")
        try #require(nodes.count == 1)
        #expect(nodes[0].previousSibling == nil)
        #expect(nodes[0].nextSibling?.name == "ePatient.07")

        nodes = try pcr.nodes(at: "/PatientCareReport/ePatient/ePatient.PatientNameGroup/ePatient.02")
        try #require(nodes.count == 1)
        #expect(nodes[0].attributes.isEmpty)
        #expect(nodes[0].textContent == "Doe")

        values = try pcr.nemsisValues(at: "/PatientCareReport/ePatient/ePatient.PatientNameGroup/ePatient.02")
        try #require(values.count == 1)
        #expect(values[0].text == "Doe")
        #expect(values[0].attributes?.isEmpty ?? true)

        try pcr.setNemsisValues([], at: "/PatientCareReport/ePatient/ePatient.PatientNameGroup/ePatient.02")
        nodes = try pcr.nodes(at: "/PatientCareReport/ePatient/ePatient.PatientNameGroup")
        #expect(nodes.isEmpty)

        values = try pcr.nemsisValues(at: "/PatientCareReport/ePatient/ePatient.PatientNameGroup/ePatient.02")
        #expect(values.isEmpty)
    }

    @Test
    mutating func testEnumValue() throws {
        try pcr.setNemsisValues([
            NemsisValue(value: "9919001")
        ], at: "/PatientCareReport/ePatient/ePatient.25")

        nodes = try pcr.nodes(at: "/PatientCareReport/ePatient/ePatient.25")
        try #require(nodes.count == 1)
        #expect(nodes[0].textContent == "9919001")
        #expect(nodes[0].attributes.isEmpty)

        values = try pcr.nemsisValues(at: "/PatientCareReport/ePatient/ePatient.25")
        try #require(values.count == 1)
        #expect(values[0].text == "9919001")
        #expect(values[0].displayText == "Female")
        #expect(values[0].attributes?.isEmpty ?? true)
    }

    @Test
    mutating func testMultipleEnumValues() throws {
        try pcr.setNemsisValues([
            NemsisValue(value: "2514001"),
            NemsisValue(value: "2514003")
        ], at: "/PatientCareReport/ePatient/ePatient.14")

        nodes = try pcr.nodes(at: "/PatientCareReport/ePatient/ePatient.14")
        try #require(nodes.count == 2)
        #expect(nodes[0].textContent == "2514001")
        #expect(nodes[0].attributes.isEmpty)
        #expect(nodes[1].textContent == "2514003")
        #expect(nodes[1].attributes.isEmpty)

        values = try pcr.nemsisValues(at: "/PatientCareReport/ePatient/ePatient.14")
        try #require(values.count == 2)
        #expect(values[0].text == "2514001")
        #expect(values[0].displayText == "American Indian or Alaska Native")
        #expect(values[0].attributes?.isEmpty ?? true)
        #expect(values[1].text == "2514003")
        #expect(values[1].displayText == "Asian")
        #expect(values[1].attributes?.isEmpty ?? true)

        try pcr.setNemsisValues([
            NemsisValue(negative: .refused)
        ], at: "/PatientCareReport/ePatient/ePatient.14")
        nodes = try pcr.nodes(at: "/PatientCareReport/ePatient/ePatient.14")
        try #require(nodes.count == 1)
        #expect(nodes[0][attribute: "xsi:nil"] == "true")
        #expect(nodes[0][attribute: "PN"] == NemsisNegative.refused.rawValue)

        values = try pcr.nemsisValues(at: "/PatientCareReport/ePatient/ePatient.14")
        try #require(values.count == 1)
        #expect(values[0].isNil)
        #expect(values[0].negative == .refused)
        #expect(values[0].displayText == "Refused")

        try pcr.setNemsisValues([], at: "/PatientCareReport/ePatient/ePatient.14")
        nodes = try pcr.nodes(at: "/PatientCareReport/ePatient/ePatient.14")
        try #require(nodes.count == 1)
        #expect(nodes[0][attribute: "xsi:nil"] == "true")
        #expect(nodes[0][attribute: "NV"] == NemsisNegative.notRecorded.rawValue)

        values = try pcr.nemsisValues(at: "/PatientCareReport/ePatient/ePatient.14")
        try #require(values.count == 1)
        #expect(values[0].isNil)
        #expect(values[0].negative == .notRecorded)
        #expect(values[0].displayText == "Not Recorded")
    }
}
