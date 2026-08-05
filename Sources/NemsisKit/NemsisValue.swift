//
//  NemsisValue.swift
//  NemsisKit
//
//  Created by Francis Li on 6/10/26.
//

import Foundation
import Nodal

public enum NemsisBoolean: String {
    // swiftlint:disable:next identifier_name
    case no = "9923001"
    case yes = "9923003"

    var nemsisValue: NemsisValue {
        return NemsisValue(value: rawValue)
    }
}

public enum NemsisCodeType: String {
    case icd10 = "9924001"
    case rxnorm = "9924003"
    case snomed = "9924005"
}

public enum NemsisNegative: String {
    case notApplicable = "7701001"
    case notRecorded = "7701003"
    case notReporting = "7701005"

    case contraindicationNoted = "8801001"
    case deniedByOrder = "8801003"
    case examFindingNotPresent = "8801005"
    case medicationAllergy = "8801007"
    case medicationAlreadyTaken = "8801009"
    case noKnownDrugAllergy = "8801013"
    case noneReported = "8801015"
    case notPerformedbyEMS = "8801017"
    case refused = "8801019"
    case unresponsive = "8801021"
    case unabletoComplete = "8801023"
    case notImmunized = "8801025"
    case orderCriteriaNotMet = "8801027"
    case approximate = "8801029"
    case symptomNotPresent = "8801031"

    var isNotValue: Bool {
        return self.rawValue.starts(with: "7701")
    }

    var isPertinentNegative: Bool {
        return self.rawValue.starts(with: "8801")
    }
}

public class NemsisValue: NSObject {
    @objc public var text: String? {
        didSet {
            isNil = text == nil
        }
    }
    @objc public var displayText: String?
    @objc public var attributes: [String: String]?

    @objc public var isNil: Bool {
        get {
            return (text?.isEmpty ?? true) && attributes?["xsi:nil"] == "true"
        }
        set {
            if newValue {
                if text != nil {
                    text = nil
                }
                if attributes == nil {
                    attributes = [:]
                }
                attributes?["xsi:nil"] = "true"
            } else {
                attributes?.removeValue(forKey: "xsi:nil")
                attributes?.removeValue(forKey: "NV")
            }
        }
    }

    @objc public var negativeValue: String? {
        get { return attributes?["NV"] ?? attributes?["PN"] }
        set { negative = NemsisNegative(rawValue: newValue ?? "") }
    }

    public var negative: NemsisNegative? {
        get { return NemsisNegative(rawValue: negativeValue ?? "") }
        set {
            if let newValue = newValue {
                if attributes == nil {
                    attributes = [:]
                }
                if newValue.isNotValue {
                    isNil = true
                    attributes?["NV"] = newValue.rawValue
                    attributes?.removeValue(forKey: "PN")
                } else if newValue.isPertinentNegative {
                    if text == nil {
                        attributes?["xsi:nil"] = "true"
                    }
                    attributes?["PN"] = newValue.rawValue
                    attributes?.removeValue(forKey: "NV")
                }
            } else {
                attributes?.removeValue(forKey: "NV")
                attributes?.removeValue(forKey: "PN")
            }
        }
    }

    override public init() {
        super.init()
        isNil = true
        negative = .notRecorded
    }

    public init(node: Node) {
        super.init()
        text = node.textContent
        var attributes: [String: String] = [:]
        for attribute in node.attributes {
            attributes[attribute.name] = attribute.value
        }
        self.attributes = attributes
    }

    public init(value: Any? = nil, negativeValue: String? = nil) {
        super.init()
        switch value {
        case let value as String:
            text = value
        case let value as Date:
            var formatted = value
                .formatted(
                    Date.ISO8601FormatStyle(timeZone: .autoupdatingCurrent)
                        .year()
                        .month()
                        .day()
                        .time(includingFractionalSeconds: false)
                        .timeZone(separator: .colon))
            if formatted.hasSuffix("Z") {
                formatted.removeLast()
                formatted = "\(formatted)+00:00"
            }
            text = formatted
        default:
            if let value {
                text = String(describing: value)
            } else {
                text = nil
            }
        }
        self.negativeValue = text == nil && negativeValue == nil ? NemsisNegative.notRecorded.rawValue : negativeValue
    }

    public init(negative: NemsisNegative) {
        super.init()
        self.negative = negative
    }

    override public func isEqual(_ object: Any?) -> Bool {
        if let object = object as? NemsisValue {
            if self === object {
                return true
            }
            if text == object.text && attributes == object.attributes {
                return true
            }
        }
        return false
    }
}
