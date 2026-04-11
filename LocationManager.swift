import Foundation
import CoreLocation
import Combine

protocol LocationManagerDelegate: AnyObject {
    func locationManager(_ manager: LocationManager,
                         didUpdateLocation location: CLLocation)
    func locationManager(_ manager: LocationManager,
                         didUpdateHeading heading: CLHeading)
    func locationManager(_ manager: LocationManager,
                         didFailWithError error: Error)
}

final class LocationManager: NSObject {

    weak var delegate: LocationManagerDelegate?

    private(set) var currentLocation: CLLocation?
    private(set) var currentHeading: CLHeading?
    private let clManager = CLLocationManager()

    override init() {
        super.init()
        clManager.delegate = self
        clManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        clManager.distanceFilter = 1.0
        clManager.headingFilter = 5.0
    }

    func startUpdating() {
        switch clManager.authorizationStatus {
        case .notDetermined:
            clManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            beginUpdates()
        default:
            break
        }
    }
    
    func stopUpdating() {
        clManager.stopUpdatingLocation()
        clManager.stopUpdatingHeading()
    }

    private func beginUpdates() {
        clManager.startUpdatingLocation()
        clManager.startUpdatingHeading()
    }

    func distance(to grave: GraveRecord) -> Double? {
        guard let userLoc = currentLocation else { return nil }
        return userLoc.distance(from: grave.location)
    }
}

extension LocationManager: CLLocationManagerDelegate {

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            beginUpdates()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        delegate?.locationManager(self, didUpdateLocation: location)
    }

    func locationManager(_ manager: CLLocationManager,
                         didUpdateHeading newHeading: CLHeading) {
        currentHeading = newHeading
        delegate?.locationManager(self, didUpdateHeading: newHeading)
    }

    func locationManager(_ manager: CLLocationManager,
                         didFailWithError error: Error) {
        delegate?.locationManager(self, didFailWithError: error)
    }
}
