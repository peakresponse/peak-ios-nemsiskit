//
//  PatientCareReportCustomElementTests.swift
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
struct PatientCareReportCustomElementTests {
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
    mutating func testCustomElement() throws {
        try pcr.setNemsisValues([
            NemsisValue(value: "MX"),
            NemsisValue(value: "IT")
        ], at: "/PatientCareReport/eHistory/eHistory.904")

        nodes = try pcr.nodes(at: "/PatientCareReport/eCustomResults/eCustomResults.ResultsGroup/" +
                              "eCustomResults.02[text()=\"eHistory.904\"]/..")
        try #require(nodes.count == 1)
        #expect(nodes[0][elements: "eCustomResults.01"].count == 2)
        #expect(nodes[0][elements: "eCustomResults.01"][0].textContent == "MX")
        #expect(nodes[0][elements: "eCustomResults.01"][0].attributes.isEmpty)
        #expect(nodes[0][elements: "eCustomResults.01"][1].textContent == "IT")
        #expect(nodes[0][elements: "eCustomResults.01"][1].attributes.isEmpty)
        #expect(nodes[0][elements: "eCustomResults.03"].count == 0)

        values = try pcr.nemsisValues(at: "/PatientCareReport/eHistory/eHistory.904")
        try #require(values.count == 2)
        #expect(values[0].text == "MX")
        #expect(values[0].attributes?.isEmpty ?? true)
        #expect(values[1].text == "IT")
        #expect(values[1].attributes?.isEmpty ?? true)

        try pcr.setNemsisValues([
            NemsisValue(negative: .refused)
        ], at: "/PatientCareReport/eHistory/eHistory.904")

        nodes = try pcr.nodes(at: "/PatientCareReport/eCustomResults/eCustomResults.ResultsGroup/" +
                              "eCustomResults.02[text()=\"eHistory.904\"]/..")
        try #require(nodes.count == 1)
        try #require(nodes[0][elements: "eCustomResults.01"].count == 1)
        #expect(nodes[0][elements: "eCustomResults.01"][0].textContent == "")
        #expect(nodes[0][elements: "eCustomResults.01"][0][attribute: "xsi:nil"] == "true")
        #expect(nodes[0][elements: "eCustomResults.01"][0][attribute: "PN"] == NemsisNegative.refused.rawValue)
        try #require(nodes[0][elements: "eCustomResults.03"].count == 0)

        values = try pcr.nemsisValues(at: "/PatientCareReport/eHistory/eHistory.904")
        #expect(values.count == 1)
        #expect(values[0].negative == .refused)
    }

    @Test
    mutating func testCustomElementOnGroup() throws {
        try pcr.setNemsisValues([
            NemsisValue(value: "2")
        ], at: "/PatientCareReport/eVitals/eVitals.VitalGroup[1]/eVitals.901")

        print(try pcr.xmlString())

        nodes = try pcr.nodes(at: "/PatientCareReport/eVitals/eVitals.VitalGroup[1]")
        try #require(nodes.count == 1)
        correlationId = nodes[0][attribute: "CorrelationID"]
        #expect(correlationId != nil)

        nodes = try pcr.nodes(at: "/PatientCareReport/eCustomResults/eCustomResults.ResultsGroup" +
                              "/eCustomResults.02[text()=\"eVitals.901\"]/..")
        try #require(nodes.count == 1)
        try #require(nodes[0][elements: "eCustomResults.01"].count == 1)
        #expect(nodes[0][elements: "eCustomResults.01"][0].textContent == "2")
        #expect(nodes[0][elements: "eCustomResults.01"][0].attributes.isEmpty)
        try #require(nodes[0][elements: "eCustomResults.03"].count == 1)
        #expect(nodes[0][elements: "eCustomResults.03"][0].textContent == correlationId)

        values = try pcr.nemsisValues(at: "/PatientCareReport/eVitals/eVitals.VitalGroup[1]/eVitals.901")
        try #require(values.count == 1)
        #expect(values[0].text == "2")
        #expect(values[0].displayText == "+2 Agitated")
        #expect(values[0].attributes?.isEmpty ?? true)

        _ = try pcr.insertNode(at: "/PatientCareReport/eVitals/eVitals.VitalGroup")

        try pcr.setNemsisValues([
            NemsisValue(value: "0")
        ], at: "/PatientCareReport/eVitals/eVitals.VitalGroup[2]/eVitals.901")

        nodes = try pcr.nodes(at: "/PatientCareReport/eVitals/eVitals.VitalGroup[2]")
        try #require(nodes.count == 1)
        correlationId = nodes[0][attribute: "CorrelationID"]
        #expect(correlationId != nil)

        nodes = try pcr.nodes(at: "/PatientCareReport/eCustomResults/eCustomResults.ResultsGroup" +
                              "/eCustomResults.02[text()=\"eVitals.901\"]/..")
        try #require(nodes.count == 2)
        try #require(nodes[1][elements: "eCustomResults.01"].count == 1)
        #expect(nodes[1][elements: "eCustomResults.01"][0].textContent == "0")
        #expect(nodes[1][elements: "eCustomResults.01"][0].attributes.isEmpty)
        try #require(nodes[1][elements: "eCustomResults.03"].count == 1)
        #expect(nodes[1][elements: "eCustomResults.03"][0].textContent == correlationId)

        try pcr.setNemsisValues([], at: "/PatientCareReport/eVitals/eVitals.VitalGroup[1]/eVitals.901")

        nodes = try pcr.nodes(at: "/PatientCareReport/eCustomResults/eCustomResults.ResultsGroup" +
                              "/eCustomResults.02[text()=\"eVitals.901\"]/..")
        try #require(nodes.count == 1)
        try #require(nodes[0][elements: "eCustomResults.01"].count == 1)
        #expect(nodes[0][elements: "eCustomResults.01"][0].textContent == "0")
        #expect(nodes[0][elements: "eCustomResults.01"][0].attributes.isEmpty)
        try #require(nodes[0][elements: "eCustomResults.03"].count == 1)
        #expect(nodes[0][elements: "eCustomResults.03"][0].textContent == correlationId)
    }

    @Test
    mutating func testGroupedCustomElement() throws {
        var node: Node?

        node = try pcr.insertNode(at: "/PatientCareReport/eCustomResults/eCustomResults.ResultsGroup")
        #expect(node != nil)
        correlationId = UUID().uuidString.lowercased()
        node?[attribute: "CorrelationID"] = correlationId

        try pcr.setNemsisValues([
            NemsisValue(value: "2018-01-30T13:01:00-05:00")
        ], at: "/PatientCareReport/ceRestraintGroup[@CorrelationID=\"\(correlationId ?? "")\"]/ceRestraint.01")

        node = try pcr.firstNode(at: "/PatientCareReport/eCustomResults/eCustomResults.ResultsGroup/" +
                                     "eCustomResults.02[text()=\"ceRestraint.01\"]/..")
        #expect(node?[attribute: "CorrelationID"] == correlationId)

        try pcr.setNemsisValues([
            NemsisValue(value: "Stretcher restraint")
        ], at: "/PatientCareReport/ceRestraintGroup[@CorrelationID=\"\(correlationId ?? "")\"]/ceRestraint.02")
        node = try pcr.firstNode(at: "/PatientCareReport/eCustomResults/eCustomResults.ResultsGroup/" +
                                     "eCustomResults.02[text()=\"ceRestraint.02\"]/..")
        #expect(node?[element: "eCustomResults.03"]?.textContent == correlationId)

        try pcr.setNemsisValues([
            NemsisValue(value: "To place pt in ambulance")
        ], at: "/PatientCareReport/ceRestraintGroup[@CorrelationID=\"\(correlationId ?? "")\"]/ceRestraint.03")
        node = try pcr.firstNode(at: "/PatientCareReport/eCustomResults/eCustomResults.ResultsGroup/" +
                                     "eCustomResults.02[text()=\"ceRestraint.03\"]/..")
        #expect(node?[element: "eCustomResults.03"]?.textContent == correlationId)

        node = try pcr.insertNode(at: "/PatientCareReport/eCustomResults/eCustomResults.ResultsGroup")
        #expect(node != nil)
        correlationId = UUID().uuidString.lowercased()
        node?[attribute: "CorrelationID"] = correlationId

        try pcr.setNemsisValues([
            NemsisValue(value: "2018-01-30T13:20:00-05:00")
        ], at: "/PatientCareReport/ceRestraintGroup[@CorrelationID=\"\(correlationId ?? "")\"]/ceRestraint.01")

        try pcr.setNemsisValues([
            NemsisValue(value: "Straight jacket")
        ], at: "/PatientCareReport/ceRestraintGroup[@CorrelationID=\"\(correlationId ?? "")\"]/ceRestraint.02")

        try pcr.setNemsisValues([
            NemsisValue(value: "Pt became combative")
        ], at: "/PatientCareReport/ceRestraintGroup[@CorrelationID=\"\(correlationId ?? "")\"]/ceRestraint.03")

        try pcr.setNemsisValues([
            NemsisValue(value: "2019-01-30T13:20:00-05:00")
        ], at: "/PatientCareReport/ceRestraintGroup[@CorrelationID=\"\(correlationId ?? "")\"]/ceRestraint.01")

        values = try pcr.nemsisValues(at: "/PatientCareReport/ceRestraintGroup/ceRestraint.01")
        #expect(values.count == 2)
        #expect(values[1].attributes?["CorrelationID"] == correlationId)

        values = try pcr.nemsisValues(at: "/PatientCareReport/ceRestraintGroup[@CorrelationID=\"\(correlationId ?? "")\"]/ceRestraint.01")
        #expect(values.count == 1)
        #expect(values[0].attributes?["CorrelationID"] == correlationId)

        print(try pcr.xmlString())
    }
}
