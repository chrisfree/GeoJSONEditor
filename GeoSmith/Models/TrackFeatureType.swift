//
//  TrackFeatureType.swift
//  geoJSONEditor
//
//  Created by Christopher Free on 11/22/24.
//

import Foundation
import SwiftUI

enum TrackFeatureType: String {
    case circuit = "circuit"
    case sectorOne = "sector1"
    case sectorTwo = "sector2"
    case sectorThree = "sector3"
    case drsZone = "drs"

    static func fromFeature(_ feature: GeoJSONFeature) -> TrackFeatureType {
        // Handle optional properties safely
        guard let properties = feature.properties else {
            return .circuit  // Default to circuit if no properties
        }
        
        if let idValue = properties["id"],
           case let .string(id) = idValue {
            switch id {
            case "sector1":
                return .sectorOne
            case "sector2":
                return .sectorTwo
            case "sector3":
                return .sectorThree
            case _ where id.contains("be-"):
                return .circuit
            default:
                // If it's not a sector, check if it's a circuit by looking at other properties
                if properties["Location"] != nil ||
                   properties["length"] != nil {
                    return .circuit
                }
                return .drsZone
            }
        }
        return .circuit // Default to circuit if no id found
    }

    var color: NSColor {
        switch self {
        case .circuit:
            return .systemPurple
        case .sectorOne:
            return .systemRed
        case .sectorTwo:
            return .systemTeal
        case .sectorThree:
            return .systemYellow
        case .drsZone:
            return .systemGreen
        }
    }
}
