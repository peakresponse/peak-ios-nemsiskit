//
//  String+Nemsis.swift
//  NemsisKit
//
//  Created by Francis Li on 7/10/26.
//

import Foundation

// swiftlint:disable:next force_try
let correlationIdRegex = try! NSRegularExpression(pattern: "\\[@CorrelationID=\"([^\"]+)\"\\]")

// swiftlint:disable:next force_try
let targetAndIndexRegex = try! NSRegularExpression(pattern: #"([^\[]+)\[(\d+)\]"#, options: [.caseInsensitive])

// swiftlint:disable:next force_try
let indexRegex = try! NSRegularExpression(pattern: "\\[\\d+\\]")

extension String {
    func extractCorrelationId() -> String? {
        let matches = correlationIdRegex.matches(in: self, range: NSRange(location: 0, length: self.count))
        if let match = matches.last, match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: self) {
            return String(self[range])
        }
        return nil
    }

    func extractTargetAndZeroIndex() -> (target: String, index: Int?) {
        var target = self
        var index: Int?
        if let match = targetAndIndexRegex.firstMatch(in: self,
                                                     options: [],
                                                     range: NSRange(self.startIndex..<self.endIndex,
                                                                    in: self)) {
            if match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: self) {
                target = String(self[range])
            }
            if match.numberOfRanges > 2, let range = Range(match.range(at: 2), in: self) {
                index = Int(String(self[range]))
                if index != nil {
                    index = index! - 1
                }
            }
        }
        return (target, index)
    }

    func extractRepeatingAncestorXpath() -> String? {
        let matches = indexRegex.matches(in: self, range: NSRange(location: 0, length: self.count))
        if let match = matches.last {
            return String(self[Range(NSRange(location: 0,
                                             length: match.range.location + match.range.length),
                                     in: self)!])
        }
        return nil
    }
}
