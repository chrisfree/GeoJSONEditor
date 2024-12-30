//
//  GeoJSONFeature.swift
//  geoJSONEditor
//
//  Created by Christopher Free on 11/22/24.
//

import Foundation

struct GeoJSONFeature: Identifiable, Codable {
    var id: UUID
    var type: GeoJSONFeatureType
    var properties: [String: PropertyValue]?
    var geometry: GeoJSONGeometry?

    enum CodingKeys: String, CodingKey {
        case type, properties, geometry
    }

    init(id: UUID = UUID(), properties: [String: PropertyValue]? = nil, geometry: GeoJSONGeometry? = nil) {
        self.id = id
        self.type = .feature
        self.properties = properties
        self.geometry = geometry
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(GeoJSONFeatureType.self, forKey: .type)
        properties = try container.decodeIfPresent([String: PropertyValue].self, forKey: .properties)
        geometry = try container.decodeIfPresent(GeoJSONGeometry.self, forKey: .geometry)
        id = UUID()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(properties, forKey: .properties)
        try container.encodeIfPresent(geometry, forKey: .geometry)
    }
}

enum GeoJSONFeatureType: String, Codable {
    case feature = "Feature"
}

enum PropertyValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case integer(Int)
    case boolean(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .boolean(boolValue)
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
        case .boolean(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    var stringValue: String {
        switch self {
        case .string(let value): return value
        case .number(let value): return String(value)
        case .integer(let value): return String(value)
        case .boolean(let value): return String(value)
        case .null: return "null"
        }
    }
}
