//
//  NemsisKitTests.swift
//  NemsisKit
//
//  Created by Francis Li on 4/19/26.
//

import Foundation
import Nodal
import SemVer
import Testing

@testable import NemsisKit

let versionString = "3.5.1.251001CP2"

@MainActor
func loadFixtures(version: Nemsis) throws {
    let fixturesURL = Bundle.module.url(forResource: "Fixtures/\(versionString)", withExtension: nil)!
    let xsdsURL = fixturesURL.appendingPathComponent("xsds")
    let xsdURLs = try FileManager.default.contentsOfDirectory(at: xsdsURL, includingPropertiesForKeys: nil)
    for xsdURL in xsdURLs {
        let destURL = version.xsdsDirectoryURL.appendingPathComponent(xsdURL.lastPathComponent)
        if !FileManager.default.fileExists(atPath: destURL.path) {
            try FileManager.default.copyItem(at: xsdURL, to: destURL)
        }
    }
    let schsURL = fixturesURL.appendingPathComponent("schs")
    let schURLs = try FileManager.default.contentsOfDirectory(at: schsURL, includingPropertiesForKeys: nil)
    for schURL in schURLs {
        let destURL = version.schsDirectoryURL.appendingPathComponent(schURL.lastPathComponent)
        if !FileManager.default.fileExists(atPath: destURL.path) {
            try FileManager.default.copyItem(at: schURL, to: destURL)
        }
    }
    let customURL = fixturesURL.appendingPathComponent("custom")
    let customURLs = try FileManager.default.contentsOfDirectory(at: customURL, includingPropertiesForKeys: nil)
    for customURL in customURLs {
        let destURL = version.customDirectoryURL.appendingPathComponent(customURL.lastPathComponent)
        if FileManager.default.fileExists(atPath: destURL.path) {
            _ = try? FileManager.default.removeItem(at: destURL)
        }
        try FileManager.default.copyItem(at: customURL, to: destURL)
    }
}

@MainActor // swiftlint:disable:next type_body_length
struct NemsisKitTests {
    let version: Nemsis

    init() throws {
        version = try Nemsis(version: versionString)
        try loadFixtures(version: version)
    }

    @Test
    func testNemsisVersion() {
        let v350 = Version(nemsisVersion: "3.5.0.190522")!
        let v350cp5 = Version(nemsisVersion: "3.5.0.250403CP5")!
        #expect(v350 < v350cp5)
        let v350cp6 = Version(nemsisVersion: "3.5.0.251001CP6")!
        #expect(v350cp6 > v350cp5)
    }

    @Test
    func testInsertIntoPCR() async throws {
        let pcr = try PatientCareReport(version: version)
        let ePatient03 = try pcr.insertNode(at: "/PatientCareReport/ePatient/ePatient.PatientNameGroup/ePatient.03")
        let ePatient02 = try pcr.insertNode(at: "/PatientCareReport/ePatient/ePatient.PatientNameGroup/ePatient.02")
        #expect(ePatient02?.nextSibling == ePatient03)

        let ePatient141 = try pcr.insertNode(at: "/PatientCareReport/ePatient/ePatient.14")
        let ePatient142 = try pcr.insertNode(at: "/PatientCareReport/ePatient/ePatient.14")
        #expect(ePatient141?.nextSibling == ePatient142)

        let newVitals = try pcr.insertNode(at: "/PatientCareReport/eVitals/eVitals.VitalGroup")
        #expect(!(newVitals?.elements.isEmpty ?? true))

        try pcr.setNemsisValues([NemsisValue(value: try Date("2026-06-19T15:06:00-07:00", strategy: .iso8601))],
                                at: "/PatientCareReport/eVitals/eVitals.VitalGroup[1]/eVitals.01")
        try pcr.setNemsisValues([NemsisValue(value: "3326001")],
                                at: "/PatientCareReport/eVitals/eVitals.VitalGroup[1]/eVitals.26")

        _ = try pcr.insertNode(at: "/PatientCareReport/eVitals/eVitals.VitalGroup")
        try pcr.setNemsisValues([NemsisValue(value: try Date("2026-06-20T15:06:00-07:00", strategy: .iso8601))],
                                at: "/PatientCareReport/eVitals/eVitals.VitalGroup[2]/eVitals.01")
        try pcr.setNemsisValues([NemsisValue(value: "3326003")],
                                at: "/PatientCareReport/eVitals/eVitals.VitalGroup[2]/eVitals.26")
        var node = try pcr.firstNode(at: "/PatientCareReport/eVitals/eVitals.VitalGroup[1]/eVitals.01")
        #expect(node?.textContent == "2026-06-19T15:06:00-07:00")
        node = try pcr.firstNode(at: "/PatientCareReport/eVitals/eVitals.VitalGroup[1]/eVitals.26")
        #expect(node?.textContent == "3326001")
        node = try pcr.firstNode(at: "/PatientCareReport/eVitals/eVitals.VitalGroup[2]/eVitals.01")
        #expect(node?.textContent == "2026-06-20T15:06:00-07:00")
        node = try pcr.firstNode(at: "/PatientCareReport/eVitals/eVitals.VitalGroup[2]/eVitals.26")
        #expect(node?.textContent == "3326003")

        print(try pcr.xmlString())
    }

    @Test
    func testRemoveFromPCR() async throws {
        let pcr = try PatientCareReport(version: version)
        _ = try pcr.insertNode(at: "/PatientCareReport/ePatient/ePatient.PatientNameGroup/ePatient.02")
        _ = try pcr.insertNode(at: "/PatientCareReport/ePatient/ePatient.PatientNameGroup/ePatient.03")

        try pcr.removeNodes(at: "/PatientCareReport/ePatient/ePatient.PatientNameGroup/ePatient.02")

        var query = try XPathQuery("/PatientCareReport/ePatient/ePatient.PatientNameGroup/ePatient.02")
        #expect(query.firstNodeResult(with: pcr.doc.node) == nil)
        try pcr.removeNodes(at: "/PatientCareReport/ePatient/ePatient.PatientNameGroup/ePatient.03")

        query = try XPathQuery("/PatientCareReport/ePatient/ePatient.PatientNameGroup")
        #expect(query.firstNodeResult(with: pcr.doc.node) == nil)

        _ = try pcr.insertNode(at: "/PatientCareReport/eVitals/eVitals.VitalGroup")
        try pcr.setNemsisValues([NemsisValue(value: try Date("2026-06-19T15:06:00-07:00", strategy: .iso8601))],
                                at: "/PatientCareReport/eVitals/eVitals.VitalGroup[1]/eVitals.01")
        try pcr.setNemsisValues([NemsisValue(value: try Date("2026-06-20T15:06:00-07:00", strategy: .iso8601))],
                                at: "/PatientCareReport/eVitals/eVitals.VitalGroup[2]/eVitals.01")

        try pcr.removeNodes(at: "/PatientCareReport/eVitals/eVitals.VitalGroup[1]")

        var node = try pcr.firstNode(at: "/PatientCareReport/eVitals/eVitals.VitalGroup[1]/eVitals.01")
        #expect(node?.textContent == "2026-06-20T15:06:00-07:00")

        try pcr.removeNodes(at: "/PatientCareReport/eVitals/eVitals.VitalGroup[1]")
        node = try pcr.firstNode(at: "/PatientCareReport/eVitals/eVitals.VitalGroup[1]/eVitals.01")
        #expect(node?.textContent == "")
    }

    @Test
    func testNemsisCustomElements() throws {
        _ = try version.emsDataSetXsd()
        #expect(version.agencyCustomElements[emsDataSetFilename] != nil)
        #expect(version.agencyCustomElements[emsDataSetFilename]?.count == 8)
        #expect(version.appCustomElements[emsDataSetFilename] != nil)
        #expect(version.appCustomElements[emsDataSetFilename]?.count == 1)

        let (baseType, enumeration, negatives, _) = try version.emsElementTypeInfo(named: "eHistory.904")
        #expect(baseType == "other")
        #expect(enumeration == nil)
        #expect(negatives?.count == 3)
        #expect(negatives?[0].label == "Refused")
        #expect(negatives?[0].value == "8801019")
        #expect(negatives?[1].label == "Unable to Complete")
        #expect(negatives?[1].value == "8801023")
        #expect(negatives?[2].label == "Unresponsive")
        #expect(negatives?[2].value == "8801021")
    }

    @Test
    func testPCRFromURL() async throws {
        let xmlURL = Bundle.module.url(forResource: "Fixtures/\(versionString)/2026-EMS-FailXsd", withExtension: "xml")!
        let pcr = try PatientCareReport(version: version, url: xmlURL)
        let errors = try await version.validate(pcr: pcr)
        print(errors)
    }

    @Test
    func testValidation() async throws {
        let pcr = try PatientCareReport(version: version)
        let errors = try await version.validate(pcr: pcr)
        print(errors)
    }

    @Test
    // swiftlint:disable:next function_body_length
    func testNewPCR() throws {
        let pcr = try PatientCareReport(version: version)
        let xml = try pcr.xmlString()
        #expect(xml.contains("""
    <eRecord>
        <eRecord.01 />
        <eRecord.SoftwareApplicationGroup>
            <eRecord.02 />
            <eRecord.03 />
            <eRecord.04 />
        </eRecord.SoftwareApplicationGroup>
    </eRecord>
    <eResponse>
        <eResponse.AgencyGroup>
            <eResponse.01 />
        </eResponse.AgencyGroup>
        <eResponse.03 xsi:nil="true" NV="7701003" />
        <eResponse.04 xsi:nil="true" NV="7701003" />
        <eResponse.ServiceGroup>
            <eResponse.05 />
        </eResponse.ServiceGroup>
        <eResponse.07 />
        <eResponse.08 xsi:nil="true" NV="7701003" />
        <eResponse.09 xsi:nil="true" NV="7701003" />
        <eResponse.10 xsi:nil="true" NV="7701003" />
        <eResponse.11 xsi:nil="true" NV="7701003" />
        <eResponse.12 xsi:nil="true" NV="7701003" />
        <eResponse.13 />
        <eResponse.14 />
        <eResponse.23 />
        <eResponse.24 xsi:nil="true" NV="7701003" />
    </eResponse>
    <eDispatch>
        <eDispatch.01 />
        <eDispatch.02 xsi:nil="true" NV="7701003" />
    </eDispatch>
    <eTimes>
        <eTimes.01 xsi:nil="true" NV="7701003" />
        <eTimes.03 />
        <eTimes.05 xsi:nil="true" NV="7701003" />
        <eTimes.06 xsi:nil="true" NV="7701003" />
        <eTimes.07 xsi:nil="true" NV="7701003" />
        <eTimes.09 xsi:nil="true" NV="7701003" />
        <eTimes.11 xsi:nil="true" NV="7701003" />
        <eTimes.12 xsi:nil="true" NV="7701003" />
        <eTimes.13 />
    </eTimes>
    <ePatient>
        <ePatient.07 xsi:nil="true" NV="7701003" />
        <ePatient.08 xsi:nil="true" NV="7701003" />
        <ePatient.09 xsi:nil="true" NV="7701003" />
        <ePatient.14 xsi:nil="true" NV="7701003" />
        <ePatient.AgeGroup>
            <ePatient.15 xsi:nil="true" NV="7701003" />
            <ePatient.16 xsi:nil="true" NV="7701003" />
        </ePatient.AgeGroup>
        <ePatient.25 xsi:nil="true" NV="7701003" />
    </ePatient>
    <ePayment>
        <ePayment.01 xsi:nil="true" NV="7701003" />
        <ePayment.50 xsi:nil="true" NV="7701003" />
    </ePayment>
    <eScene>
        <eScene.01 xsi:nil="true" NV="7701003" />
        <eScene.06 xsi:nil="true" NV="7701003" />
        <eScene.07 xsi:nil="true" NV="7701003" />
        <eScene.08 xsi:nil="true" NV="7701003" />
        <eScene.09 xsi:nil="true" NV="7701003" />
        <eScene.18 xsi:nil="true" NV="7701003" />
        <eScene.19 xsi:nil="true" NV="7701003" />
        <eScene.21 xsi:nil="true" NV="7701003" />
    </eScene>
    <eSituation>
        <eSituation.01 xsi:nil="true" NV="7701003" />
        <eSituation.02 xsi:nil="true" NV="7701003" />
        <eSituation.07 xsi:nil="true" NV="7701003" />
        <eSituation.08 xsi:nil="true" NV="7701003" />
        <eSituation.09 xsi:nil="true" NV="7701003" />
        <eSituation.10 xsi:nil="true" NV="7701003" />
        <eSituation.11 xsi:nil="true" NV="7701003" />
        <eSituation.12 xsi:nil="true" NV="7701003" />
        <eSituation.13 xsi:nil="true" NV="7701003" />
        <eSituation.18 xsi:nil="true" NV="7701003" />
        <eSituation.20 xsi:nil="true" NV="7701003" />
    </eSituation>
    <eInjury>
        <eInjury.01 xsi:nil="true" NV="7701003" />
        <eInjury.03 xsi:nil="true" NV="7701003" />
        <eInjury.04 xsi:nil="true" NV="7701003" />
    </eInjury>
    <eArrest>
        <eArrest.01 xsi:nil="true" NV="7701003" />
        <eArrest.02 xsi:nil="true" NV="7701003" />
        <eArrest.03 xsi:nil="true" NV="7701003" />
        <eArrest.04 xsi:nil="true" NV="7701003" />
        <eArrest.07 xsi:nil="true" NV="7701003" />
        <eArrest.09 xsi:nil="true" NV="7701003" />
        <eArrest.11 xsi:nil="true" NV="7701003" />
        <eArrest.12 xsi:nil="true" NV="7701003" />
        <eArrest.14 xsi:nil="true" NV="7701003" />
        <eArrest.16 xsi:nil="true" NV="7701003" />
        <eArrest.17 xsi:nil="true" NV="7701003" />
        <eArrest.18 xsi:nil="true" NV="7701003" />
        <eArrest.20 xsi:nil="true" NV="7701003" />
        <eArrest.21 xsi:nil="true" NV="7701003" />
        <eArrest.22 xsi:nil="true" NV="7701003" />
    </eArrest>
    <eHistory>
        <eHistory.01 xsi:nil="true" NV="7701003" />
        <eHistory.17 xsi:nil="true" NV="7701003" />
    </eHistory>
    <eVitals>
        <eVitals.VitalGroup>
            <eVitals.01 xsi:nil="true" NV="7701003" />
            <eVitals.02 xsi:nil="true" NV="7701003" />
            <eVitals.CardiacRhythmGroup>
                <eVitals.03 xsi:nil="true" NV="7701003" />
                <eVitals.04 xsi:nil="true" NV="7701003" />
                <eVitals.05 xsi:nil="true" NV="7701003" />
            </eVitals.CardiacRhythmGroup>
            <eVitals.BloodPressureGroup>
                <eVitals.06 xsi:nil="true" NV="7701003" />
            </eVitals.BloodPressureGroup>
            <eVitals.HeartRateGroup>
                <eVitals.10 xsi:nil="true" NV="7701003" />
            </eVitals.HeartRateGroup>
            <eVitals.12 xsi:nil="true" NV="7701003" />
            <eVitals.14 xsi:nil="true" NV="7701003" />
            <eVitals.16 xsi:nil="true" NV="7701003" />
            <eVitals.18 xsi:nil="true" NV="7701003" />
            <eVitals.GlasgowScoreGroup>
                <eVitals.19 xsi:nil="true" NV="7701003" />
                <eVitals.20 xsi:nil="true" NV="7701003" />
                <eVitals.21 xsi:nil="true" NV="7701003" />
                <eVitals.22 xsi:nil="true" NV="7701003" />
            </eVitals.GlasgowScoreGroup>
            <eVitals.26 xsi:nil="true" NV="7701003" />
            <eVitals.PainScaleGroup>
                <eVitals.27 xsi:nil="true" NV="7701003" />
            </eVitals.PainScaleGroup>
            <eVitals.StrokeScaleGroup>
                <eVitals.29 xsi:nil="true" NV="7701003" />
                <eVitals.30 xsi:nil="true" NV="7701003" />
            </eVitals.StrokeScaleGroup>
            <eVitals.31 xsi:nil="true" NV="7701003" />
        </eVitals.VitalGroup>
    </eVitals>
    <eProtocols>
        <eProtocols.ProtocolGroup>
            <eProtocols.01 xsi:nil="true" NV="7701003" />
        </eProtocols.ProtocolGroup>
    </eProtocols>
    <eMedications>
        <eMedications.MedicationGroup>
            <eMedications.01 xsi:nil="true" NV="7701003" />
            <eMedications.02 xsi:nil="true" NV="7701003" />
            <eMedications.03 xsi:nil="true" NV="7701003" />
            <eMedications.04 xsi:nil="true" NV="7701003" />
            <eMedications.DosageGroup>
                <eMedications.05 xsi:nil="true" NV="7701003" />
                <eMedications.06 xsi:nil="true" NV="7701003" />
            </eMedications.DosageGroup>
            <eMedications.07 xsi:nil="true" NV="7701003" />
            <eMedications.08 xsi:nil="true" NV="7701003" />
            <eMedications.10 xsi:nil="true" NV="7701003" />
        </eMedications.MedicationGroup>
    </eMedications>
    <eProcedures>
        <eProcedures.ProcedureGroup>
            <eProcedures.01 xsi:nil="true" NV="7701003" />
            <eProcedures.02 xsi:nil="true" NV="7701003" />
            <eProcedures.03 xsi:nil="true" NV="7701003" />
            <eProcedures.05 xsi:nil="true" NV="7701003" />
            <eProcedures.06 xsi:nil="true" NV="7701003" />
            <eProcedures.07 xsi:nil="true" NV="7701003" />
            <eProcedures.08 xsi:nil="true" NV="7701003" />
            <eProcedures.10 xsi:nil="true" NV="7701003" />
        </eProcedures.ProcedureGroup>
    </eProcedures>
    <eDisposition>
        <eDisposition.DestinationGroup>
            <eDisposition.05 xsi:nil="true" NV="7701003" />
            <eDisposition.06 xsi:nil="true" NV="7701003" />
            <eDisposition.07 xsi:nil="true" NV="7701003" />
        </eDisposition.DestinationGroup>
        <eDisposition.IncidentDispositionGroup>
            <eDisposition.27 />
            <eDisposition.28 xsi:nil="true" NV="7701003" />
            <eDisposition.29 xsi:nil="true" NV="7701003" />
            <eDisposition.30 xsi:nil="true" NV="7701003" />
        </eDisposition.IncidentDispositionGroup>
        <eDisposition.16 xsi:nil="true" NV="7701003" />
        <eDisposition.17 xsi:nil="true" NV="7701003" />
        <eDisposition.18 xsi:nil="true" NV="7701003" />
        <eDisposition.19 xsi:nil="true" NV="7701003" />
        <eDisposition.20 xsi:nil="true" NV="7701003" />
        <eDisposition.21 xsi:nil="true" NV="7701003" />
        <eDisposition.22 xsi:nil="true" NV="7701003" />
        <eDisposition.23 xsi:nil="true" NV="7701003" />
        <eDisposition.HospitalTeamActivationGroup>
            <eDisposition.24 xsi:nil="true" NV="7701003" />
            <eDisposition.25 xsi:nil="true" NV="7701003" />
        </eDisposition.HospitalTeamActivationGroup>
        <eDisposition.32 xsi:nil="true" NV="7701003" />
    </eDisposition>
    <eOutcome>
        <eOutcome.01 xsi:nil="true" NV="7701003" />
        <eOutcome.02 xsi:nil="true" NV="7701003" />
        <eOutcome.EmergencyDepartmentProceduresGroup>
            <eOutcome.09 xsi:nil="true" NV="7701003" />
            <eOutcome.19 xsi:nil="true" NV="7701003" />
        </eOutcome.EmergencyDepartmentProceduresGroup>
        <eOutcome.10 xsi:nil="true" NV="7701003" />
        <eOutcome.11 xsi:nil="true" NV="7701003" />
        <eOutcome.HospitalProceduresGroup>
            <eOutcome.12 xsi:nil="true" NV="7701003" />
            <eOutcome.20 xsi:nil="true" NV="7701003" />
        </eOutcome.HospitalProceduresGroup>
        <eOutcome.13 xsi:nil="true" NV="7701003" />
        <eOutcome.16 xsi:nil="true" NV="7701003" />
        <eOutcome.18 xsi:nil="true" NV="7701003" />
    </eOutcome>
"""))
    }
}
