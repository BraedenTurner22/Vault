//
//  ContentView.swift (Updated)
//  vault
//
//  Main view with authentication and vault management
//

import SwiftUI
import MapKit

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var position: MapCameraPosition = .automatic
    @State private var showingLocationAlert = false
    @State private var isDrawerExpanded = false
    @State private var vaultLocations: [VaultLocation] = []
    @State private var showingNewVaultFlow = false
    @State private var showingEditVaultFlow = false
    @State private var vaultToEdit: VaultLocation?
    @State private var hasInitiallycentered = false
    
    // Authentication state
    @State private var isAuthenticated = false
    @State private var currentUserId: Int?
    
    // Loading state
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            if isLoading {
                LaunchScreenView()
                    .transition(.opacity)
            } else {
                Group {
                    if isAuthenticated, let userId = currentUserId {
                        mainMapView(userId: userId)
                    } else {
                        AuthView(isAuthenticated: $isAuthenticated, currentUserId: $currentUserId)
                    }
                }
                .onChange(of: isAuthenticated) { _, authenticated in
                    if authenticated, let userId = currentUserId {
                        loadUserVaults(userId: userId)
                        hasInitiallycentered = false
                    }
                }
                .onChange(of: vaultLocations) { _, newVaults in
                    setupGeofencing(for: newVaults)
                }
            }
        }
        .onAppear {
            // Show launch screen for 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    isLoading = false
                }
            }
        }
    }
    
    @ViewBuilder
    private func mainMapView(userId: Int) -> some View {
        ZStack(alignment: .bottom) {
            // Map
            Map(position: $position) {
                UserAnnotation()
                
                // Add vault location overlays
                ForEach(vaultLocations) { location in
                    // Render different shapes based on location type
                    switch location.shape {
                    case .circle(let radius):
                        MapCircle(
                            center: location.coordinate,
                            radius: radius
                        )
                        .foregroundStyle(Color(hex: location.color).opacity(0.3))
                        .stroke(Color(hex: location.color), lineWidth: 2)
                        
                    case .quadrilateral(let corners):
                        MapPolygon(coordinates: corners)
                            .foregroundStyle(Color(hex: location.color).opacity(0.3))
                            .stroke(Color(hex: location.color), lineWidth: 2)
                    }
                    
                    // Add annotation for the center with custom icon
                    Annotation(location.name, coordinate: location.coordinate) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: location.color))
                                .frame(width: 30, height: 30)
                            Image(systemName: location.iconName)
                                .foregroundColor(.white)
                                .font(.system(size: 12))
                        }
                    }
                }
            }
            .mapControls {
                MapCompass()
            }
            .edgesIgnoringSafeArea(.all)
            .onAppear {
                locationManager.requestLocation()
                
                if let location = locationManager.lastLocation, !hasInitiallycentered {
                    centerOnLocation(location)
                    hasInitiallycentered = true
                }
            }
            .onChange(of: locationManager.lastLocation) { _, newLocation in
                if let location = newLocation {
                    if !hasInitiallycentered {
                        centerOnLocation(location)
                        hasInitiallycentered = true
                    }
                }
            }
            .onChange(of: locationManager.authorizationStatus) { _, status in
                handleAuthorizationChange(status)
            }
            
            // Vault Drawer
            VaultDrawerView(
                isExpanded: $isDrawerExpanded,
                locations: $vaultLocations,
                userId: userId,
                onLocationTap: { location in
                    centerOnVaultLocation(location)
                },
                onEditTap: { location in
                    vaultToEdit = location
                    showingEditVaultFlow = true
                },
                onAddTap: {
                    showingNewVaultFlow = true
                },
                onUserLocationTap: {
                    if let location = locationManager.lastLocation {
                        centerOnLocation(location)
                    }
                }
            )
            .transition(.move(edge: .bottom))
            
            // New Vault Flow
            if showingNewVaultFlow {
                NewVaultFlowView(
                    isPresented: $showingNewVaultFlow,
                    vaultLocations: $vaultLocations,
                    userLocation: locationManager.lastLocation,
                    userId: userId
                )
                .transition(.opacity)
            }
            
            // Edit Vault Flow
            if showingEditVaultFlow, let vault = vaultToEdit {
                EditVaultFlowView(
                    isPresented: $showingEditVaultFlow,
                    vaultLocations: $vaultLocations,
                    vaultToEdit: vault,
                    userLocation: locationManager.lastLocation,
                    userId: userId
                )
                .transition(.opacity)
            }
        }
        .alert("Location Required", isPresented: $showingLocationAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This app requires access to your location at all times to function. Please enable 'Always' location access in Settings.")
        }
    }
    
    private func loadUserVaults(userId: Int) {
        vaultLocations = DatabaseManager.shared.loadVaults(userId: userId)
    }
      
    private func setupGeofencing(for vaults: [VaultLocation]) {
        if locationManager.authorizationStatus == .authorizedAlways ||
           locationManager.authorizationStatus == .authorizedWhenInUse {
            locationManager.setupGeofencing(for: vaults)
        }
    }
      
    private func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
        switch status {
        case .denied, .restricted:
            showingLocationAlert = true
        case .notDetermined:
            break
        case .authorizedAlways:
            locationManager.startUpdatingLocation()
            setupGeofencing(for: vaultLocations)
        case .authorizedWhenInUse:
            locationManager.startUpdatingLocation()
            setupGeofencing(for: vaultLocations)
        @unknown default:
            break
        }
    }
    
    private func centerOnLocation(_ location: CLLocation) {
        let region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        withAnimation {
            position = .region(region)
        }
    }
    
    private func centerOnVaultLocation(_ location: VaultLocation) {
        // Calculate span based on shape to show the full zone
        let span: MKCoordinateSpan
        
        switch location.shape {
        case .circle(let radius):
            let radiusInDegrees = radius / 111000.0
            span = MKCoordinateSpan(
                latitudeDelta: radiusInDegrees * 4,
                longitudeDelta: radiusInDegrees * 4
            )
            
        case .quadrilateral(let corners):
            let lats = corners.map { $0.latitude }
            let lons = corners.map { $0.longitude }
            let minLat = lats.min() ?? location.coordinate.latitude
            let maxLat = lats.max() ?? location.coordinate.latitude
            let minLon = lons.min() ?? location.coordinate.longitude
            let maxLon = lons.max() ?? location.coordinate.longitude
            
            span = MKCoordinateSpan(
                latitudeDelta: (maxLat - minLat) * 1.5,
                longitudeDelta: (maxLon - minLon) * 1.5
            )
        }
        
        let region = MKCoordinateRegion(
            center: location.coordinate,
            span: span
        )
        
        withAnimation {
            position = .region(region)
            isDrawerExpanded = false
        }
    }
}
