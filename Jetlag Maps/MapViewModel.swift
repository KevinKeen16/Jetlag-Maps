//
//  MapViewModel.swift
//  Jetlag Maps
//
//  Created by Kevin Keen on 02/01/2026.
//

import Foundation
import MapKit
import SwiftUI
import Combine

class MapViewModel: ObservableObject {
    @Published var selectedRegion: MKCoordinateRegion?
    @Published var selectedRegionPolygon: MKPolygon?
    @Published var selectedRegionPolygons: [MKPolygon] = [] // For MultiPolygon countries
    @Published var regionName: String = "No region selected"
    @Published var selectedTool: MapTool = .none
    @Published var penSize: PenSize = .medium
    @Published var crossedOffAreas: [MKPolygon] = []
    @Published var hasActiveSession: Bool = false
    @Published var history: [HistoryEntry] = []
    @Published var showHistory = false
    
    // Drawing state
    @Published var isDrawing = false
    @Published var currentDrawingPath: [CLLocationCoordinate2D] = []
    
    // Radar system
    @Published var radarPins: [RadarPin] = []
    @Published var pendingRadarLocation: CLLocationCoordinate2D?
    @Published var showRadarSizePicker = false
    @Published var selectedRadarPin: RadarPin?
    @Published var showHitMissDialog = false
    
    private let sessionKey = "activeSession"
    private let regionNameKey = "savedRegionName"
    private let crossedOffAreasKey = "savedCrossedOffAreas"
    
    init() {
        loadSession()
    }
    
    // Common regions for quick selection - loaded from JSON
    // Uses ISO codes for better matching with API data
    lazy var commonRegions: [(name: String, region: MKCoordinateRegion, polygon: MKPolygon)] = {
        // Use ISO codes for better matching
        let countryISOCodes = ["NL", "US", "GB", "FR", "DE", "JP", "AU"]
        var regions: [(name: String, region: MKCoordinateRegion, polygon: MKPolygon)] = []
        
        for isoCode in countryISOCodes {
            // Try to find by ISO code first, then fall back to common names
            if let countryData = CountryBoundaryLoader.findCountry(byISO2: isoCode) {
                // Create all polygons and use the largest one for the region calculation
                let allPolygons = CountryBoundaryLoader.createAllPolygons(from: countryData.geoShape.geometry)
                guard let mainPolygon = allPolygons.first else { continue }
                
                // Calculate bounding box from all polygons
                var minLat = 90.0, maxLat = -90.0
                var minLon = 180.0, maxLon = -180.0
                
                for polygon in allPolygons {
                    let points = polygon.points()
                    for i in 0..<polygon.pointCount {
                        let coord = points[i].coordinate
                        // Validate coordinates are in valid range
                        guard coord.latitude >= -90 && coord.latitude <= 90,
                              coord.longitude >= -180 && coord.longitude <= 180 else {
                            continue
                        }
                        minLat = min(minLat, coord.latitude)
                        maxLat = max(maxLat, coord.latitude)
                        minLon = min(minLon, coord.longitude)
                        maxLon = max(maxLon, coord.longitude)
                    }
                }
                
                // Calculate deltas
                let latDelta = maxLat - minLat
                var lonDelta = maxLon - minLon
                
                // Handle longitude wrapping (if span > 180, it wraps around)
                if lonDelta > 180 {
                    // Country crosses date line - use the shorter path
                    lonDelta = 360 - lonDelta
                }
                
                // Clamp to valid MapKit ranges
                let finalLatDelta = min(max(latDelta * 1.2, 1.0), 180.0)
                let finalLonDelta = min(max(lonDelta * 1.2, 1.0), 180.0)
                
                // Calculate center
                let centerLat = (minLat + maxLat) / 2
                let centerLon = (minLon + maxLon) / 2
                
                // Normalize center longitude to [-180, 180]
                let normalizedCenterLon = centerLon > 180 ? centerLon - 360 : (centerLon < -180 ? centerLon + 360 : centerLon)
                
                let center = CLLocationCoordinate2D(
                    latitude: centerLat,
                    longitude: normalizedCenterLon
                )
                
                let span = MKCoordinateSpan(
                    latitudeDelta: finalLatDelta,
                    longitudeDelta: finalLonDelta
                )
                
                print("📍 Calculated region: center=(\(centerLat), \(normalizedCenterLon)), span=(\(finalLatDelta), \(finalLonDelta))")
                
                let region = MKCoordinateRegion(center: center, span: span)
                // Use the main polygon for the tuple (but we'll use all polygons when selecting)
                regions.append((countryData.name, region, mainPolygon))
            } else {
                // Fallback to name-based search with exact names from JSON
                let fallbackNames: [String: String] = [
                    "NL": "Netherlands",
                    "US": "United States of America",
                    "GB": "United Kingdom",
                    "FR": "France",
                    "DE": "Germany",
                    "JP": "Japan",
                    "AU": "Australia"
                ]
                
                if let countryName = fallbackNames[isoCode],
                   let countryData = CountryBoundaryLoader.findCountry(byName: countryName) {
                    let allPolygons = CountryBoundaryLoader.createAllPolygons(from: countryData.geoShape.geometry)
                    guard let mainPolygon = allPolygons.first else { continue }
                    
                    // Calculate bounding box from all polygons
                    var minLat = 90.0, maxLat = -90.0
                    var minLon = 180.0, maxLon = -180.0
                    
                    for polygon in allPolygons {
                        let points = polygon.points()
                        for i in 0..<polygon.pointCount {
                            let coord = points[i].coordinate
                            guard coord.latitude >= -90 && coord.latitude <= 90,
                                  coord.longitude >= -180 && coord.longitude <= 180 else {
                                continue
                            }
                            minLat = min(minLat, coord.latitude)
                            maxLat = max(maxLat, coord.latitude)
                            minLon = min(minLon, coord.longitude)
                            maxLon = max(maxLon, coord.longitude)
                        }
                    }
                    
                    let latDelta = maxLat - minLat
                    var lonDelta = maxLon - minLon
                    
                    if lonDelta > 180 {
                        lonDelta = 360 - lonDelta
                    }
                    
                    let finalLatDelta = min(max(latDelta * 1.2, 1.0), 180.0)
                    let finalLonDelta = min(max(lonDelta * 1.2, 1.0), 180.0)
                    
                    let centerLat = (minLat + maxLat) / 2
                    let centerLon = (minLon + maxLon) / 2
                    let normalizedCenterLon = centerLon > 180 ? centerLon - 360 : (centerLon < -180 ? centerLon + 360 : centerLon)
                    
                    let center = CLLocationCoordinate2D(
                        latitude: centerLat,
                        longitude: normalizedCenterLon
                    )
                    
                    let span = MKCoordinateSpan(
                        latitudeDelta: finalLatDelta,
                        longitudeDelta: finalLonDelta
                    )
                    
                    let region = MKCoordinateRegion(center: center, span: span)
                    regions.append((countryData.name, region, mainPolygon))
                } else {
                    print("⚠️ Could not load country with ISO code: \(isoCode)")
                }
            }
        }
        
        print("✅ Loaded \(regions.count) regions from JSON")
        return regions
    }()
    
    // All countries from API (for search/selection)
    @Published var allCountriesFromAPI: [CountryAPIResponse] = []
    
    func loadCountriesFromAPI() async {
        do {
            let countries = try await CountryAPIService.fetchAllCountries()
            await MainActor.run {
                self.allCountriesFromAPI = countries
                print("✅ Loaded \(countries.count) countries from API")
            }
        } catch {
            print("❌ Error loading countries from API: \(error)")
        }
    }
    
    private func calculateBoundingBox(for polygon: MKPolygon) -> (latDelta: Double, lonDelta: Double) {
        var minLat = 90.0
        var maxLat = -90.0
        var minLon = 180.0
        var maxLon = -180.0
        
        let pointCount = polygon.pointCount
        let points = polygon.points()
        
        for i in 0..<pointCount {
            let point = points[i]
            let coord = point.coordinate
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }
        
        return (maxLat - minLat, maxLon - minLon)
    }
    
    func selectRegion(_ region: MKCoordinateRegion, polygon: MKPolygon, name: String) {
        selectRegion(region, polygons: [polygon], name: name)
    }
    
    func selectRegion(_ region: MKCoordinateRegion, polygons: [MKPolygon], name: String) {
        selectedRegion = region
        selectedRegionPolygon = polygons.first // Keep first for compatibility
        selectedRegionPolygons = polygons
        regionName = name
        hasActiveSession = true
        saveSession()
    }
    
    func clearSession() {
        selectedRegion = nil
        selectedRegionPolygon = nil
        selectedRegionPolygons = []
        regionName = "No region selected"
        crossedOffAreas = []
        radarPins = []
        history = []
        hasActiveSession = false
        UserDefaults.standard.removeObject(forKey: sessionKey)
        UserDefaults.standard.removeObject(forKey: regionNameKey)
        UserDefaults.standard.removeObject(forKey: crossedOffAreasKey)
        UserDefaults.standard.removeObject(forKey: "savedHistory")
        UserDefaults.standard.removeObject(forKey: "savedRadarPins")
        print("🗑️ Session cleared")
    }
    
    private func saveSession() {
        guard hasActiveSession, let region = selectedRegion else { return }
        
        // Save region data
        let regionData: [String: Double] = [
            "centerLat": region.center.latitude,
            "centerLon": region.center.longitude,
            "spanLat": region.span.latitudeDelta,
            "spanLon": region.span.longitudeDelta
        ]
        
        UserDefaults.standard.set(true, forKey: sessionKey)
        UserDefaults.standard.set(regionName, forKey: regionNameKey)
        UserDefaults.standard.set(regionData, forKey: "savedRegion")
        
        // Save history
        if let historyData = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(historyData, forKey: "savedHistory")
        }
        
        // Save radar pins
        let radarPinsData = radarPins.map { pin -> [String: Any] in
            var data: [String: Any] = [
                "id": pin.id.uuidString,
                "latitude": pin.coordinate.latitude,
                "longitude": pin.coordinate.longitude,
                "size": pin.size.rawValue,
                "status": pin.status == .pending ? "pending" : (pin.status == .hit ? "hit" : "miss")
            ]
            if let customRadius = pin.customRadius {
                data["customRadius"] = customRadius
            }
            return data
        }
        UserDefaults.standard.set(radarPinsData, forKey: "savedRadarPins")
        
        // Save crossed off areas by serializing their coordinates
        let crossedOffAreasData = crossedOffAreas.map { polygon -> [[Double]] in
            let points = polygon.points()
            var coordinates: [[Double]] = []
            for i in 0..<polygon.pointCount {
                let coord = points[i].coordinate
                coordinates.append([coord.longitude, coord.latitude]) // [lon, lat] format
            }
            return coordinates
        }
        UserDefaults.standard.set(crossedOffAreasData, forKey: crossedOffAreasKey)
        
        print("💾 Session saved: \(regionName) with \(history.count) history entries and \(radarPins.count) radar pins")
    }
    
    private func loadSession() {
        guard UserDefaults.standard.bool(forKey: sessionKey) else {
            print("📭 No saved session found")
            return
        }
        
        // Load region name
        if let savedName = UserDefaults.standard.string(forKey: regionNameKey) {
            regionName = savedName
        }
        
        // Load region
        if let regionData = UserDefaults.standard.dictionary(forKey: "savedRegion") as? [String: Double],
           let centerLat = regionData["centerLat"],
           let centerLon = regionData["centerLon"],
           let spanLat = regionData["spanLat"],
           let spanLon = regionData["spanLon"] {
            
            let center = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
            let span = MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
            let region = MKCoordinateRegion(center: center, span: span)
            
            selectedRegion = region
            
            // Reload polygons for the saved region
            if let countryData = CountryBoundaryLoader.findCountry(byName: regionName) {
                let allPolygons = CountryBoundaryLoader.createAllPolygons(from: countryData.geoShape.geometry)
                selectedRegionPolygons = allPolygons
                selectedRegionPolygon = allPolygons.first
                hasActiveSession = true
                
                // Load history
                if let historyData = UserDefaults.standard.data(forKey: "savedHistory"),
                   let decodedHistory = try? JSONDecoder().decode([HistoryEntry].self, from: historyData) {
                    history = decodedHistory
                    print("✅ Loaded \(history.count) history entries")
                }
                
                // Load radar pins
                if let radarPinsData = UserDefaults.standard.array(forKey: "savedRadarPins") as? [[String: Any]] {
                    radarPins = radarPinsData.compactMap { data -> RadarPin? in
                        guard let lat = data["latitude"] as? Double,
                              let lon = data["longitude"] as? Double,
                              let sizeString = data["size"] as? String,
                              let size = RadarSize(rawValue: sizeString),
                              let statusString = data["status"] as? String else {
                            return nil
                        }
                        
                        let status: RadarStatus = statusString == "pending" ? .pending : (statusString == "hit" ? .hit : .miss)
                        let customRadius = data["customRadius"] as? Double
                        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                        
                        return RadarPin(coordinate: coordinate, size: size, status: status, customRadius: customRadius)
                    }
                    print("✅ Loaded \(radarPins.count) radar pins")
                }
                
                // Load crossed off areas
                if let crossedOffAreasData = UserDefaults.standard.array(forKey: crossedOffAreasKey) as? [[[Double]]] {
                    crossedOffAreas = crossedOffAreasData.compactMap { polygonCoords -> MKPolygon? in
                        let coordinates = polygonCoords.compactMap { coord -> CLLocationCoordinate2D? in
                            guard coord.count >= 2 else { return nil }
                            return CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0]) // [lon, lat] -> (lat, lon)
                        }
                        guard coordinates.count >= 3 else { return nil }
                        return MKPolygon(coordinates: coordinates, count: coordinates.count)
                    }
                    print("✅ Loaded \(crossedOffAreas.count) crossed off areas")
                }
                
                print("✅ Session loaded: \(regionName)")
            }
        }
    }
    
    func selectCountry(byName name: String) {
        print("🔍 Selecting country: \(name)")
        if let countryData = CountryBoundaryLoader.findCountry(byName: name) {
            print("✅ Found country data: \(countryData.name)")
            
            // Create all polygons (for MultiPolygon countries like Netherlands)
            let allPolygons = CountryBoundaryLoader.createAllPolygons(from: countryData.geoShape.geometry)
            
            if !allPolygons.isEmpty {
                print("✅ Created \(allPolygons.count) polygon(s) for \(countryData.name)")
                
                // Calculate bounding box from all polygons
                var minLat = 90.0, maxLat = -90.0
                var minLon = 180.0, maxLon = -180.0
                
                for polygon in allPolygons {
                    let points = polygon.points()
                    for i in 0..<polygon.pointCount {
                        let coord = points[i].coordinate
                        // Validate coordinates are in valid range
                        guard coord.latitude >= -90 && coord.latitude <= 90,
                              coord.longitude >= -180 && coord.longitude <= 180 else {
                            continue
                        }
                        minLat = min(minLat, coord.latitude)
                        maxLat = max(maxLat, coord.latitude)
                        minLon = min(minLon, coord.longitude)
                        maxLon = max(maxLon, coord.longitude)
                    }
                }
                
                // Calculate deltas
                let latDelta = maxLat - minLat
                var lonDelta = maxLon - minLon
                
                // Handle longitude wrapping (if span > 180, it wraps around)
                if lonDelta > 180 {
                    // Country crosses date line - use the shorter path
                    lonDelta = 360 - lonDelta
                }
                
                // Clamp to valid MapKit ranges
                let finalLatDelta = min(max(latDelta * 1.2, 1.0), 180.0)
                let finalLonDelta = min(max(lonDelta * 1.2, 1.0), 180.0)
                
                // Calculate center
                let centerLat = (minLat + maxLat) / 2
                let centerLon = (minLon + maxLon) / 2
                
                // Normalize center longitude to [-180, 180]
                let normalizedCenterLon = centerLon > 180 ? centerLon - 360 : (centerLon < -180 ? centerLon + 360 : centerLon)
                
                // Final validation before creating region
                guard finalLatDelta > 0 && finalLatDelta <= 180,
                      finalLonDelta > 0 && finalLonDelta <= 180,
                      centerLat >= -90 && centerLat <= 90,
                      normalizedCenterLon >= -180 && normalizedCenterLon <= 180 else {
                    print("❌ Invalid region values: latDelta=\(finalLatDelta), lonDelta=\(finalLonDelta), center=(\(centerLat), \(normalizedCenterLon))")
                    print("   Raw values: minLat=\(minLat), maxLat=\(maxLat), minLon=\(minLon), maxLon=\(maxLon)")
                    // Use safe fallback
                    let safeCenter = CLLocationCoordinate2D(latitude: countryData.geoPoint2D.lat, longitude: countryData.geoPoint2D.lon)
                    let safeSpan = MKCoordinateSpan(latitudeDelta: 50.0, longitudeDelta: 50.0)
                    let safeRegion = MKCoordinateRegion(center: safeCenter, span: safeSpan)
                    selectRegion(safeRegion, polygons: allPolygons, name: countryData.name)
                    return
                }
                
                let center = CLLocationCoordinate2D(
                    latitude: centerLat,
                    longitude: normalizedCenterLon
                )
                
                let span = MKCoordinateSpan(
                    latitudeDelta: finalLatDelta,
                    longitudeDelta: finalLonDelta
                )
                
                print("📍 Calculated region: center=(\(centerLat), \(normalizedCenterLon)), span=(\(finalLatDelta), \(finalLonDelta))")
                
                let region = MKCoordinateRegion(center: center, span: span)
                selectRegion(region, polygons: allPolygons, name: countryData.name)
                print("✅ Selected region: \(countryData.name) with \(allPolygons.count) polygon(s)")
            } else {
                print("❌ Failed to create polygons for \(countryData.name)")
            }
        } else {
            print("❌ Country not found: \(name)")
        }
    }
    
    func addCrossedOffArea(_ polygon: MKPolygon) {
        // Find all existing polygons that this new one touches or intersects
        var polygonsToMerge: [MKPolygon] = [polygon]
        var indicesToRemove: [Int] = []
        
        // Check against all existing crossed off areas
        for (index, existingPolygon) in crossedOffAreas.enumerated() {
            if polygonsIntersectOrTouch(polygon, existingPolygon) {
                polygonsToMerge.append(existingPolygon)
                indicesToRemove.append(index)
            }
        }
        
        // Remove the polygons that will be merged (in reverse order to maintain indices)
        for index in indicesToRemove.reversed() {
            crossedOffAreas.remove(at: index)
        }
        
        // Merge all touching polygons into one
        let mergedPolygon = mergePolygons(polygonsToMerge)
        
        // Add the merged polygon
        crossedOffAreas.append(mergedPolygon)
        
        // Add to history
        let description = polygonsToMerge.count > 1 ? 
            "\(polygonsToMerge.count) areas merged" : "Area marked off"
        history.append(HistoryEntry(
            action: .addMarkedArea,
            timestamp: Date(),
            polygon: mergedPolygon,
            description: description
        ))
        if hasActiveSession {
            saveSession()
        }
    }
    
    
    // Radar functions
    func dropRadarPin(at coordinate: CLLocationCoordinate2D) {
        pendingRadarLocation = coordinate
        showRadarSizePicker = true
    }
    
    func createRadarPin(size: RadarSize, customRadius: Double? = nil) {
        guard let location = pendingRadarLocation else { return }
        let pin = RadarPin(coordinate: location, size: size, customRadius: customRadius)
        radarPins.append(pin)
        pendingRadarLocation = nil
        showRadarSizePicker = false
        
        // Add to history
        let sizeText = size == .custom ? (customRadius != nil ? String(format: "%.2f mi", customRadius! / 1609.34) : "Custom") : size.displayName
        history.append(HistoryEntry(
            action: .radarCreated,
            timestamp: Date(),
            polygon: pin.createCirclePolygon(),
            radarPinId: pin.id,
            description: "Radar created: \(sizeText) at (\(String(format: "%.4f", location.latitude)), \(String(format: "%.4f", location.longitude)))"
        ))
        if hasActiveSession {
            saveSession()
        }
    }
    
    func handleRadarHitMiss(pin: RadarPin, isHit: Bool) {
        pin.status = isHit ? .hit : .miss
        
        // Add to history
        let action: HistoryEntry.HistoryAction = isHit ? .radarHit : .radarMiss
        let sizeText = pin.size == .custom ? (pin.customRadius != nil ? String(format: "%.2f mi", pin.customRadius! / 1609.34) : "Custom") : pin.size.displayName
        history.append(HistoryEntry(
            action: action,
            timestamp: Date(),
            polygon: pin.createCirclePolygon(),
            radarPinId: pin.id,
            description: "Radar \(isHit ? "HIT" : "MISS"): \(sizeText) at (\(String(format: "%.4f", pin.coordinate.latitude)), \(String(format: "%.4f", pin.coordinate.longitude)))"
        ))
        
        if isHit {
            // Hit: grey out everything else within the boundary (everything outside the hit circle)
            // Create exclusion zones around the hit circle using 8 sectors for better coverage
            if !selectedRegionPolygons.isEmpty {
                // Calculate bounding box
                var minLat = 90.0, maxLat = -90.0
                var minLon = 180.0, maxLon = -180.0
                
                for polygon in selectedRegionPolygons {
                    let points = polygon.points()
                    for i in 0..<polygon.pointCount {
                        let coord = points[i].coordinate
                        minLat = min(minLat, coord.latitude)
                        maxLat = max(maxLat, coord.latitude)
                        minLon = min(minLon, coord.longitude)
                        maxLon = max(maxLon, coord.longitude)
                    }
                }
                
                let hitRadius = pin.radiusInMeters
                let hitRadiusDegreesLat = hitRadius / 111000.0
                let hitRadiusDegreesLon = hitRadius / (111000.0 * cos(pin.coordinate.latitude * .pi / 180.0))
                let center = pin.coordinate
                
                // Create 8 sectors around the hit circle (like a donut)
                // Top sector (clipped to play area)
                let top = MKPolygon(coordinates: [
                    CLLocationCoordinate2D(latitude: maxLat, longitude: minLon),
                    CLLocationCoordinate2D(latitude: maxLat, longitude: maxLon),
                    CLLocationCoordinate2D(latitude: center.latitude + hitRadiusDegreesLat, longitude: maxLon),
                    CLLocationCoordinate2D(latitude: center.latitude + hitRadiusDegreesLat, longitude: minLon),
                ], count: 4)
                let clippedTop = clipPolygonToPlayArea(top)
                if clippedTop.pointCount >= 3 {
                    addCrossedOffArea(clippedTop)
                }
                
                // Bottom sector (clipped to play area)
                let bottom = MKPolygon(coordinates: [
                    CLLocationCoordinate2D(latitude: center.latitude - hitRadiusDegreesLat, longitude: minLon),
                    CLLocationCoordinate2D(latitude: center.latitude - hitRadiusDegreesLat, longitude: maxLon),
                    CLLocationCoordinate2D(latitude: minLat, longitude: maxLon),
                    CLLocationCoordinate2D(latitude: minLat, longitude: minLon),
                ], count: 4)
                let clippedBottom = clipPolygonToPlayArea(bottom)
                if clippedBottom.pointCount >= 3 {
                    addCrossedOffArea(clippedBottom)
                }
                
                // Left sector (clipped to play area)
                let left = MKPolygon(coordinates: [
                    CLLocationCoordinate2D(latitude: center.latitude + hitRadiusDegreesLat, longitude: minLon),
                    CLLocationCoordinate2D(latitude: center.latitude + hitRadiusDegreesLat, longitude: center.longitude - hitRadiusDegreesLon),
                    CLLocationCoordinate2D(latitude: center.latitude - hitRadiusDegreesLat, longitude: center.longitude - hitRadiusDegreesLon),
                    CLLocationCoordinate2D(latitude: center.latitude - hitRadiusDegreesLat, longitude: minLon),
                ], count: 4)
                let clippedLeft = clipPolygonToPlayArea(left)
                if clippedLeft.pointCount >= 3 {
                    addCrossedOffArea(clippedLeft)
                }
                
                // Right sector (clipped to play area)
                let right = MKPolygon(coordinates: [
                    CLLocationCoordinate2D(latitude: center.latitude + hitRadiusDegreesLat, longitude: center.longitude + hitRadiusDegreesLon),
                    CLLocationCoordinate2D(latitude: center.latitude + hitRadiusDegreesLat, longitude: maxLon),
                    CLLocationCoordinate2D(latitude: center.latitude - hitRadiusDegreesLat, longitude: maxLon),
                    CLLocationCoordinate2D(latitude: center.latitude - hitRadiusDegreesLat, longitude: center.longitude + hitRadiusDegreesLon),
                ], count: 4)
                let clippedRight = clipPolygonToPlayArea(right)
                if clippedRight.pointCount >= 3 {
                    addCrossedOffArea(clippedRight)
                }
            }
        } else {
            // Miss: grey out just this circle (clipped to play area)
            let missCircle = pin.createCirclePolygon()
            let clippedCircle = clipPolygonToPlayArea(missCircle)
            if clippedCircle.pointCount >= 3 {
                addCrossedOffArea(clippedCircle)
            }
        }
        
        selectedRadarPin = nil
        showHitMissDialog = false
        
        if hasActiveSession {
            saveSession()
        }
    }
    
    func removeCrossedOffArea(_ polygon: MKPolygon) {
        if let index = crossedOffAreas.firstIndex(where: { $0 === polygon }) {
            crossedOffAreas.remove(at: index)
            // Add to history
            history.append(HistoryEntry(
                action: .removeMarkedArea,
                timestamp: Date(),
                polygon: polygon,
                description: "Area unmarked"
            ))
            if hasActiveSession {
                saveSession()
            }
        }
    }
    
    func undo() {
        guard let lastEntry = history.popLast() else { return }
        
        switch lastEntry.action {
        case .addMarkedArea:
            // Remove the polygon that was added
            if let polygon = lastEntry.polygon,
               let index = crossedOffAreas.firstIndex(where: { $0 === polygon }) {
                crossedOffAreas.remove(at: index)
            }
        case .removeMarkedArea:
            // Re-add the polygon that was removed
            if let polygon = lastEntry.polygon {
                crossedOffAreas.append(polygon)
            }
        case .radarCreated:
            // Remove the radar pin that was created
            if let radarPinId = lastEntry.radarPinId,
               let index = radarPins.firstIndex(where: { $0.id == radarPinId }) {
                radarPins.remove(at: index)
            }
        case .radarHit, .radarMiss:
            // Revert radar status to pending
            if let radarPinId = lastEntry.radarPinId,
               let pin = radarPins.first(where: { $0.id == radarPinId }) {
                pin.status = .pending
                // Also need to undo the crossed off areas that were added
                // This is complex, so for now we'll just revert the status
            }
        }
        
        if hasActiveSession {
            saveSession()
        }
    }
    
    var canUndo: Bool {
        return !history.isEmpty
    }
    
    // Convert drawing path to a marked area polygon (lasso tool)
    func finishDrawing() {
        guard currentDrawingPath.count >= 3 else {
            currentDrawingPath = []
            isDrawing = false
            return
        }

        // Create a closed polygon from the lasso path
        var path = currentDrawingPath
        
        // Simplify the path to reduce points
        path = simplifyPath(path, tolerance: 0.0001)
        
        // Ensure the polygon is closed
        if let first = path.first, let last = path.last {
            let distance = sqrt(pow(first.latitude - last.latitude, 2) + pow(first.longitude - last.longitude, 2))
            if distance > 0.0001 { // Not closed (points are more than ~11m apart)
                path.append(first)
            }
        }
        
        let polygon = MKPolygon(coordinates: path, count: path.count)
        
        // Clip polygon to play area boundary
        let clippedPolygon = clipPolygonToPlayArea(polygon)
        if clippedPolygon.pointCount >= 3 {
            addCrossedOffArea(clippedPolygon)
        }

        currentDrawingPath = []
        isDrawing = false
    }
    
    // Simplify path by removing points that are too close together
    private func simplifyPath(_ path: [CLLocationCoordinate2D], tolerance: Double) -> [CLLocationCoordinate2D] {
        guard path.count > 2 else { return path }
        
        var simplified: [CLLocationCoordinate2D] = [path[0]]
        
        for i in 1..<path.count - 1 {
            let prev = simplified.last!
            let current = path[i]
            let distance = sqrt(pow(current.latitude - prev.latitude, 2) + pow(current.longitude - prev.longitude, 2))
            if distance > tolerance {
                simplified.append(current)
            }
        }
        
        // Always include the last point
        if let last = path.last {
            simplified.append(last)
        }
        
        return simplified
    }
    
    private func createCirclePolygon(center: CLLocationCoordinate2D, radius: Double) -> MKPolygon {
        // Convert radius from meters to degrees (approximate)
        let radiusInDegreesLat = radius / 111000.0 // 1 degree latitude ≈ 111km
        let radiusInDegreesLon = radius / (111000.0 * cos(center.latitude * .pi / 180.0))
        
        let points = 32 // More points for smoother circle
        var coordinates: [CLLocationCoordinate2D] = []
        
        for i in 0..<points {
            let angle = Double(i) * 2 * .pi / Double(points)
            let lat = center.latitude + radiusInDegreesLat * cos(angle)
            let lon = center.longitude + radiusInDegreesLon * sin(angle)
            coordinates.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
        
        // Close the circle
        if let first = coordinates.first {
            coordinates.append(first)
        }
        
        return MKPolygon(coordinates: coordinates, count: coordinates.count)
    }
    
    // Check if a coordinate is within the play area boundary
    func isCoordinateInPlayArea(_ coordinate: CLLocationCoordinate2D) -> Bool {
        guard !selectedRegionPolygons.isEmpty else { return false }
        
        // Check if coordinate is inside any of the region polygons
        for polygon in selectedRegionPolygons {
            if isPointInPolygon(coordinate, polygon: polygon) {
                return true
            }
        }
        return false
    }
    
    // Point-in-polygon test using ray casting algorithm
    private func isPointInPolygon(_ point: CLLocationCoordinate2D, polygon: MKPolygon) -> Bool {
        let points = polygon.points()
        var inside = false
        var j = polygon.pointCount - 1
        
        for i in 0..<polygon.pointCount {
            let pi = points[i].coordinate
            let pj = points[j].coordinate
            
            if ((pi.latitude > point.latitude) != (pj.latitude > point.latitude)) {
                let intersect = (point.longitude < (pj.longitude - pi.longitude) * (point.latitude - pi.latitude) / (pj.latitude - pi.latitude) + pi.longitude)
                if intersect {
                    inside = !inside
                }
            }
            j = i
        }
        
        return inside
    }
    
    // Clip a polygon to the play area boundary
    func clipPolygonToPlayArea(_ polygon: MKPolygon) -> MKPolygon {
        guard !selectedRegionPolygons.isEmpty else { return polygon }
        
        let polygonPoints = polygon.points()
        var clippedPoints: [CLLocationCoordinate2D] = []
        
        // Process each edge of the polygon
        for i in 0..<polygon.pointCount {
            let currentPoint = polygonPoints[i].coordinate
            let nextIndex = (i + 1) % polygon.pointCount
            let nextPoint = polygonPoints[nextIndex].coordinate
            
            let currentInside = isCoordinateInPlayArea(currentPoint)
            let nextInside = isCoordinateInPlayArea(nextPoint)
            
            if currentInside {
                // Current point is inside, add it
                clippedPoints.append(currentPoint)
            }
            
            // If edge crosses boundary, find intersection
            if currentInside != nextInside {
                // Edge crosses boundary - find intersection point
                if let intersection = findBoundaryIntersection(from: currentPoint, to: nextPoint) {
                    clippedPoints.append(intersection)
                }
            }
        }
        
        // Remove duplicate consecutive points
        var cleanedPoints: [CLLocationCoordinate2D] = []
        for i in 0..<clippedPoints.count {
            let point = clippedPoints[i]
            if cleanedPoints.isEmpty {
                cleanedPoints.append(point)
            } else {
                let lastPoint = cleanedPoints.last!
                let distance = sqrt(pow(point.latitude - lastPoint.latitude, 2) + pow(point.longitude - lastPoint.longitude, 2))
                if distance > 0.0001 { // Only add if not duplicate
                    cleanedPoints.append(point)
                }
            }
        }
        
        // Ensure we have at least 3 points for a valid polygon
        if cleanedPoints.count >= 3 {
            // Close the polygon if needed
            if let first = cleanedPoints.first, let last = cleanedPoints.last {
                let distance = sqrt(pow(first.latitude - last.latitude, 2) + pow(first.longitude - last.longitude, 2))
                if distance > 0.0001 {
                    cleanedPoints.append(first)
                }
            }
            return MKPolygon(coordinates: cleanedPoints, count: cleanedPoints.count)
        }
        
        // If not enough points, return empty polygon
        return MKPolygon(coordinates: [], count: 0)
    }
    
    // Clip a polygon against a single edge (Sutherland-Hodgman algorithm step)
    private func clipPolygonAgainstEdge(_ polygon: MKPolygon, edgeStart: CLLocationCoordinate2D, edgeEnd: CLLocationCoordinate2D) -> MKPolygon {
        let inputPoints = polygon.points()
        var outputPoints: [CLLocationCoordinate2D] = []
        
        if polygon.pointCount == 0 {
            return MKPolygon(coordinates: [], count: 0)
        }
        
        // Calculate edge normal (pointing inside the boundary)
        let edgeDx = edgeEnd.longitude - edgeStart.longitude
        let edgeDy = edgeEnd.latitude - edgeStart.latitude
        let edgeLength = sqrt(edgeDx * edgeDx + edgeDy * edgeDy)
        
        if edgeLength < 1e-10 {
            return polygon // Degenerate edge
        }
        
        // Normal vector (perpendicular, pointing inside)
        let normalX = -edgeDy / edgeLength
        let normalY = edgeDx / edgeLength
        
        // Process each edge of the input polygon
        var prevPoint = inputPoints[polygon.pointCount - 1].coordinate
        
        for i in 0..<polygon.pointCount {
            let currentPoint = inputPoints[i].coordinate
            
            // Check if points are inside the clipping edge
            let prevInside = isPointInsideEdge(prevPoint, edgeStart: edgeStart, edgeEnd: edgeEnd, normalX: normalX, normalY: normalY)
            let currentInside = isPointInsideEdge(currentPoint, edgeStart: edgeStart, edgeEnd: edgeEnd, normalX: normalX, normalY: normalY)
            
            if currentInside {
                if !prevInside {
                    // Previous outside, current inside - add intersection
                    if let intersection = findEdgeIntersection(from: prevPoint, to: currentPoint, edgeStart: edgeStart, edgeEnd: edgeEnd) {
                        outputPoints.append(intersection)
                    }
                }
                outputPoints.append(currentPoint)
            } else if prevInside {
                // Previous inside, current outside - add intersection
                if let intersection = findEdgeIntersection(from: prevPoint, to: currentPoint, edgeStart: edgeStart, edgeEnd: edgeEnd) {
                    outputPoints.append(intersection)
                }
            }
            
            prevPoint = currentPoint
        }
        
        // Close the polygon if needed
        if !outputPoints.isEmpty, let first = outputPoints.first, let last = outputPoints.last {
            let distance = sqrt(pow(first.latitude - last.latitude, 2) + pow(first.longitude - last.longitude, 2))
            if distance > 0.0001 {
                outputPoints.append(first)
            }
        }
        
        if outputPoints.count >= 3 {
            return MKPolygon(coordinates: outputPoints, count: outputPoints.count)
        }
        
        return MKPolygon(coordinates: [], count: 0)
    }
    
    // Check if a point is inside an edge (determine which side is inside using a test point)
    private func isPointInsideEdge(_ point: CLLocationCoordinate2D, edgeStart: CLLocationCoordinate2D, edgeEnd: CLLocationCoordinate2D, normalX: Double, normalY: Double) -> Bool {
        // Use a point known to be inside the boundary to determine which side is "inside"
        // For simplicity, use the center of the selected region
        guard let region = selectedRegion else {
            // Fallback: use normal vector
            let dx = point.longitude - edgeStart.longitude
            let dy = point.latitude - edgeStart.latitude
            return (dx * normalX + dy * normalY) >= 0
        }
        
        // Use region center as reference point (should be inside)
        let referencePoint = region.center
        
        // Check which side of the edge the reference point is on
        let refDx = referencePoint.longitude - edgeStart.longitude
        let refDy = referencePoint.latitude - edgeStart.latitude
        let refSide = refDx * normalX + refDy * normalY
        
        // Check which side the test point is on
        let pointDx = point.longitude - edgeStart.longitude
        let pointDy = point.latitude - edgeStart.latitude
        let pointSide = pointDx * normalX + pointDy * normalY
        
        // Point is inside if it's on the same side as the reference point
        return (refSide >= 0 && pointSide >= 0) || (refSide < 0 && pointSide < 0)
    }
    
    // Find intersection of a line segment with a clipping edge
    private func findEdgeIntersection(from p1: CLLocationCoordinate2D, to p2: CLLocationCoordinate2D, edgeStart: CLLocationCoordinate2D, edgeEnd: CLLocationCoordinate2D) -> CLLocationCoordinate2D? {
        return lineSegmentIntersection(p1: p1, p2: p2, p3: edgeStart, p4: edgeEnd)
    }
    
    // Find intersection point between a line segment and the play area boundary
    private func findBoundaryIntersection(from p1: CLLocationCoordinate2D, to p2: CLLocationCoordinate2D) -> CLLocationCoordinate2D? {
        guard !selectedRegionPolygons.isEmpty else { return nil }
        
        // For each boundary polygon, check if the edge intersects
        for boundaryPolygon in selectedRegionPolygons {
            let boundaryPoints = boundaryPolygon.points()
            
            for i in 0..<boundaryPolygon.pointCount {
                let b1 = boundaryPoints[i].coordinate
                let b2 = boundaryPoints[(i + 1) % boundaryPolygon.pointCount].coordinate
                
                if let intersection = lineSegmentIntersection(p1: p1, p2: p2, p3: b1, p4: b2) {
                    return intersection
                }
            }
        }
        
        // If no intersection found, return midpoint (fallback)
        return CLLocationCoordinate2D(
            latitude: (p1.latitude + p2.latitude) / 2,
            longitude: (p1.longitude + p2.longitude) / 2
        )
    }
    
    // Find intersection point of two line segments
    private func lineSegmentIntersection(p1: CLLocationCoordinate2D, p2: CLLocationCoordinate2D,
                                        p3: CLLocationCoordinate2D, p4: CLLocationCoordinate2D) -> CLLocationCoordinate2D? {
        let x1 = p1.longitude, y1 = p1.latitude
        let x2 = p2.longitude, y2 = p2.latitude
        let x3 = p3.longitude, y3 = p3.latitude
        let x4 = p4.longitude, y4 = p4.latitude
        
        let denom = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
        if abs(denom) < 1e-10 { return nil } // Lines are parallel
        
        let t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / denom
        let u = -((x1 - x2) * (y1 - y3) - (y1 - y2) * (x1 - x3)) / denom
        
        // Check if intersection is within both line segments
        if t >= 0 && t <= 1 && u >= 0 && u <= 1 {
            let x = x1 + t * (x2 - x1)
            let y = y1 + t * (y2 - y1)
            return CLLocationCoordinate2D(latitude: y, longitude: x)
        }
        
        return nil
    }
    
    // Check if two polygons intersect or touch each other
    private func polygonsIntersectOrTouch(_ poly1: MKPolygon, _ poly2: MKPolygon) -> Bool {
        let points1 = poly1.points()
        let points2 = poly2.points()
        
        // Check if any edge of poly1 intersects with any edge of poly2
        for i in 0..<poly1.pointCount {
            let p1 = points1[i].coordinate
            let p2 = points1[(i + 1) % poly1.pointCount].coordinate
            
            for j in 0..<poly2.pointCount {
                let p3 = points2[j].coordinate
                let p4 = points2[(j + 1) % poly2.pointCount].coordinate
                
                // Check if edges intersect
                if lineSegmentIntersection(p1: p1, p2: p2, p3: p3, p4: p4) != nil {
                    return true
                }
            }
        }
        
        // Check if any vertex of poly1 is inside poly2 or vice versa
        for i in 0..<poly1.pointCount {
            if isPointInPolygon(points1[i].coordinate, polygon: poly2) {
                return true
            }
        }
        
        for i in 0..<poly2.pointCount {
            if isPointInPolygon(points2[i].coordinate, polygon: poly1) {
                return true
            }
        }
        
        // Check if polygons are close enough to be considered "touching"
        // (within a small threshold distance)
        let threshold: Double = 0.001 // ~111 meters
        for i in 0..<poly1.pointCount {
            let p1 = points1[i].coordinate
            for j in 0..<poly2.pointCount {
                let p2 = points2[j].coordinate
                let distance = sqrt(pow(p1.latitude - p2.latitude, 2) + pow(p1.longitude - p2.longitude, 2))
                if distance < threshold {
                    return true
                }
            }
        }
        
        // Also check if edges are close (not just vertices)
        for i in 0..<poly1.pointCount {
            let p1 = points1[i].coordinate
            let p2 = points1[(i + 1) % poly1.pointCount].coordinate
            
            for j in 0..<poly2.pointCount {
                let p3 = points2[j].coordinate
                // Check distance from p3 to the edge (p1, p2)
                let dist = distanceFromPointToLineSegment(point: p3, lineStart: p1, lineEnd: p2)
                if dist < threshold {
                    return true
                }
            }
        }
        
        return false
    }
    
    // Calculate distance from a point to a line segment
    private func distanceFromPointToLineSegment(point: CLLocationCoordinate2D, lineStart: CLLocationCoordinate2D, lineEnd: CLLocationCoordinate2D) -> Double {
        let A = point.longitude - lineStart.longitude
        let B = point.latitude - lineStart.latitude
        let C = lineEnd.longitude - lineStart.longitude
        let D = lineEnd.latitude - lineStart.latitude
        
        let dot = A * C + B * D
        let lenSq = C * C + D * D
        var param: Double = -1
        
        if lenSq != 0 {
            param = dot / lenSq
        }
        
        var xx: Double, yy: Double
        
        if param < 0 {
            xx = lineStart.longitude
            yy = lineStart.latitude
        } else if param > 1 {
            xx = lineEnd.longitude
            yy = lineEnd.latitude
        } else {
            xx = lineStart.longitude + param * C
            yy = lineStart.latitude + param * D
        }
        
        let dx = point.longitude - xx
        let dy = point.latitude - yy
        return sqrt(dx * dx + dy * dy)
    }
    
    // Merge multiple polygons into a single polygon using boundary tracing
    private func mergePolygons(_ polygons: [MKPolygon]) -> MKPolygon {
        guard !polygons.isEmpty else {
            return MKPolygon(coordinates: [], count: 0)
        }
        
        if polygons.count == 1 {
            return polygons[0]
        }
        
        // Collect all points and find intersection points
        var allPoints: [CLLocationCoordinate2D] = []
        var intersectionPoints: [CLLocationCoordinate2D] = []
        
        // Add all vertices from all polygons
        for polygon in polygons {
            let points = polygon.points()
            for i in 0..<polygon.pointCount {
                allPoints.append(points[i].coordinate)
            }
        }
        
        // Find intersection points between edges of different polygons
        for i in 0..<polygons.count {
            let poly1 = polygons[i]
            let points1 = poly1.points()
            
            for j in (i + 1)..<polygons.count {
                let poly2 = polygons[j]
                let points2 = poly2.points()
                
                // Check all edges of poly1 against all edges of poly2
                for k in 0..<poly1.pointCount {
                    let p1 = points1[k].coordinate
                    let p2 = points1[(k + 1) % poly1.pointCount].coordinate
                    
                    for l in 0..<poly2.pointCount {
                        let p3 = points2[l].coordinate
                        let p4 = points2[(l + 1) % poly2.pointCount].coordinate
                        
                        if let intersection = lineSegmentIntersection(p1: p1, p2: p2, p3: p3, p4: p4) {
                            intersectionPoints.append(intersection)
                        }
                    }
                }
            }
        }
        
        // Combine all points
        allPoints.append(contentsOf: intersectionPoints)
        
        // Remove duplicate points
        var uniquePoints: [CLLocationCoordinate2D] = []
        for point in allPoints {
            var isDuplicate = false
            for existing in uniquePoints {
                let distance = sqrt(pow(point.latitude - existing.latitude, 2) + pow(point.longitude - existing.longitude, 2))
                if distance < 0.0001 {
                    isDuplicate = true
                    break
                }
            }
            if !isDuplicate {
                uniquePoints.append(point)
            }
        }
        
        // For now, use a convex hull approach to create the merged polygon
        // This ensures all points are encompassed, though it may be slightly larger than the true union
        let hullPoints = convexHull(uniquePoints)
        
        if hullPoints.count >= 3 {
            return MKPolygon(coordinates: hullPoints, count: hullPoints.count)
        }
        
        // Fallback: return the largest polygon
        return polygons.max(by: { $0.pointCount < $1.pointCount }) ?? polygons[0]
    }
    
    // Compute convex hull using Graham scan algorithm
    private func convexHull(_ points: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        guard points.count >= 3 else { return points }
        
        // Find the bottom-most point (or leftmost in case of tie)
        var bottomIndex = 0
        for i in 1..<points.count {
            if points[i].latitude < points[bottomIndex].latitude ||
               (points[i].latitude == points[bottomIndex].latitude && points[i].longitude < points[bottomIndex].longitude) {
                bottomIndex = i
            }
        }
        
        // Sort points by polar angle with respect to bottom point
        let bottomPoint = points[bottomIndex]
        var sortedPoints = points
        sortedPoints.remove(at: bottomIndex)
        sortedPoints.sort { p1, p2 in
            let angle1 = atan2(p1.latitude - bottomPoint.latitude, p1.longitude - bottomPoint.longitude)
            let angle2 = atan2(p2.latitude - bottomPoint.latitude, p2.longitude - bottomPoint.longitude)
            if abs(angle1 - angle2) < 1e-10 {
                let dist1 = pow(p1.latitude - bottomPoint.latitude, 2) + pow(p1.longitude - bottomPoint.longitude, 2)
                let dist2 = pow(p2.latitude - bottomPoint.latitude, 2) + pow(p2.longitude - bottomPoint.longitude, 2)
                return dist1 < dist2
            }
            return angle1 < angle2
        }
        
        // Build convex hull
        var hull: [CLLocationCoordinate2D] = [bottomPoint]
        hull.append(contentsOf: sortedPoints)
        
        // Remove points that create clockwise turns (Graham scan)
        var m = 1
        for i in 2..<hull.count {
            while m > 0 && crossProduct(hull[m-1], hull[m], hull[i]) <= 0 {
                m -= 1
            }
            m += 1
            if m < i {
                hull.swapAt(m, i)
            }
        }
        
        // Return the hull points
        return Array(hull.prefix(m + 1))
    }
    
    // Calculate cross product for three points (for convex hull)
    private func crossProduct(_ o: CLLocationCoordinate2D, _ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        return (a.longitude - o.longitude) * (b.latitude - o.latitude) - (a.latitude - o.latitude) * (b.longitude - o.longitude)
    }
}

enum MapTool: String, CaseIterable {
    case none = "None"
    case radar = "Radar"
    case lasso = "Lasso"
    case crossOff = "Cross Off"
    case erase = "Erase"
    case highlight = "Highlight"
    case measure = "Measure"
    
    var icon: String {
        switch self {
        case .none: return "hand.point.up.left"
        case .radar: return "antenna.radiowaves.left.and.right"
        case .lasso: return "lasso"
        case .crossOff: return "xmark.circle"
        case .erase: return "eraser"
        case .highlight: return "highlighter"
        case .measure: return "ruler"
        }
    }
}

enum RadarSize: String, CaseIterable, Identifiable {
    case quarterMile = "0.25 mi"
    case halfMile = "0.5 mi"
    case oneMile = "1 mi"
    case threeMiles = "3 mi"
    case fiveMiles = "5 mi"
    case tenMiles = "10 mi"
    case twentyFiveMiles = "25 mi"
    case fiftyMiles = "50 mi"
    case custom = "Custom"
    
    var id: String { rawValue }
    
    var radiusInMeters: Double {
        switch self {
        case .quarterMile: return 402.34 // 0.25 miles in meters
        case .halfMile: return 804.67
        case .oneMile: return 1609.34
        case .threeMiles: return 4828.03
        case .fiveMiles: return 8046.72
        case .tenMiles: return 16093.4
        case .twentyFiveMiles: return 40233.6
        case .fiftyMiles: return 80467.2
        case .custom: return 1609.34 // Default to 1 mile, will be set by user
        }
    }
    
    var displayName: String {
        return rawValue
    }
}

enum RadarStatus {
    case pending
    case hit
    case miss
}

class RadarPin: NSObject, Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    var size: RadarSize
    var status: RadarStatus
    var customRadius: Double? // For custom size
    
    init(coordinate: CLLocationCoordinate2D, size: RadarSize, status: RadarStatus = .pending, customRadius: Double? = nil) {
        self.coordinate = coordinate
        self.size = size
        self.status = status
        self.customRadius = customRadius
    }
    
    var radiusInMeters: Double {
        if size == .custom, let custom = customRadius {
            return custom
        }
        return size.radiusInMeters
    }
    
    func createCircle() -> MKCircle {
        return MKCircle(center: coordinate, radius: radiusInMeters)
    }
    
    func createCirclePolygon() -> MKPolygon {
        // Create a polygon approximation of the circle for rendering
        let radius = radiusInMeters
        // Convert meters to degrees (approximate, accounting for latitude)
        let radiusInDegreesLat = radius / 111000.0 // 1 degree latitude ≈ 111km
        let radiusInDegreesLon = radius / (111000.0 * cos(coordinate.latitude * .pi / 180.0))
        
        let points = 64 // More points for smoother circle
        var coordinates: [CLLocationCoordinate2D] = []
        
        for i in 0..<points {
            let angle = Double(i) * 2 * .pi / Double(points)
            let lat = coordinate.latitude + radiusInDegreesLat * cos(angle)
            let lon = coordinate.longitude + radiusInDegreesLon * sin(angle)
            coordinates.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
        
        // Close the circle
        if let first = coordinates.first {
            coordinates.append(first)
        }
        
        return MKPolygon(coordinates: coordinates, count: coordinates.count)
    }
}

enum PenSize: String, CaseIterable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
    
    var radius: Double {
        switch self {
        case .small: return 0.001 // ~100 meters
        case .medium: return 0.005 // ~500 meters
        case .large: return 0.01 // ~1 km
        }
    }
    
    var displayName: String {
        return rawValue
    }
}

// History entry for undo/redo
struct HistoryEntry: Codable, Identifiable {
    let id = UUID()
    let action: HistoryAction
    let timestamp: Date
    let polygon: MKPolygon?
    let radarPinId: UUID?
    let description: String
    
    enum HistoryAction: String, Codable {
        case addMarkedArea
        case removeMarkedArea
        case radarHit
        case radarMiss
        case radarCreated
    }
    
    // Custom encoding/decoding for MKPolygon (which isn't Codable)
    enum CodingKeys: String, CodingKey {
        case action, timestamp, radarPinId, description
    }
    
    init(action: HistoryAction, timestamp: Date, polygon: MKPolygon? = nil, radarPinId: UUID? = nil, description: String = "") {
        self.action = action
        self.timestamp = timestamp
        self.polygon = polygon
        self.radarPinId = radarPinId
        self.description = description
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        action = try container.decode(HistoryAction.self, forKey: .action)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        radarPinId = try container.decodeIfPresent(UUID.self, forKey: .radarPinId)
        description = try container.decode(String.self, forKey: .description)
        polygon = nil // We don't persist polygons, they'll be recreated
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(action, forKey: .action)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(radarPinId, forKey: .radarPinId)
        try container.encode(description, forKey: .description)
    }
}

