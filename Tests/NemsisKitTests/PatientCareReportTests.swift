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
        try #require(nodes.isEmpty)

        values = try pcr.nemsisValues(at: "/PatientCareReport/ePatient/ePatient.PatientNameGroup/ePatient.02")
        try #require(values.isEmpty)

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
    mutating func testDateValue() throws {
        try pcr.setNemsisValues([
            NemsisValue(value: try Date("2026-06-19T15:06:00-07:00", strategy: .iso8601))
        ], at: "/PatientCareReport/eTimes/eTimes.01")

        nodes = try pcr.nodes(at: "/PatientCareReport/eTimes/eTimes.01")
        try #require(nodes.count == 1)
        #expect(nodes[0].textContent == "2026-06-19T15:06:00-07:00")
        #expect(nodes[0].attributes.isEmpty)

        values = try pcr.nemsisValues(at: "/PatientCareReport/eTimes/eTimes.01")
        try #require(values.count == 1)
        #expect(values[0].text == "2026-06-19T15:06:00-07:00")
        #expect(values[0].displayText == "Jun 19, 2026 at 3:06 PM")
        #expect(values[0].attributes?.isEmpty ?? true)
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
    mutating func testRequiredMultipleEnumValues() throws {
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

    @Test
    mutating func testOptionalMultipleEnumValues() throws {
        nodes = try pcr.nodes(at: "/PatientCareReport/ePatient/ePatient.18")
        try #require(nodes.isEmpty)

        values = try pcr.nemsisValues(at: "/PatientCareReport/ePatient/ePatient.18")
        try #require(values.isEmpty)

        try pcr.setNemsisValues([
            NemsisValue(value: "415-555-1234", attributes: ["PhoneNumberType": "9913005"]),
            NemsisValue(value: "415-555-5678", attributes: ["PhoneNumberType": "9913009"])
        ], at: "/PatientCareReport/ePatient/ePatient.18")

        nodes = try pcr.nodes(at: "/PatientCareReport/ePatient/ePatient.18")
        try #require(nodes.count == 2)
        #expect(nodes[0].previousSibling?.name == "ePatient.AgeGroup")
        #expect(nodes[0].textContent == "415-555-1234")
        #expect(nodes[0][attribute: "PhoneNumberType"] == "9913005")
        #expect(nodes[0].nextSibling == nodes[1])
        #expect(nodes[1].textContent == "415-555-5678")
        #expect(nodes[1][attribute: "PhoneNumberType"] == "9913009")
        #expect(nodes[1].nextSibling?.name == "ePatient.25")

        values = try pcr.nemsisValues(at: "/PatientCareReport/ePatient/ePatient.18")
        try #require(values.count == 2)
        #expect(values[0].text == "415-555-1234")
        #expect(values[0].displayText == nil)
        #expect(values[0].attributes?["PhoneNumberType"] == "9913005")
        #expect(values[1].text == "415-555-5678")
        #expect(values[1].displayText == nil)
        #expect(values[1].attributes?["PhoneNumberType"] == "9913009")

        try pcr.setNemsisValues([
            NemsisValue(negative: .unabletoComplete)
        ], at: "/PatientCareReport/ePatient/ePatient.18")
        nodes = try pcr.nodes(at: "/PatientCareReport/ePatient/ePatient.18")
        try #require(nodes.count == 1)
        #expect(nodes[0][attribute: "xsi:nil"] == "true")
        #expect(nodes[0][attribute: "PN"] == NemsisNegative.unabletoComplete.rawValue)

        values = try pcr.nemsisValues(at: "/PatientCareReport/ePatient/ePatient.18")
        try #require(values.count == 1)
        #expect(values[0].isNil)
        #expect(values[0].negative == .unabletoComplete)
        #expect(values[0].displayText == "Unable to Complete")

        try pcr.setNemsisValues([], at: "/PatientCareReport/ePatient/ePatient.18")
        nodes = try pcr.nodes(at: "/PatientCareReport/ePatient/ePatient.18")
        #expect(nodes.count == 0)

        values = try pcr.nemsisValues(at: "/PatientCareReport/ePatient/ePatient.18")
        #expect(values.count == 0)
    }
}
