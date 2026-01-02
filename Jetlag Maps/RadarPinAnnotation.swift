//
//  RadarPinAnnotation.swift
//  Jetlag Maps
//
//  Created by Kevin Keen on 02/01/2026.
//

import Foundation
import MapKit

class RadarPinAnnotation: NSObject, MKAnnotation {
    let radarPin: RadarPin
    var coordinate: CLLocationCoordinate2D {
        return radarPin.coordinate
    }
    var title: String? {
        return radarPin.size.displayName
    }
    var subtitle: String? {
        switch radarPin.status {
        case .pending: return "Pending"
        case .hit: return "Hit"
        case .miss: return "Miss"
        }
    }
    
    init(radarPin: RadarPin) {
        self.radarPin = radarPin
        super.init()
    }
}

