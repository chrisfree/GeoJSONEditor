//
//  GeoJSONFeature.swift
//  geoJSONEditor
//
//  Created by Christopher Free on 11/22/24.
//

import Foundation
import CryptoKit
import SwiftUI

struct GeoJSONFeature: Identifiable, Codable {
    var id: UUID
    let type: String = "Feature" // GeoJSON features always have type "Feature"
    var properties: [String: PropertyValue]
    var geometry: GeoJSONGeometry

    private enum CodingKeys: String, CodingKey {
        case id, type, properties, geometry
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

        // Try to decode the id field if it exists
        if let idString = try? container.decode(String.self, forKey: .id) {
            // Use the provided ID string to create a deterministic UUID
            let idData = idString.data(using: .utf8) ?? Data()
            let hash = SHA256.hash(data: idData)
            let hashData = Data(hash)
            self.id = UUID(data: hashData) ?? UUID()
        } else {
            self.id = UUID()
        }

        self.properties = try container.decode([String: PropertyValue].self, forKey: .properties)
        self.geometry = try container.decode(GeoJSONGeometry.self, forKey: .geometry)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(properties, forKey: .properties)
        try container.encode(geometry, forKey: .geometry)
        try container.encode(id.uuidString, forKey: .id)
    }
}

enum PropertyValue: Codable {
    case string(String)
    case number(Double)
    case integer(Int)
    case object([String: PropertyValue])
    case array([PropertyValue])
    case boolean(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .boolean(boolValue)
        } else if let intValue = try? container.decode(Int.self) {
            self = .integer(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self = .number(doubleValue)
        } else if let objectValue = try? container.decode([String: PropertyValue].self) {
            self = .object(objectValue)
        } else if let arrayValue = try? container.decode([PropertyValue].self) {
            self = .array(arrayValue)
        } else if container.decodeNil() {
            self = .null
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
        case .object(let value):
            try container.encode(value)
        case .array(let value):
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
        case .object(let value): return "Object(\(value.count) properties)"
        case .array(let value): return "Array(\(value.count) items)"
        case .null: return "null"
        }
    }
}

fileprivate extension UUID {
    init?(data: Data) {
        guard data.count >= 16 else { return nil }
        self.init(uuid: (data[0], data[1], data[2], data[3],
                        data[4], data[5], data[6], data[7],
                        data[8], data[9], data[10], data[11],
                        data[12], data[13], data[14], data[15]))
    }
}
