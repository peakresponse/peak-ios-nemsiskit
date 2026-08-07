//
//  PatientCareReportAppCustomElementTests.swift
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
struct PatientCareReportAppCustomElementTests {
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
    mutating func testAppCustomElementOnGroup() throws {
        try pcr.setNemsisValues([
            NemsisValue(value: "98.6")
        ], at: "/PatientCareReport/eVitals/eVitals.VitalGroup[1]/eVitals.TemperatureGroup/peakVitals.24")

        nodes = try pcr.nodes(at: "/PatientCareReport/eVitals/eVitals.VitalGroup[1]")
        try #require(nodes.count == 1)
        correlationId = nodes[0][attribute: "CorrelationID"]
        #expect(correlationId != nil)

        nodes = try pcr.appNodes(at: "/PatientCareReport/eCustomResults/eCustomResults.ResultsGroup" +
                                 "/eCustomResults.02[text()=\"peakVitals.24\"]/..")
        try #require(nodes.count == 1)
        try #require(nodes[0][elements: "eCustomResults.01"].count == 1)
        #expect(nodes[0][elements: "eCustomResults.01"][0].textContent == "98.6")
        #expect(nodes[0][elements: "eCustomResults.01"][0].attributes.isEmpty)
        try #require(nodes[0][elements: "eCustomResults.03"].count == 1)
        #expect(nodes[0][elements: "eCustomResults.03"][0].textContent == correlationId)

        values = try pcr.nemsisValues(at: "/PatientCareReport/eVitals/eVitals.VitalGroup[1]/eVitals.TemperatureGroup/peakVitals.24")
        try #require(values.count == 1)
        #expect(values[0].text == "98.6")
        #expect(values[0].displayText == nil)
        #expect(values[0].attributes?.isEmpty ?? true)

        _ = try pcr.insertNode(at: "/PatientCareReport/eVitals/eVitals.VitalGroup")

        try pcr.setNemsisValues([
            NemsisValue(value: "100.1")
        ], at: "/PatientCareReport/eVitals/eVitals.VitalGroup[2]/eVitals.TemperatureGroup/peakVitals.24")

        nodes = try pcr.nodes(at: "/PatientCareReport/eVitals/eVitals.VitalGroup[2]")
        try #require(nodes.count == 1)
        correlationId = nodes[0][attribute: "CorrelationID"]
        #expect(correlationId != nil)

        nodes = try pcr.appNodes(at: "/PatientCareReport/eCustomResults/eCustomResults.ResultsGroup" +
                                 "/eCustomResults.02[text()=\"peakVitals.24\"]/..")
        try #require(nodes.count == 2)
        try #require(nodes[1][elements: "eCustomResults.01"].count == 1)
        #expect(nodes[1][elements: "eCustomResults.01"][0].textContent == "100.1")
        #expect(nodes[1][elements: "eCustomResults.01"][0].attributes.isEmpty)
        try #require(nodes[1][elements: "eCustomResults.03"].count == 1)
        #expect(nodes[1][elements: "eCustomResults.03"][0].textContent == correlationId)

        try pcr.setNemsisValues([], at: "/PatientCareReport/eVitals/eVitals.VitalGroup[1]/peakVitals.24")

        nodes = try pcr.appNodes(at: "/PatientCareReport/eCustomResults/eCustomResults.ResultsGroup" +
                                 "/eCustomResults.02[text()=\"peakVitals.24\"]/..")
        try #require(nodes.count == 1)
        try #require(nodes[0][elements: "eCustomResults.01"].count == 1)
        #expect(nodes[0][elements: "eCustomResults.01"][0].textContent == "100.1")
        #expect(nodes[0][elements: "eCustomResults.01"][0].attributes.isEmpty)
        try #require(nodes[0][elements: "eCustomResults.03"].count == 1)
        #expect(nodes[0][elements: "eCustomResults.03"][0].textContent == correlationId)
    }
}
