import Foundation
import CoreLocation

enum VaultShape: Equatable {
    case circle(radius: Double)
    case quadrilateral(corners: [CLLocationCoordinate2D])
    
    static func == (lhs: VaultShape, rhs: VaultShape) -> Bool {
        switch (lhs, rhs) {
        case (.circle(let r1), .circle(let r2)):
            return r1 == r2
        case (.quadrilateral(let c1), .quadrilateral(let c2)):
            return c1.count == c2.count && zip(c1, c2).allSatisfy {
                $0.0.latitude == $0.1.latitude && $0.0.longitude == $0.1.longitude
            }
        default:
            return false
        }
    }
}

struct VaultLocation: Identifiable, Equatable {
    let id: UUID
    let name: String
    let coordinate: CLLocationCoordinate2D
    let shape: VaultShape
    let blockedApps: [String]
    let color: String
    let iconName: String
    
    // Default initializer (for new vaults)
    init(name: String, coordinate: CLLocationCoordinate2D, shape: VaultShape, blockedApps: [String], color: String, iconName: String = "dumbbell.fill") {
        self.id = UUID()
        self.name = name
        self.coordinate = coordinate
        self.shape = shape
        self.blockedApps = blockedApps
        self.color = color
        self.iconName = iconName
    }
    
    // Initializer with ID (for editing existing vaults)
    init(id: UUID, name: String, coordinate: CLLocationCoordinate2D, shape: VaultShape, blockedApps: [String], color: String, iconName: String = "dumbbell.fill") {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.shape = shape
        self.blockedApps = blockedApps
        self.color = color
        self.iconName = iconName
    }
    
    // Equatable conformance
    static func == (lhs: VaultLocation, rhs: VaultLocation) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude &&
        lhs.shape == rhs.shape &&
        lhs.blockedApps == rhs.blockedApps &&
        lhs.color == rhs.color &&
        lhs.iconName == rhs.iconName
    }
    
    // Computed property for SwiftUI Color
    var displayColor: String {
        color
    }
    
    // Helper to check if a coordinate is inside this vault location
    func contains(_ point: CLLocationCoordinate2D) -> Bool {
        switch shape {
        case .circle(let radius):
            let center = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let pointLocation = CLLocation(latitude: point.latitude, longitude: point.longitude)
            return center.distance(from: pointLocation) <= radius
            
        case .quadrilateral(let corners):
            guard corners.count == 4 else { return false }
            return isPointInQuadrilateral(point: point, corners: corners)
        }
    }
    
    // Ray casting algorithm to check if point is inside quadrilateral
    private func isPointInQuadrilateral(point: CLLocationCoordinate2D, corners: [CLLocationCoordinate2D]) -> Bool {
        var inside = false
        var j = corners.count - 1
        
        for i in 0..<corners.count {
            let xi = corners[i].latitude
            let yi = corners[i].longitude
            let xj = corners[j].latitude
            let yj = corners[j].longitude
            
            let intersect = ((yi > point.longitude) != (yj > point.longitude)) &&
                           (point.latitude < (xj - xi) * (point.longitude - yi) / (yj - yi) + xi)
            
            if intersect {
                inside = !inside
            }
            j = i
        }
        
        return inside
    }
}
