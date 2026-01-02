//
//  CountryData.swift
//  Jetlag Maps
//
//  Created by Kevin Keen on 02/01/2026.
//

import Foundation
import MapKit

struct CountryData: Codable {
    let name: String
    let iso3: String?
    let iso3166_1_alpha_2_codes: String?
    let geoShape: GeoShape
    let geoPoint2D: GeoPoint
    
    enum CodingKeys: String, CodingKey {
        case name
        case iso3
        case iso3166_1_alpha_2_codes = "iso_3166_1_alpha_2_codes"
        case geoShape = "geo_shape"
        case geoPoint2D = "geo_point_2d"
    }
}

struct GeoShape: Codable {
    let type: String?
    let geometry: Geometry
    let properties: [String: AnyCodable]?
    
    enum CodingKeys: String, CodingKey {
        case type
        case geometry
        case properties
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try? container.decode(String.self, forKey: .type)
        geometry = try container.decode(Geometry.self, forKey: .geometry)
        // Properties can be ignored if it fails to decode
        properties = try? container.decodeIfPresent([String: AnyCodable].self, forKey: .properties)
    }
}

// Helper to decode any JSON value
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable value cannot be decoded")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable value cannot be encoded"))
        }
    }
}

struct Geometry: Codable {
    let type: String
    let coordinates: [[[[Double]]]]? // For MultiPolygon: [[[[lon, lat], ...]]]
    let polygonCoordinates: [[[Double]]]? // For Polygon: [[[lon, lat], ...]]
    
    enum CodingKeys: String, CodingKey {
        case type
        case coordinates
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        
        // Try to decode as MultiPolygon first (4 levels)
        if let multiPoly = try? container.decode([[[[Double]]]].self, forKey: .coordinates) {
            coordinates = multiPoly
            polygonCoordinates = nil
        } else if let poly = try? container.decode([[[Double]]].self, forKey: .coordinates) {
            // Decode as Polygon (3 levels)
            coordinates = nil
            polygonCoordinates = poly
        } else {
            coordinates = nil
            polygonCoordinates = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        if let coords = coordinates {
            try container.encode(coords, forKey: .coordinates)
        } else if let polyCoords = polygonCoordinates {
            try container.encode(polyCoords, forKey: .coordinates)
        }
    }
}

struct GeoPoint: Codable {
    let lon: Double
    let lat: Double
}

class CountryBoundaryLoader {
    static func loadCountries() -> [CountryData] {
        guard let url = Bundle.main.url(forResource: "world-administrative-boundaries", withExtension: "json") else {
            print("❌ Could not find world-administrative-boundaries.json in bundle")
            return []
        }
        
        guard let data = try? Data(contentsOf: url) else {
            print("❌ Could not read data from world-administrative-boundaries.json")
            return []
        }
        
        do {
            let countries = try JSONDecoder().decode([CountryData].self, from: data)
            print("✅ Successfully loaded \(countries.count) countries from JSON")
            return countries
        } catch let decodingError as DecodingError {
            print("❌ Decoding error: \(decodingError)")
            switch decodingError {
            case .typeMismatch(let type, let context):
                print("   Type mismatch: expected \(type) at \(context.codingPath)")
            case .valueNotFound(let type, let context):
                print("   Value not found: \(type) at \(context.codingPath)")
            case .keyNotFound(let key, let context):
                print("   Key not found: \(key) at \(context.codingPath)")
            case .dataCorrupted(let context):
                print("   Data corrupted at \(context.codingPath): \(context.debugDescription)")
            @unknown default:
                print("   Unknown decoding error")
            }
            return []
        } catch {
            print("❌ Error decoding JSON: \(error)")
            print("   Error details: \(error.localizedDescription)")
            return []
        }
    }
    
    // Create all polygons from a MultiPolygon (for countries with multiple landmasses)
    static func createAllPolygons(from geometry: Geometry) -> [MKPolygon] {
        guard geometry.type == "MultiPolygon" else {
            // For regular Polygon, return single polygon
            if let polygon = createPolygon(from: geometry) {
                return [polygon]
            }
            return []
        }
        
        guard let coords = geometry.coordinates, !coords.isEmpty else {
            return []
        }
        
        var polygons: [MKPolygon] = []
        
        for polygon in coords {
            if let firstRing = polygon.first {
                let coordinates = firstRing.compactMap { coord -> CLLocationCoordinate2D? in
                    guard coord.count >= 2 else { return nil }
                    return CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
                }
                
                if coordinates.count >= 3 {
                    polygons.append(MKPolygon(coordinates: coordinates, count: coordinates.count))
                }
            }
        }
        
        return polygons
    }
    
    static func createPolygon(from geometry: Geometry) -> MKPolygon? {
        guard geometry.type == "MultiPolygon" || geometry.type == "Polygon" else {
            print("⚠️ Unknown geometry type: \(geometry.type)")
            return nil
        }
        
        var allCoordinates: [CLLocationCoordinate2D] = []
        
        if geometry.type == "MultiPolygon" {
            // MultiPolygon: [[[[lon, lat], ...]]]
            // Structure: [polygon1, polygon2, ...] where each polygon is [[ring1], [ring2], ...]
            // Each ring is [[lon, lat], [lon, lat], ...]
            guard let coords = geometry.coordinates, !coords.isEmpty else {
                print("⚠️ MultiPolygon has no coordinates")
                return nil
            }
            
            // Find the largest polygon (usually the mainland)
            var largestRing: [[Double]]? = nil
            var largestSize = 0
            
            for polygon in coords {
                if let firstRing = polygon.first, firstRing.count > largestSize {
                    largestRing = firstRing
                    largestSize = firstRing.count
                }
            }
            
            guard let ring = largestRing else {
                print("⚠️ MultiPolygon has no valid rings")
                return nil
            }
            
            allCoordinates = ring.compactMap { coord -> CLLocationCoordinate2D? in
                guard coord.count >= 2 else { return nil }
                return CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
            }
            
            print("📐 MultiPolygon: Using largest polygon with \(allCoordinates.count) points (out of \(coords.count) polygons)")
        } else {
            // Polygon: [[[lon, lat], ...]]
            guard let polyCoords = geometry.polygonCoordinates,
                  let firstRing = polyCoords.first else {
                print("⚠️ Polygon has no coordinates")
                return nil
            }
            
            allCoordinates = firstRing.compactMap { coord -> CLLocationCoordinate2D? in
                guard coord.count >= 2 else { return nil }
                return CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
            }
        }
        
        guard allCoordinates.count >= 3 else {
            print("⚠️ Not enough coordinates: \(allCoordinates.count)")
            return nil
        }
        
        print("✅ Created polygon with \(allCoordinates.count) coordinates")
        return MKPolygon(coordinates: allCoordinates, count: allCoordinates.count)
    }
    
    static func findCountry(byName name: String) -> CountryData? {
        let countries = loadCountries()
        let searchName = name.lowercased()
        
        // Try exact match first
        if let exact = countries.first(where: { $0.name.lowercased() == searchName }) {
            print("✅ Found exact match for: \(name) -> \(exact.name)")
            return exact
        }
        
        // Try partial match (e.g., "United States" matches "United States of America")
        if let partial = countries.first(where: { 
            $0.name.lowercased().contains(searchName) || searchName.contains($0.name.lowercased())
        }) {
            print("✅ Found partial match for: \(name) -> \(partial.name)")
            return partial
        }
        
        print("❌ No match found for: \(name)")
        return nil
    }
    
    static func findCountry(byISO2 code: String) -> CountryData? {
        let countries = loadCountries()
        return countries.first { $0.iso3166_1_alpha_2_codes?.lowercased() == code.lowercased() }
    }
}

