//
//  NemsisVersion.swift
//  NemsisKit
//
//  Created by Francis Li on 6/5/26.
//

import Foundation
import SemVer

extension Version {
    public init?(nemsisVersion: String) {
        var nemsisVersion = nemsisVersion
        if nemsisVersion.count(where: { $0 == "." }) == 3, let index = nemsisVersion.lastIndex(of: ".") {
            nemsisVersion = nemsisVersion.replacingOccurrences(of: ".",
                                                               with: "-",
                                                               range: index..<nemsisVersion.endIndex)
        }
        self.init(nemsisVersion)
    }
}
