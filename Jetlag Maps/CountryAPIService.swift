//
//  CountryAPIService.swift
//  Jetlag Maps
//
//  Created by Kevin Keen on 02/01/2026.
//

import Foundation

struct CountryAPIResponse: Codable {
    let name: CountryName
    let cca2: String? // ISO 3166-1 alpha-2 code
    let cca3: String? // ISO 3166-1 alpha-3 code
    let capital: [String]?
    let region: String?
    let subregion: String?
    let population: Int?
    let latlng: [Double]? // [latitude, longitude]
    let area: Double?
}

struct CountryName: Codable {
    let common: String
    let official: String
}

class CountryAPIService {
    static let baseURL = "https://www.apicountries.com"
    
    // Fetch all countries from the API
    static func fetchAllCountries() async throws -> [CountryAPIResponse] {
        guard let url = URL(string: "\(baseURL)/countries") else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let countries = try JSONDecoder().decode([CountryAPIResponse].self, from: data)
        return countries
    }
    
    // Fetch a specific country by name
    static func fetchCountry(byName name: String) async throws -> [CountryAPIResponse] {
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        guard let url = URL(string: "\(baseURL)/name/\(encodedName)") else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let countries = try JSONDecoder().decode([CountryAPIResponse].self, from: data)
        return countries
    }
    
    // Fetch a specific country by ISO code
    static func fetchCountry(byISOCode code: String) async throws -> CountryAPIResponse? {
        guard let url = URL(string: "\(baseURL)/alpha/\(code.uppercased())") else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let country = try JSONDecoder().decode(CountryAPIResponse.self, from: data)
        return country
    }
    
    // Get country center coordinates from API
    static func getCountryCenter(byISOCode code: String) async -> CLLocationCoordinate2D? {
        do {
            if let country = try await fetchCountry(byISOCode: code),
               let latlng = country.latlng,
               latlng.count >= 2 {
                return CLLocationCoordinate2D(latitude: latlng[0], longitude: latlng[1])
            }
        } catch {
            print("⚠️ Error fetching country center from API: \(error)")
        }
        return nil
    }
}

import MapKit

