//
//  TrackFeatureType.swift
//  geoJSONEditor
//
//  Created by Christopher Free on 11/22/24.
//

import Foundation
import AppKit

enum TrackFeatureType: String, CaseIterable {
    case circuit = "circuit"
    case sector = "sector"
    case line = "line"
    case area = "area"
    case drsZone = "drs"
    case point = "point"

    static var colorCache: [String: NSColor] = [:]

    static func fromFeature(_ feature: GeoJSONFeature) -> TrackFeatureType {
        if let id = feature.properties["id"]?.stringValue {
            switch id {
            case "sector1":
                return .sector
            case "sector2":
                return .sector
            case "sector3":
                return .sector
            case _ where id.contains("be-"):
                return .circuit
            default:
                // If it's not a sector, check if it's a circuit by looking at other properties
                if feature.properties["Location"] != nil ||
                   feature.properties["length"] != nil {
                    return .circuit
                }
                return .drsZone
            }
        }
        if let typeString = feature.properties["type"]?.stringValue ??
                           feature.properties["Type"]?.stringValue,
           let type = TrackFeatureType(rawValue: typeString.lowercased()) {
            return type
        }
        
        // Default based on geometry type
        switch feature.geometry.type {
        case .point:
            return .point
        case .polygon:
            return .area
        case .lineString:
            return .line
        default:
            return .line // Default fallback
        }
    }

    var color: NSColor {
        // If we have cached color for this instance, return it
        if let cached = TrackFeatureType.colorCache[self.rawValue] {
            return cached
        }
        
        // Generate a unique color based on the rawValue
        let hash = self.rawValue.hash
        let hue = CGFloat(abs(hash) % 360) / 360.0
        let saturation: CGFloat = 0.7
        let brightness: CGFloat = 0.9
        
        let color = NSColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1.0)
        TrackFeatureType.colorCache[self.rawValue] = color
        return color
    }
    
    var baseColor: NSColor {
        switch self {
        case .circuit:
            return .systemRed
        case .sector:
            return .systemBlue
        case .line:
            return .systemGreen
        case .area:
            return .systemOrange
        case .drsZone:
            return .systemTeal
        case .point:
            return .systemPurple
        }
    }
    
    static func uniqueColorForFeature(_ feature: GeoJSONFeature) -> NSColor {
        let featureId = feature.id.uuidString
        if let cachedColor = colorCache[featureId] {
            return cachedColor
        }
        
        let baseColors: [NSColor] = [.systemBlue, .systemGreen, .systemOrange, .systemPink,
                                    .systemPurple, .systemRed, .systemYellow, .systemTeal]
        
        // Generate a unique color based on the feature ID
        let index = colorCache.count % baseColors.count
        let color = baseColors[index].withAlphaComponent(0.8)
        colorCache[featureId] = color
        return color
    }
}
