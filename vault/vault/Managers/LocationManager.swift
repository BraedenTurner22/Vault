import Foundation
import CoreLocation
import Combine

final class LocationManager: NSObject, ObservableObject {
    private var manager = CLLocationManager()
    @Published var lastLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var activeVaults: Set<String> = [] // Track which vaults user is currently in
    
    override init() {
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
    }
    
    func requestLocation() {
        let status = manager.authorizationStatus
        
        switch status {
        case .notDetermined:
            // Step 1: Request "When In Use" first
            manager.requestWhenInUseAuthorization()
            
        case .authorizedWhenInUse:
            // Step 2: After getting "When In Use", request "Always"
            manager.requestAlwaysAuthorization()
            
        case .authorizedAlways:
            startUpdatingLocation()
            
        default:
            break
        }
    }
    
    func startUpdatingLocation() {
        manager.startUpdatingLocation()
    }
    
    func stopUpdatingLocation() {
        manager.stopUpdatingLocation()
    }
    
    // Setup geofencing for vault locations
    func setupGeofencing(for vaults: [VaultLocation]) {
        // Remove all existing monitored regions first
        for region in manager.monitoredRegions {
            manager.stopMonitoring(for: region)
        }
        
        // Add new regions
        for vault in vaults {
            if case .circle(let radius) = vault.shape {
                let region = CLCircularRegion(
                    center: vault.coordinate,
                    radius: radius,
                    identifier: vault.id.uuidString
                )
                region.notifyOnEntry = true
                region.notifyOnExit = true
                manager.startMonitoring(for: region)
            }
            // Note: Geofencing only supports circular regions
            // Quadrilateral vaults would need continuous location monitoring
        }
    }
    
    // Remove geofencing
    func stopGeofencing() {
        for region in manager.monitoredRegions {
            manager.stopMonitoring(for: region)
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async {
            self.lastLocation = location
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            
            switch manager.authorizationStatus {
            case .authorizedWhenInUse:
                // Immediately request "Always" after getting "When In Use"
                manager.requestAlwaysAuthorization()
                
            case .authorizedAlways:
                self.startUpdatingLocation()
                
            default:
                break
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
    
    // Geofencing delegate methods
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
      guard region is CLCircularRegion else { return }
        
        DispatchQueue.main.async {
            self.activeVaults.insert(region.identifier)
            print("Entered vault region: \(region.identifier)")
            // Trigger app blocking logic here
            NotificationCenter.default.post(
                name: NSNotification.Name("EnteredVault"),
                object: nil,
                userInfo: ["vaultId": region.identifier]
            )
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
      guard region is CLCircularRegion else { return }
        
        DispatchQueue.main.async {
            self.activeVaults.remove(region.identifier)
            print("Exited vault region: \(region.identifier)")
            // Trigger app unblocking logic here
            NotificationCenter.default.post(
                name: NSNotification.Name("ExitedVault"),
                object: nil,
                userInfo: ["vaultId": region.identifier]
            )
        }
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("Monitoring failed for region: \(region?.identifier ?? "unknown") with error: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        print("Started monitoring region: \(region.identifier)")
        // Request initial state to check if already inside
        manager.requestState(for: region)
    }
    
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        if state == .inside {
            // User is already inside this region when monitoring started
            DispatchQueue.main.async {
                self.activeVaults.insert(region.identifier)
            }
        }
    }
}
