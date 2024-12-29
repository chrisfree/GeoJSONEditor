//
//  GeoJSONFeature.swift
//  geoJSONEditor
//
//  Created by Christopher Free on 11/22/24.
//

import Foundation

struct GeoJSONFeature: Identifiable, Codable {
    var id: UUID
    let type: String = "Feature" // GeoJSON features always have type "Feature"
    var properties: [String: PropertyValue]
    var geometry: GeoJSONGeometry

    enum CodingKeys: String, CodingKey {
        case type, properties, geometry
    }

    init(id: UUID = UUID(), properties: [String: PropertyValue], geometry: GeoJSONGeometry) {
        self.id = id
        self.properties = properties
        self.geometry = geometry
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedType = try container.decode(String.self, forKey: .type)
        guard decodedType == "Feature" else {
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Invalid feature type")
        }
        properties = try container.decode([String: PropertyValue].self, forKey: .properties)
        geometry = try container.decode(GeoJSONGeometry.self, forKey: .geometry)
        id = UUID()
    }
}

enum PropertyValue: Codable {
    case string(String)
    case number(Double)
    case integer(Int)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let intValue = try? container.decode(Int.self) {
            self = .integer(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self = .number(doubleValue)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .integer(let value):
            try container.encode(value)
        }
    }

    var stringValue: String {
        switch self {
        case .string(let value): return value
        case .number(let value): return String(value)
        case .integer(let value): return String(value)
        }
    }
}
