//
//  PatientCareReportExtendedElementTests.swift
//  NemsisKit
//
//  Created by Francis Li on 8/6/26.
//

import Foundation
import Nodal
import SemVer
import Testing

@testable import NemsisKit

@MainActor
struct PatientCareReportExtendedElementTests {
    let version: Nemsis
    let pcr: PatientCareReport
    var nodes: [Node] = []
    var values: [NemsisValue] = []
    var correlationId: String?

    init() throws {
        version = try Nemsis(version: versionString)
        try loadFixtures(version: version)
        pcr = try PatientCareReport(version: version)
    }

    @Test
    mutating func testExtendedElement() throws {
        try pcr.setNemsisValues([
            NemsisValue(value: "4221043")
        ], at: "/PatientCareReport/eDisposition/eDisposition.21")

        nodes = try pcr.nodes(at: "/PatientCareReport/eDisposition/eDisposition.21")
        try #require(nodes.count == 1)
        #expect(nodes[0].textContent == "4221013")
        #expect(nodes[0].attributes.isEmpty)

        nodes = try pcr.nodes(at: "/PatientCareReport/eCustomResults/eCustomResults.ResultsGroup/" +
                              "eCustomResults.02[text()=\"eDisposition.21\"]/..")
        try #require(nodes.count == 1)
        try #require(nodes[0][elements: "eCustomResults.01"].count == 1)
        #expect(nodes[0][elements: "eCustomResults.01"][0].textContent == "4221043")
        #expect(nodes[0][elements: "eCustomResults.01"][0].attributes.isEmpty)
        try #require(nodes[0][elements: "eCustomResults.03"].count == 0)

        values = try pcr.nemsisValues(at: "/PatientCareReport/eDisposition/eDisposition.21")
        try #require(values.count == 1)
        #expect(values[0].text == "4221043")
        #expect(values[0].displayText == "Alternate Care Site")
        #expect(values[0].attributes?.isEmpty ?? true)
    }

    @Test
    mutating func testExtendedElementOnGroup() throws {
        try pcr.setNemsisValues([
            NemsisValue(value: "3325019")
        ], at: "/PatientCareReport/eVitals/eVitals.VitalGroup[1]/eVitals.TemperatureGroup/eVitals.25")

        nodes = try pcr.nodes(at: "/PatientCareReport/eVitals/eVitals.VitalGroup[1]/eVitals.TemperatureGroup/eVitals.25")
        try #require(nodes.count == 1)
        #expect(nodes[0].textContent == "3325011")
        #expect(nodes[0].attributes.isEmpty)

        correlationId = nodes[0].parentElement?.parentElement?[attribute: "CorrelationID"]
        #expect(correlationId != nil)

        nodes = try pcr.nodes(at: "/PatientCareReport/eCustomResults/eCustomResults.ResultsGroup" +
                              "/eCustomResults.02[text()=\"eVitals.25\"]/..")
        try #require(nodes.count == 1)
        try #require(nodes[0][elements: "eCustomResults.01"].count == 1)
        #expect(nodes[0][elements: "eCustomResults.01"][0].textContent == "3325019")
        try #require(nodes[0][elements: "eCustomResults.03"].count == 1)
        #expect(nodes[0][elements: "eCustomResults.03"][0].textContent == correlationId)

        values = try pcr.nemsisValues(at: "/PatientCareReport/eVitals/eVitals.VitalGroup[1]/eVitals.TemperatureGroup/eVitals.25")
        try #require(values.count == 1)
        #expect(values[0].text == "3325019")
        #expect(values[0].displayText == "No Touch (e.g., Infrared)")
        #expect(values[0].attributes?.isEmpty ?? true)

        _ = try pcr.insertNode(at: "/PatientCareReport/eVitals/eVitals.VitalGroup")

        try pcr.setNemsisValues([
            NemsisValue(value: "3325019")
        ], at: "/PatientCareReport/eVitals/eVitals.VitalGroup[2]/eVitals.TemperatureGroup/eVitals.25")

        nodes = try pcr.nodes(at: "/PatientCareReport/eVitals/eVitals.VitalGroup[2]/eVitals.TemperatureGroup/eVitals.25")
        try #require(nodes.count == 1)
        #expect(nodes[0].textContent == "3325011")
        #expect(nodes[0].attributes.isEmpty)

        correlationId = nodes[0].parentElement?.parentElement?[attribute: "CorrelationID"]
        #expect(correlationId != nil)

        nodes = try pcr.nodes(at: "/PatientCareReport/eCustomResults/eCustomResults.ResultsGroup" +
                              "/eCustomResults.02[text()=\"eVitals.25\"]/..")
        try #require(nodes.count == 2)
        try #require(nodes[1][elements: "eCustomResults.01"].count == 1)
        #expect(nodes[1][elements: "eCustomResults.01"][0].textContent == "3325019")
        try #require(nodes[1][elements: "eCustomResults.03"].count == 1)
        #expect(nodes[1][elements: "eCustomResults.03"][0].textContent == correlationId)

        values = try pcr.nemsisValues(at: "/PatientCareReport/eVitals/eVitals.VitalGroup[2]/eVitals.TemperatureGroup/eVitals.25")
        try #require(values.count == 1)
        #expect(values[0].text == "3325019")
        #expect(values[0].displayText == "No Touch (e.g., Infrared)")
        #expect(values[0].attributes?.isEmpty ?? true)

        try pcr.setNemsisValues([
            NemsisValue(value: "3325007")
        ], at: "/PatientCareReport/eVitals/eVitals.VitalGroup[1]/eVitals.TemperatureGroup/eVitals.25")

        nodes = try pcr.nodes(at: "/PatientCareReport/eVitals/eVitals.VitalGroup[2]/eVitals.TemperatureGroup/eVitals.25")
        try #require(nodes.count == 1)
        #expect(nodes[0].textContent == "3325011")
        #expect(nodes[0].attributes.isEmpty)

        nodes = try pcr.nodes(at: "/PatientCareReport/eCustomResults/eCustomResults.ResultsGroup" +
                              "/eCustomResults.02[text()=\"eVitals.25\"]/..")
        try #require(nodes.count == 1)
        try #require(nodes[0][elements: "eCustomResults.01"].count == 1)
        #expect(nodes[0][elements: "eCustomResults.01"][0].textContent == "3325019")
        try #require(nodes[0][elements: "eCustomResults.03"].count == 1)
        #expect(nodes[0][elements: "eCustomResults.03"][0].textContent == correlationId)
    }

    @Test
    mutating func testRepeatingExtendedElementOnGroup() throws {
        try pcr.setNemsisValues([
            NemsisValue(value: "c101"),
            NemsisValue(value: "c103")
        ], at: "/PatientCareReport/eMedications/eMedications.MedicationGroup[1]/eMedications.08")

        nodes = try pcr.nodes(at: "/PatientCareReport/eMedications/eMedications.MedicationGroup[1]/eMedications.08")
        try #require(nodes.count == 2)
        #expect(nodes[0].textContent == "3708035")
        #expect(nodes[0][attribute: "CorrelationID"] != nil)
        #expect(nodes[1].textContent == "3708035")
        #expect(nodes[1][attribute: "CorrelationID"] != nil)

        values = try pcr.nemsisValues(at: "/PatientCareReport/eMedications/eMedications.MedicationGroup[1]/eMedications.08")
        #expect(values.count == 2)
        #expect(values[0].text == "c101")
        #expect(values[0].displayText == "Breathing Rate Change")
        #expect(values[0].attributes?.isEmpty ?? true)
        #expect(values[1].text == "c103")
        #expect(values[1].displayText == "Nose Flaring")
        #expect(values[1].attributes?.isEmpty ?? true)

        _ = try pcr.insertNode(at: "/PatientCareReport/eMedications/eMedications.MedicationGroup")

        try pcr.setNemsisValues([
            NemsisValue(value: "c102"),
            NemsisValue(value: "c104")
        ], at: "/PatientCareReport/eMedications/eMedications.MedicationGroup[2]/eMedications.08")

        nodes = try pcr.nodes(at: "/PatientCareReport/eCustomResults/eCustomResults.ResultsGroup" +
                              "/eCustomResults.02[text()=\"eMedications.08\"]/..")
        #expect(nodes.count == 4)

        nodes = try pcr.nodes(at: "/PatientCareReport/eMedications/eMedications.MedicationGroup[2]/eMedications.08")
        try #require(nodes.count == 2)
        #expect(nodes[0].textContent == "3708035")
        #expect(nodes[0][attribute: "CorrelationID"] != nil)
        #expect(nodes[1].textContent == "3708035")
        #expect(nodes[1][attribute: "CorrelationID"] != nil)

        values = try pcr.nemsisValues(at: "/PatientCareReport/eMedications/eMedications.MedicationGroup[2]/eMedications.08")
        #expect(values.count == 2)
        #expect(values[0].text == "c102")
        #expect(values[0].displayText == "Grunting")
        #expect(values[0].attributes?.isEmpty ?? true)
        #expect(values[1].text == "c104")
        #expect(values[1].displayText == "Wheezing")
        #expect(values[1].attributes?.isEmpty ?? true)

        try pcr.setNemsisValues([], at: "/PatientCareReport/eMedications/eMedications.MedicationGroup[1]/eMedications.08")

        nodes = try pcr.nodes(at: "/PatientCareReport/eCustomResults/eCustomResults.ResultsGroup" +
                              "/eCustomResults.02[text()=\"eMedications.08\"]/..")
        #expect(nodes.count == 2)

        values = try pcr.nemsisValues(at: "/PatientCareReport/eMedications/eMedications.MedicationGroup[1]/eMedications.08")
        try #require(values.count == 1)
        #expect(values[0].isNil)
        #expect(values[0].negative == .notRecorded)

        values = try pcr.nemsisValues(at: "/PatientCareReport/eMedications/eMedications.MedicationGroup[2]/eMedications.08")
        #expect(values.count == 2)
        #expect(values[0].text == "c102")
        #expect(values[0].displayText == "Grunting")
        #expect(values[0].attributes?.isEmpty ?? true)
        #expect(values[1].text == "c104")
        #expect(values[1].displayText == "Wheezing")
        #expect(values[1].attributes?.isEmpty ?? true)
    }
}
