import Foundation
import CoreLocation
import UIKit
import Combine
import SwiftUI

struct GraveRecord: Identifiable, Codable, Hashable {

    let id: String
    let firstName: String
    let lastName: String
    let birthYear: Int?
    let deathYear: Int?
    let biography: String?
    let latitude: Double
    let longitude: Double
    let section: String
    let row: Int?
    let plot: Int?

    var fullName: String { "\(firstName) \(lastName)" }

    var lifespan: String {
        switch (birthYear, deathYear) {
        case let (b?, d?): return "\(b) – \(d)"
        case let (b?, nil): return "b. \(b)"
        case let (nil, d?): return "d. \(d)"
        default:           return "Unknown"
        }
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
}

import MapKit

final class GraveAnnotation: NSObject, MKAnnotation {

    let grave: GraveRecord

    var coordinate: CLLocationCoordinate2D { grave.coordinate }
    var title:      String? { grave.fullName }
    var subtitle:   String? { grave.lifespan }

    init(grave: GraveRecord) {
        self.grave = grave
        super.init()
    }
}

struct CemeterySection: Identifiable, Codable {
    let id: String
    let name: String
    let colour: String

    let boundaryCoordinates: [[Double]]

    var clCoordinates: [CLLocationCoordinate2D] {
        boundaryCoordinates.map {
            CLLocationCoordinate2D(latitude: $0[0], longitude: $0[1])
        }
    }
}

@MainActor
final class ARNavigationState: ObservableObject {

    @Published var selectedGrave: GraveRecord?
    @Published var distanceToTarget: Double?
    @Published var isARRunning: Bool = false
    @Published var heading: Double = 0
    @Published var userLocation: CLLocation?
}

extension CLLocationCoordinate2D {
    func bearing(to other: CLLocationCoordinate2D) -> Double {
        let lat1 = self.latitude  * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let dLon = (other.longitude - self.longitude) * .pi / 180

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)

        let bearing = atan2(y, x) * 180 / .pi
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }
}
