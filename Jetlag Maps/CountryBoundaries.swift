//
//  CountryBoundaries.swift
//  Jetlag Maps
//
//  Created by Kevin Keen on 02/01/2026.
//

import Foundation
import MapKit

struct CountryBoundaries {
    // United States - simplified mainland outline
    static var unitedStates: MKPolygon {
        let coordinates: [CLLocationCoordinate2D] = [
            // West Coast
            CLLocationCoordinate2D(latitude: 32.5, longitude: -117.0), // San Diego
            CLLocationCoordinate2D(latitude: 34.0, longitude: -119.0), // Los Angeles
            CLLocationCoordinate2D(latitude: 37.8, longitude: -122.4), // San Francisco
            CLLocationCoordinate2D(latitude: 45.5, longitude: -123.9), // Portland
            CLLocationCoordinate2D(latitude: 47.6, longitude: -122.3), // Seattle
            CLLocationCoordinate2D(latitude: 48.7, longitude: -122.5), // Bellingham
            // Northern Border
            CLLocationCoordinate2D(latitude: 49.0, longitude: -95.0), // Minnesota border
            CLLocationCoordinate2D(latitude: 49.0, longitude: -67.0), // Maine border
            // East Coast
            CLLocationCoordinate2D(latitude: 44.3, longitude: -68.2), // Maine
            CLLocationCoordinate2D(latitude: 42.3, longitude: -71.0), // Boston
            CLLocationCoordinate2D(latitude: 40.7, longitude: -74.0), // New York
            CLLocationCoordinate2D(latitude: 39.9, longitude: -75.2), // Philadelphia
            CLLocationCoordinate2D(latitude: 38.9, longitude: -77.0), // Washington DC
            CLLocationCoordinate2D(latitude: 35.2, longitude: -80.8), // Charlotte
            CLLocationCoordinate2D(latitude: 30.3, longitude: -81.7), // Jacksonville
            CLLocationCoordinate2D(latitude: 25.8, longitude: -80.1), // Miami
            // Southern Border
            CLLocationCoordinate2D(latitude: 25.8, longitude: -97.4), // Texas border
            CLLocationCoordinate2D(latitude: 31.8, longitude: -106.5), // El Paso
            CLLocationCoordinate2D(latitude: 32.5, longitude: -117.0) // Back to start
        ]
        return MKPolygon(coordinates: coordinates, count: coordinates.count)
    }
    
    // United Kingdom - simplified outline
    static var unitedKingdom: MKPolygon {
        let coordinates: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 50.0, longitude: -5.5), // Southwest
            CLLocationCoordinate2D(latitude: 50.1, longitude: -1.3), // South
            CLLocationCoordinate2D(latitude: 51.5, longitude: 1.4), // Southeast
            CLLocationCoordinate2D(latitude: 52.5, longitude: 1.7), // East
            CLLocationCoordinate2D(latitude: 55.0, longitude: -1.5), // Northeast (Scotland)
            CLLocationCoordinate2D(latitude: 58.6, longitude: -3.1), // North Scotland
            CLLocationCoordinate2D(latitude: 58.0, longitude: -6.2), // Northwest Scotland
            CLLocationCoordinate2D(latitude: 55.0, longitude: -6.0), // Northern Ireland
            CLLocationCoordinate2D(latitude: 53.4, longitude: -6.2), // Ireland border
            CLLocationCoordinate2D(latitude: 52.0, longitude: -5.0), // Wales
            CLLocationCoordinate2D(latitude: 50.0, longitude: -5.5) // Back to start
        ]
        return MKPolygon(coordinates: coordinates, count: coordinates.count)
    }
    
    // France - simplified hexagonal outline
    static var france: MKPolygon {
        let coordinates: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 43.4, longitude: 7.5), // Southeast (Nice)
            CLLocationCoordinate2D(latitude: 45.8, longitude: 6.9), // East (Alps)
            CLLocationCoordinate2D(latitude: 49.4, longitude: 6.4), // Northeast (Strasbourg)
            CLLocationCoordinate2D(latitude: 51.0, longitude: 2.5), // North (Lille)
            CLLocationCoordinate2D(latitude: 48.9, longitude: -1.6), // Northwest (Brittany)
            CLLocationCoordinate2D(latitude: 47.2, longitude: -2.2), // West (Nantes)
            CLLocationCoordinate2D(latitude: 44.8, longitude: -1.2), // Southwest (Bordeaux)
            CLLocationCoordinate2D(latitude: 42.7, longitude: 3.0), // South (Pyrenees)
            CLLocationCoordinate2D(latitude: 43.4, longitude: 7.5) // Back to start
        ]
        return MKPolygon(coordinates: coordinates, count: coordinates.count)
    }
    
    // Germany - simplified outline
    static var germany: MKPolygon {
        let coordinates: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 54.7, longitude: 9.4), // North (Schleswig-Holstein)
            CLLocationCoordinate2D(latitude: 54.9, longitude: 13.4), // Northeast
            CLLocationCoordinate2D(latitude: 50.3, longitude: 15.0), // East (Czech border)
            CLLocationCoordinate2D(latitude: 47.6, longitude: 13.0), // Southeast (Austria border)
            CLLocationCoordinate2D(latitude: 47.5, longitude: 7.6), // Southwest (Switzerland border)
            CLLocationCoordinate2D(latitude: 49.0, longitude: 6.1), // West (France border)
            CLLocationCoordinate2D(latitude: 51.3, longitude: 6.1), // Northwest (Netherlands border)
            CLLocationCoordinate2D(latitude: 54.7, longitude: 9.4) // Back to start
        ]
        return MKPolygon(coordinates: coordinates, count: coordinates.count)
    }
    
    // Japan - simplified main islands outline
    static var japan: MKPolygon {
        let coordinates: [CLLocationCoordinate2D] = [
            // Hokkaido
            CLLocationCoordinate2D(latitude: 45.4, longitude: 141.0), // Northeast
            CLLocationCoordinate2D(latitude: 43.4, longitude: 145.8), // East
            CLLocationCoordinate2D(latitude: 41.8, longitude: 140.7), // Southwest
            // Honshu
            CLLocationCoordinate2D(latitude: 40.8, longitude: 140.7), // North
            CLLocationCoordinate2D(latitude: 38.3, longitude: 141.0), // East coast
            CLLocationCoordinate2D(latitude: 35.7, longitude: 140.8), // Tokyo area
            CLLocationCoordinate2D(latitude: 34.7, longitude: 137.2), // Central
            CLLocationCoordinate2D(latitude: 35.0, longitude: 132.5), // West coast
            CLLocationCoordinate2D(latitude: 34.2, longitude: 130.9), // Southwest
            // Kyushu
            CLLocationCoordinate2D(latitude: 33.2, longitude: 130.4), // North Kyushu
            CLLocationCoordinate2D(latitude: 31.4, longitude: 130.5), // South Kyushu
            CLLocationCoordinate2D(latitude: 31.0, longitude: 131.4), // East Kyushu
            // Shikoku
            CLLocationCoordinate2D(latitude: 33.8, longitude: 134.6), // East Shikoku
            // Back up Honshu
            CLLocationCoordinate2D(latitude: 35.0, longitude: 137.2),
            CLLocationCoordinate2D(latitude: 36.4, longitude: 140.6), // Back to Honshu east
            CLLocationCoordinate2D(latitude: 40.8, longitude: 140.7), // Back to Hokkaido connection
            CLLocationCoordinate2D(latitude: 45.4, longitude: 141.0) // Back to start
        ]
        return MKPolygon(coordinates: coordinates, count: coordinates.count)
    }
    
    // Australia - simplified outline
    static var australia: MKPolygon {
        let coordinates: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: -10.7, longitude: 142.5), // Northeast (Queensland)
            CLLocationCoordinate2D(latitude: -16.9, longitude: 145.8), // East (Cairns)
            CLLocationCoordinate2D(latitude: -28.2, longitude: 153.5), // Southeast (Sydney)
            CLLocationCoordinate2D(latitude: -37.8, longitude: 144.9), // South (Melbourne)
            CLLocationCoordinate2D(latitude: -38.4, longitude: 141.6), // Southwest (Victoria)
            CLLocationCoordinate2D(latitude: -35.1, longitude: 117.9), // West (Perth)
            CLLocationCoordinate2D(latitude: -12.5, longitude: 130.8), // Northwest (Darwin)
            CLLocationCoordinate2D(latitude: -10.7, longitude: 142.5) // Back to start
        ]
        return MKPolygon(coordinates: coordinates, count: coordinates.count)
    }
}

