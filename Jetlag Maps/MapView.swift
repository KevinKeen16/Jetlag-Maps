//
//  MapView.swift
//  Jetlag Maps
//
//  Created by Kevin Keen on 02/01/2026.
//

import SwiftUI
import MapKit

struct MapView: UIViewRepresentable {
    @ObservedObject var viewModel: MapViewModel
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = false
        
        // Add gesture recognizer for drawing
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        panGesture.minimumNumberOfTouches = 1
        panGesture.maximumNumberOfTouches = 1
        panGesture.delegate = context.coordinator
        mapView.addGestureRecognizer(panGesture)
        
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tapGesture)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Lock map movement when lasso tool is selected
        mapView.isScrollEnabled = viewModel.selectedTool != .lasso
        mapView.isZoomEnabled = viewModel.selectedTool != .lasso
        mapView.isPitchEnabled = viewModel.selectedTool != .lasso
        mapView.isRotateEnabled = viewModel.selectedTool != .lasso
        
        // Update map region only if it has actually changed
        if let region = viewModel.selectedRegion {
            let coordinator = context.coordinator
            // Only set region if it's different from what we last set, or if we haven't set one yet
            if let lastRegion = coordinator.lastSetRegion {
                if !coordinator.regionsAreEqual(region, lastRegion) {
                    mapView.setRegion(region, animated: true)
                    coordinator.lastSetRegion = region
                    print("🗺️ Map region updated to: \(region.center.latitude), \(region.center.longitude)")
                }
            } else {
                // First time setting region
                mapView.setRegion(region, animated: true)
                coordinator.lastSetRegion = region
                coordinator.hasSetInitialRegion = true
                print("🗺️ Map region set to: \(region.center.latitude), \(region.center.longitude)")
            }
        }
        
        // Remove all existing overlays and rebuild (but preserve temp drawing overlay and newly added pen circles)
        let existingOverlays = mapView.overlays
        let overlaysToRemove = existingOverlays.filter { overlay in
            // Don't remove the temporary drawing overlay if we're currently drawing
            if let tempOverlay = context.coordinator.tempOverlay,
               overlay === tempOverlay,
               viewModel.isDrawing {
                return false
            }
            // Don't remove overlays that are in crossedOffAreas (they'll be re-added)
            // But we need to remove them to avoid duplicates
            return true
        }
        if !overlaysToRemove.isEmpty {
            mapView.removeOverlays(overlaysToRemove)
            print("🗑️ Removed \(overlaysToRemove.count) existing overlays")
        }
        
        // Add region overlay(s) if region polygons are selected
        if !viewModel.selectedRegionPolygons.isEmpty {
            mapView.addOverlays(viewModel.selectedRegionPolygons)
            let totalPoints = viewModel.selectedRegionPolygons.reduce(0) { $0 + $1.pointCount }
            print("✅ Added \(viewModel.selectedRegionPolygons.count) region polygon overlay(s) with \(totalPoints) total points")
        } else if let regionPolygon = viewModel.selectedRegionPolygon {
            mapView.addOverlay(regionPolygon)
            print("✅ Added region polygon overlay with \(regionPolygon.pointCount) points")
        } else {
            print("⚠️ No region polygon to display")
        }
        
        // Add all crossed off areas
        if !viewModel.crossedOffAreas.isEmpty {
            mapView.addOverlays(viewModel.crossedOffAreas)
            print("✅ Added \(viewModel.crossedOffAreas.count) crossed off areas")
        }
        
        // Update radar pins and circles
        context.coordinator.updateRadarPins(mapView: mapView, viewModel: viewModel)
        
        // Update temporary drawing overlay (must be last so it's on top)
        context.coordinator.updateDrawingOverlay(mapView: mapView, viewModel: viewModel)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: MapView
        var tempOverlay: MKPolygon?
        var lastSetRegion: MKCoordinateRegion?
        var hasSetInitialRegion = false
        var radarAnnotations: [RadarPinAnnotation] = []
        var radarOverlays: [MKPolygon] = []
        
        init(_ parent: MapView) {
            self.parent = parent
        }
        
        func updateRadarPins(mapView: MKMapView, viewModel: MapViewModel) {
            // Remove old radar annotations
            mapView.removeAnnotations(radarAnnotations)
            radarAnnotations = []
            
            // Remove old radar overlays
            mapView.removeOverlays(radarOverlays)
            radarOverlays = []
            
            // Add new radar pins and circles
            for pin in viewModel.radarPins {
                let annotation = RadarPinAnnotation(radarPin: pin)
                mapView.addAnnotation(annotation)
                radarAnnotations.append(annotation)
                
                // Add circle overlay for the radar
                let circle = pin.createCirclePolygon()
                mapView.addOverlay(circle)
                radarOverlays.append(circle)
            }
        }
        
        func regionsAreEqual(_ region1: MKCoordinateRegion, _ region2: MKCoordinateRegion) -> Bool {
            let centerTolerance = 0.0001
            let spanTolerance = 0.0001
            
            return abs(region1.center.latitude - region2.center.latitude) < centerTolerance &&
                   abs(region1.center.longitude - region2.center.longitude) < centerTolerance &&
                   abs(region1.span.latitudeDelta - region2.span.latitudeDelta) < spanTolerance &&
                   abs(region1.span.longitudeDelta - region2.span.longitudeDelta) < spanTolerance
        }
        
        func updateDrawingOverlay(mapView: MKMapView, viewModel: MapViewModel) {
            // Remove old temporary overlay
            if let oldOverlay = tempOverlay {
                mapView.removeOverlay(oldOverlay)
                tempOverlay = nil
            }
            
            // Add new temporary overlay if drawing (lasso tool - show closed polygon)
            if viewModel.isDrawing && !viewModel.currentDrawingPath.isEmpty {
                let newOverlay: MKPolygon
                if viewModel.currentDrawingPath.count >= 3 {
                    // Create closed polygon from path (lasso) - don't simplify or clip for preview
                    var closedPath = viewModel.currentDrawingPath
                    // Close the polygon if not already closed
                    if let first = closedPath.first, let last = closedPath.last {
                        let distance = sqrt(pow(first.latitude - last.latitude, 2) + pow(first.longitude - last.longitude, 2))
                        if distance > 0.0001 {
                            closedPath.append(first)
                        }
                    }
                    // Don't clip during preview - show full polygon
                    newOverlay = MKPolygon(coordinates: closedPath, count: closedPath.count)
                } else if viewModel.currentDrawingPath.count == 2 {
                    // For 2 points, show a line (will become polygon when closed)
                    var path = viewModel.currentDrawingPath
                    path.append(path[0]) // Close it
                    newOverlay = MKPolygon(coordinates: path, count: path.count)
                } else {
                    // Show a small circle for single point
                    let center = viewModel.currentDrawingPath.first!
                    newOverlay = createCirclePolygon(center: center, radius: 0.0005) // Small circle
                }
                
                // Add overlay and ensure it's visible (show full polygon in preview)
                mapView.addOverlay(newOverlay, level: .aboveLabels)
                tempOverlay = newOverlay
                
                // Force immediate refresh - multiple methods to ensure it updates
                mapView.setNeedsDisplay()
                mapView.setNeedsLayout()
                
                // Trigger renderer update
                if let renderer = mapView.renderer(for: newOverlay) as? MKPolygonRenderer {
                    renderer.setNeedsDisplay()
                }
            }
        }
        
        private func createCirclePolygon(center: CLLocationCoordinate2D, radius: Double) -> MKPolygon {
            // Convert radius from meters to degrees (approximate)
            let radiusInDegrees = radius / 111000.0
            let points = 16
            var coordinates: [CLLocationCoordinate2D] = []
            
            for i in 0..<points {
                let angle = Double(i) * 2 * .pi / Double(points)
                let lat = center.latitude + radiusInDegrees * cos(angle)
                let lon = center.longitude + radiusInDegrees * sin(angle)
                coordinates.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
            }
            
            // Close the circle
            if let first = coordinates.first {
                coordinates.append(first)
            }
            
            return MKPolygon(coordinates: coordinates, count: coordinates.count)
        }
        
        private func createTempPolygonFromPath(_ path: [CLLocationCoordinate2D], radius: Double) -> MKPolygon {
            guard path.count >= 2 else {
                let center = path.first ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)
                return createCirclePolygon(center: center, radius: radius)
            }
            
            // For lasso tool: create a closed polygon from the path
            // Don't simplify during drawing for real-time preview - only simplify on finish
            var closedPath = path
            
            // Ensure the polygon is closed by connecting start and end
            if closedPath.count >= 3 {
                // Close the polygon if not already closed
                if let first = closedPath.first, let last = closedPath.last {
                    let distance = sqrt(pow(first.latitude - last.latitude, 2) + pow(first.longitude - last.longitude, 2))
                    if distance > 0.0001 { // Not closed (points are more than ~11m apart)
                        closedPath.append(first)
                    }
                }
                return MKPolygon(coordinates: closedPath, count: closedPath.count)
            }
            
            // Fallback for very short paths
            return MKPolygon(coordinates: path, count: path.count)
        }
        
        // Simplify path using Douglas-Peucker algorithm (simplified version)
        private func simplifyPath(_ path: [CLLocationCoordinate2D], tolerance: Double) -> [CLLocationCoordinate2D] {
            guard path.count > 2 else { return path }
            
            // Simple simplification: remove points that are too close together
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
        
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard parent.viewModel.selectedTool == .lasso else { return }
            guard let mapView = gesture.view as? MKMapView else { return }
            
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            
            switch gesture.state {
            case .began:
                // Start drawing - allow starting anywhere, will clip later
                parent.viewModel.isDrawing = true
                parent.viewModel.currentDrawingPath = [coordinate]
                // Update immediately on main thread
                updateDrawingOverlay(mapView: mapView, viewModel: parent.viewModel)
            case .changed:
                if parent.viewModel.isDrawing {
                    // Add all coordinates - allow crossing border, will clip polygon later
                    parent.viewModel.currentDrawingPath.append(coordinate)
                    // Update overlay immediately - no async delay for real-time feedback
                    updateDrawingOverlay(mapView: mapView, viewModel: parent.viewModel)
                }
            case .ended, .cancelled:
                parent.viewModel.finishDrawing()
                updateDrawingOverlay(mapView: mapView, viewModel: parent.viewModel)
            default:
                break
            }
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            
            // Check if tapping on a radar pin annotation
            let tappedAnnotations = mapView.annotations.filter { annotation in
                if let pinAnnotation = annotation as? RadarPinAnnotation {
                    let annotationPoint = mapView.convert(pinAnnotation.coordinate, toPointTo: mapView)
                    let distance = sqrt(pow(annotationPoint.x - point.x, 2) + pow(annotationPoint.y - point.y, 2))
                    return distance < 30 // 30 point tap radius
                }
                return false
            }
            
            if let tappedAnnotation = tappedAnnotations.first as? RadarPinAnnotation {
                // Tapped on a radar pin - only allow interaction if pending
                if tappedAnnotation.radarPin.status == .pending {
                    parent.viewModel.selectedRadarPin = tappedAnnotation.radarPin
                    parent.viewModel.showHitMissDialog = true
                }
            } else if parent.viewModel.selectedTool == .radar {
                // Drop a new radar pin only if within play area
                if parent.viewModel.isCoordinateInPlayArea(coordinate) {
                    parent.viewModel.dropRadarPin(at: coordinate)
                }
            }
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
        
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            // Only allow drawing pan gesture when lasso tool is selected
            if gestureRecognizer is UIPanGestureRecognizer {
                return parent.viewModel.selectedTool == .lasso
            }
            return true
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let radarAnnotation = annotation as? RadarPinAnnotation {
                let identifier = "RadarPin"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                
                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                }
                
                annotationView?.annotation = annotation
                
                // Customize appearance based on status
                if let markerView = annotationView as? MKMarkerAnnotationView {
                    switch radarAnnotation.radarPin.status {
                    case .pending:
                        markerView.markerTintColor = .orange
                        markerView.glyphImage = UIImage(systemName: "questionmark.circle.fill")
                    case .hit:
                        markerView.markerTintColor = .green
                        markerView.glyphImage = UIImage(systemName: "checkmark.circle.fill")
                    case .miss:
                        markerView.markerTintColor = .red
                        markerView.glyphImage = UIImage(systemName: "xmark.circle.fill")
                    }
                }
                
                return annotationView
            }
            
            return nil
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                
                // Check if this is the temporary drawing overlay
                if let tempOverlay = self.tempOverlay {
                    // Check by reference first
                    if polygon === tempOverlay {
                        // Temporary drawing overlay (more visible)
                        renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.4)
                        renderer.strokeColor = UIColor.systemBlue
                        renderer.lineWidth = 3
                        return renderer
                    }
                    
                    // Also check by coordinates if reference doesn't match (in case overlay was recreated)
                    if tempOverlay.pointCount == polygon.pointCount && tempOverlay.pointCount > 0 {
                        let tempPoints = tempOverlay.points()
                        let polygonPoints = polygon.points()
                        let tempCenter = tempPoints[0].coordinate
                        let polyCenter = polygonPoints[0].coordinate
                        let distance = sqrt(pow(tempCenter.latitude - polyCenter.latitude, 2) + pow(tempCenter.longitude - polyCenter.longitude, 2))
                        if distance < 0.001 {
                            // Temporary drawing overlay
                            renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.4)
                            renderer.strokeColor = UIColor.systemBlue
                            renderer.lineWidth = 3
                            return renderer
                        }
                    }
                }
                
                // Check if this is a radar circle by matching with stored radar overlays
                // Try reference equality first
                if let index = radarOverlays.firstIndex(where: { $0 === polygon }) {
                    let pin = radarAnnotations[index].radarPin
                    switch pin.status {
                    case .pending:
                        renderer.fillColor = UIColor.systemOrange.withAlphaComponent(0.2)
                        renderer.strokeColor = UIColor.systemOrange
                        renderer.lineWidth = 2
                    case .hit:
                        renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.2)
                        renderer.strokeColor = UIColor.darkGray
                        renderer.lineWidth = 2
                    case .miss:
                        renderer.fillColor = UIColor.systemRed.withAlphaComponent(0.2)
                        renderer.strokeColor = UIColor.darkGray
                        renderer.lineWidth = 2
                    }
                    return renderer
                }
                
                // If reference equality fails, try matching by coordinates (for cases where polygons are recreated)
                // Match by checking if polygon center matches any radar pin location
                let polygonPoints = polygon.points()
                var polygonCenterLat: Double = 0
                var polygonCenterLon: Double = 0
                for i in 0..<polygon.pointCount {
                    let coord = polygonPoints[i].coordinate
                    polygonCenterLat += coord.latitude
                    polygonCenterLon += coord.longitude
                }
                polygonCenterLat /= Double(polygon.pointCount)
                polygonCenterLon /= Double(polygon.pointCount)
                
                for (index, annotation) in radarAnnotations.enumerated() {
                    let pin = annotation.radarPin
                    let distance = sqrt(pow(pin.coordinate.latitude - polygonCenterLat, 2) + pow(pin.coordinate.longitude - polygonCenterLon, 2))
                    
                    // Check if this polygon's center is close to the radar pin (within 0.01 degrees, ~1km)
                    if distance < 0.01 {
                        switch pin.status {
                        case .pending:
                            renderer.fillColor = UIColor.systemOrange.withAlphaComponent(0.2)
                            renderer.strokeColor = UIColor.systemOrange
                            renderer.lineWidth = 2
                        case .hit:
                            renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.2)
                            renderer.strokeColor = UIColor.darkGray
                            renderer.lineWidth = 2
                        case .miss:
                            renderer.fillColor = UIColor.systemRed.withAlphaComponent(0.2)
                            renderer.strokeColor = UIColor.darkGray
                            renderer.lineWidth = 2
                        }
                        return renderer
                    }
                }
                
                // Check if this is a crossed off area
                // Try reference equality first
                var isCrossedOff = parent.viewModel.crossedOffAreas.contains(where: { $0 === polygon })
                
                // If reference equality fails, try matching by center coordinates
                if !isCrossedOff {
                    let polygonPoints = polygon.points()
                    var polygonCenterLat: Double = 0
                    var polygonCenterLon: Double = 0
                    for i in 0..<polygon.pointCount {
                        let coord = polygonPoints[i].coordinate
                        polygonCenterLat += coord.latitude
                        polygonCenterLon += coord.longitude
                    }
                    polygonCenterLat /= Double(polygon.pointCount)
                    polygonCenterLon /= Double(polygon.pointCount)
                    
                    // Check if any crossed off area has a similar center
                    for crossedOff in parent.viewModel.crossedOffAreas {
                        let crossedPoints = crossedOff.points()
                        var crossedCenterLat: Double = 0
                        var crossedCenterLon: Double = 0
                        for i in 0..<crossedOff.pointCount {
                            let coord = crossedPoints[i].coordinate
                            crossedCenterLat += coord.latitude
                            crossedCenterLon += coord.longitude
                        }
                        crossedCenterLat /= Double(crossedOff.pointCount)
                        crossedCenterLon /= Double(crossedOff.pointCount)
                        
                        let distance = sqrt(pow(polygonCenterLat - crossedCenterLat, 2) + pow(polygonCenterLon - crossedCenterLon, 2))
                        if distance < 0.001 { // Very close centers
                            isCrossedOff = true
                            break
                        }
                    }
                }
                
                if isCrossedOff {
                    // Marked off areas are greyed out
                    renderer.fillColor = UIColor.systemGray.withAlphaComponent(0.5)
                    renderer.strokeColor = UIColor.systemGray2
                    renderer.lineWidth = 1
                    print("🎨 Rendering crossed off area (\(polygon.pointCount) points)")
                } else {
                    // This is the selected region overlay - outline only, no fill
                    renderer.fillColor = UIColor.clear
                    renderer.strokeColor = UIColor.systemBlue
                    renderer.lineWidth = 3
                    print("🎨 Rendering country border (blue outline, \(polygon.pointCount) points)")
                }
                
                return renderer
            }
            
            print("⚠️ Unknown overlay type: \(type(of: overlay))")
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

