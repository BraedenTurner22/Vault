//
//  MapPlacementView.swift
//  vault
//
//  Interactive map for placing and resizing vault zones
//  Supports both creating new vaults and editing existing ones
//

import SwiftUI
import MapKit

struct MapPlacementView: View {
    @Binding var isPresented: Bool
    let vaultName: String
    let shapeType: ShapeType
    let selectedApps: [String]
    let userLocation: CLLocation?
    let userId: Int
    let vaultToEdit: VaultLocation? // Optional - if provided, we're editing
    let onSave: (VaultLocation) -> Void
    
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var currentRegion: MKCoordinateRegion?
    @State private var searchText = ""
    
    // Zone editing state
    @State private var zoneCenter: CLLocationCoordinate2D
    @State private var circleRadius: Double = 150.0
    @State private var quadCorners: [CLLocationCoordinate2D]
    
    // Interaction state
    @State private var interactionMode: InteractionMode = .none
    @State private var holdTimer: Timer?
    @State private var dragStartCoordinate: CLLocationCoordinate2D?
    @State private var dragStartRadius: Double?
    @State private var dragStartCorners: [CLLocationCoordinate2D]?
    @State private var selectedCornerIndex: Int?
    
    // Icon and color selection
    private let availableColors = ["#FF6B6B", "#4ECDC4", "#95E1D3", "#FFD93D", "#A78BFA", "#F472B6", "#FB923C"]
    private let availableIcons = ["dumbbell.fill", "book.fill", "briefcase.fill", "fork.knife", "house.fill", "person.2.fill", "pawprint.fill"]
    @State private var selectedColor: String
    @State private var selectedIcon: String
    
    // Performance optimization
    @State private var isInteracting: Bool = false
    
    enum InteractionMode: Equatable {
        case none
        case resizingCircle
        case movingShape
        case draggingCorner(Int)
    }
    
    init(isPresented: Binding<Bool>,
         vaultName: String,
         shapeType: ShapeType,
         selectedApps: [String],
         userLocation: CLLocation?,
         userId: Int,
         vaultToEdit: VaultLocation? = nil,
         onSave: @escaping (VaultLocation) -> Void) {
        
        self._isPresented = isPresented
        self.vaultName = vaultName
        self.shapeType = shapeType
        self.selectedApps = selectedApps
        self.userLocation = userLocation
        self.userId = userId
        self.vaultToEdit = vaultToEdit
        self.onSave = onSave
        
        // If editing, use existing vault data
        if let vault = vaultToEdit {
            _zoneCenter = State(initialValue: vault.coordinate)
            _selectedColor = State(initialValue: vault.color)
            _selectedIcon = State(initialValue: vault.iconName)
            
            switch vault.shape {
            case .circle(let radius):
                _circleRadius = State(initialValue: radius)
                // Initialize quad corners with default (won't be used)
                let offset = 0.002
                _quadCorners = State(initialValue: [
                    CLLocationCoordinate2D(latitude: vault.coordinate.latitude + offset, longitude: vault.coordinate.longitude - offset),
                    CLLocationCoordinate2D(latitude: vault.coordinate.latitude + offset, longitude: vault.coordinate.longitude + offset),
                    CLLocationCoordinate2D(latitude: vault.coordinate.latitude - offset, longitude: vault.coordinate.longitude + offset),
                    CLLocationCoordinate2D(latitude: vault.coordinate.latitude - offset, longitude: vault.coordinate.longitude - offset)
                ])
            case .quadrilateral(let corners):
                _quadCorners = State(initialValue: corners)
                _circleRadius = State(initialValue: 150.0) // Won't be used
            }
            
            let region = MKCoordinateRegion(
                center: vault.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            _currentRegion = State(initialValue: region)
        } else {
            // New vault - use defaults
            let center = userLocation?.coordinate ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
            _zoneCenter = State(initialValue: center)
            _selectedColor = State(initialValue: "#FF6B6B") // Default to first color (red)
            _selectedIcon = State(initialValue: "dumbbell.fill") // Default to first icon
            
            let offset = 0.002
            _quadCorners = State(initialValue: [
                CLLocationCoordinate2D(latitude: center.latitude + offset, longitude: center.longitude - offset),
                CLLocationCoordinate2D(latitude: center.latitude + offset, longitude: center.longitude + offset),
                CLLocationCoordinate2D(latitude: center.latitude - offset, longitude: center.longitude + offset),
                CLLocationCoordinate2D(latitude: center.latitude - offset, longitude: center.longitude - offset)
            ])
            
            let region = MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            _currentRegion = State(initialValue: region)
        }
    }
    
    var body: some View {
        ZStack {
            // Map with interactive overlay
            MapReader { proxy in
                ZStack {
                    // Base map - always interactive unless we're actively dragging a vault element
                    Map(position: $cameraPosition, interactionModes: isInteracting ? [] : .all) {
                        UserAnnotation()
                        
                        // Draw the zone
                        if shapeType == .circle {
                            MapCircle(center: zoneCenter, radius: circleRadius)
                                .foregroundStyle(Color(hex: selectedColor).opacity(0.3))
                                .stroke(Color(hex: selectedColor), lineWidth: 2)
                        } else {
                            MapPolygon(coordinates: quadCorners)
                                .foregroundStyle(Color(hex: selectedColor).opacity(0.3))
                                .stroke(Color(hex: selectedColor), lineWidth: 2)
                        }
                        
                        // Center annotation with selected icon
                        Annotation(vaultName, coordinate: zoneCenter) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: selectedColor))
                                    .frame(width: 30, height: 30)
                                Image(systemName: selectedIcon)
                                    .foregroundColor(.white)
                                    .font(.system(size: 12))
                            }
                            .allowsHitTesting(false)
                        }
                        
                        // Corner handles for quadrilateral
                        if shapeType == .quadrilateral {
                            ForEach(Array(quadCorners.enumerated()), id: \.offset) { index, corner in
                                Annotation("", coordinate: corner) {
                                    Circle()
                                        .fill(Color(hex: selectedColor))
                                        .frame(width: 20, height: 20)
                                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                        .shadow(radius: 2)
                                        .allowsHitTesting(false)
                                }
                            }
                        }
                    }
                    .mapControls {
                        MapUserLocationButton()
                        MapCompass()
                    }
                    .mapStyle(.standard)
                    .onMapCameraChange { context in
                        currentRegion = context.region
                    }
                    
                    // Overlay to capture vault interactions only
                    GeometryReader { geometry in
                        Color.clear
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        // Only process if we're already interacting OR if this touch starts on vault
                                        if interactionMode == .none {
                                            // Check if touch is on vault
                                            if shouldStartVaultInteraction(value, proxy: proxy) {
                                                handleDragChanged(value, proxy: proxy)
                                            }
                                            // If not on vault, do nothing - let map handle it
                                        } else {
                                            // Already interacting with vault, continue handling
                                            handleDragChanged(value, proxy: proxy)
                                        }
                                    }
                                    .onEnded { value in
                                        if interactionMode != .none {
                                            handleDragEnded(value, proxy: proxy)
                                        }
                                    },
                                including: interactionMode != .none ? .all : .subviews
                            )
                    }
                    .allowsHitTesting(interactionMode != .none)
                }
            }
            .edgesIgnoringSafeArea(.all)
            .onAppear {
                centerOnZone()
            }
            
            // Top controls
            VStack {
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search location", text: $searchText)
                            .onSubmit {
                                performSearch()
                            }
                    }
                    .padding(12)
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 3)
                    
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                }
                .padding()
                
                Spacer()
            }
            
            // Bottom controls
            VStack {
                Spacer()
                
                VStack(spacing: 16) {
                    // Instructions - only show when not interacting
                    if !isInteracting {
                        Text("Drag to resize • Hold to move")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(20)
                    }
                    
                    // Icon picker - non-scrollable
                    HStack(spacing: 12) {
                        ForEach(availableIcons, id: \.self) { icon in
                            Button(action: { selectedIcon = icon }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.gray)
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: selectedIcon == icon ? 3 : 0)
                                        )
                                        .shadow(radius: 2)
                                    
                                    Image(systemName: icon)
                                        .foregroundColor(.white)
                                        .font(.system(size: 16))
                                }
                            }
                        }
                    }
                    .frame(height: 50)
                    .padding(.horizontal)
                    
                    // Color picker - non-scrollable
                    HStack(spacing: 12) {
                        ForEach(availableColors, id: \.self) { color in
                            Button(action: { selectedColor = color }) {
                                Circle()
                                    .fill(Color(hex: color))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: selectedColor == color ? 3 : 0)
                                    )
                                    .shadow(radius: 2)
                            }
                        }
                    }
                    .frame(height: 50)
                    .padding(.horizontal)
                    
                    // Save button
                    Button(action: handleSave) {
                        Text(saveButtonText)
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .cornerRadius(12)
                            .shadow(radius: 5)
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 30)
            }
        }
    }
    
    private var saveButtonText: String {
        vaultToEdit == nil ? "Save Vault" : "Update Vault"
    }
    
    private func shouldStartVaultInteraction(_ value: DragGesture.Value, proxy: MapProxy) -> Bool {
        guard let startCoord = proxy.convert(value.startLocation, from: .local) else { return false }
        
        if shapeType == .circle {
            let distanceFromCenter = distanceBetweenCoordinates(startCoord, zoneCenter)
            return distanceFromCenter <= circleRadius
        } else {
            // Check if near corner or inside quad
            if findNearestCorner(to: startCoord, proxy: proxy, threshold: 30.0) != nil {
                return true
            }
            return isPointInsideQuad(startCoord)
        }
    }
    
    private func handleDragChanged(_ value: DragGesture.Value, proxy: MapProxy) {
        // Convert touch location to map coordinate
        guard let currentCoord = proxy.convert(value.location, from: .local) else { return }
        
        // If no interaction mode, check if we should start one
        if interactionMode == .none {
            guard let startCoord = proxy.convert(value.startLocation, from: .local) else { return }
            
            if shapeType == .circle {
                // Check if touch started inside circle
                let distanceFromCenter = distanceBetweenCoordinates(startCoord, zoneCenter)
                
                if distanceFromCenter <= circleRadius {
                    // Inside circle - we're interacting with the vault
                    isInteracting = true
                    dragStartCoordinate = zoneCenter
                    dragStartRadius = circleRadius
                    
                    // Check if user moved their finger
                    let dragDistance = hypot(value.location.x - value.startLocation.x,
                                            value.location.y - value.startLocation.y)
                    
                    if dragDistance > 3 {
                        // User is dragging - start resize immediately
                        interactionMode = .resizingCircle
                        holdTimer?.invalidate()
                        holdTimer = nil
                        
                        // Immediately update radius
                        let newRadius = distanceBetweenCoordinates(currentCoord, zoneCenter)
                        circleRadius = max(50, min(1000, newRadius))
                    } else if holdTimer == nil {
                        // Start hold timer for move
                        holdTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
                            if self.interactionMode == .none {
                                self.interactionMode = .movingShape
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                            }
                        }
                    }
                } else {
                    // Outside circle - don't interfere with map
                    return
                }
            } else {
                // Quadrilateral - check corners first, then inside
                if let cornerIndex = findNearestCorner(to: startCoord, proxy: proxy, threshold: 30.0) {
                    // Near a corner - start dragging it immediately
                    isInteracting = true
                    interactionMode = .draggingCorner(cornerIndex)
                    dragStartCorners = quadCorners
                    selectedCornerIndex = cornerIndex
                    
                    // Immediately update corner position
                    quadCorners[cornerIndex] = currentCoord
                    updateQuadCenter()
                } else if isPointInsideQuad(startCoord) {
                    // Inside quad - we're interacting with the vault
                    isInteracting = true
                    dragStartCoordinate = zoneCenter
                    dragStartCorners = quadCorners
                    
                    // Start hold timer for move
                    holdTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
                        if self.interactionMode == .none {
                            self.interactionMode = .movingShape
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                        }
                    }
                } else {
                    // Outside quad - don't interfere with map
                    return
                }
            }
            return
        }
        
        // Handle ongoing interaction - update immediately
        switch interactionMode {
        case .none:
            break
            
        case .resizingCircle:
            // Calculate new radius as distance from center to finger - INSTANT UPDATE
            let newRadius = distanceBetweenCoordinates(currentCoord, zoneCenter)
            circleRadius = max(50, min(1000, newRadius))
            
        case .movingShape:
            guard let startCoord = dragStartCoordinate else { return }
            
            if shapeType == .circle {
                // Move circle center to finger position - INSTANT UPDATE
                zoneCenter = currentCoord
            } else {
                // Move quadrilateral - INSTANT UPDATE
                guard let startCorners = dragStartCorners else { return }
                let deltaLat = currentCoord.latitude - startCoord.latitude
                let deltaLon = currentCoord.longitude - startCoord.longitude
                
                for i in 0..<quadCorners.count {
                    quadCorners[i] = CLLocationCoordinate2D(
                        latitude: startCorners[i].latitude + deltaLat,
                        longitude: startCorners[i].longitude + deltaLon
                    )
                }
                
                zoneCenter = currentCoord
            }
            
        case .draggingCorner(let index):
            // Move the specific corner to finger position - INSTANT UPDATE
            quadCorners[index] = currentCoord
            updateQuadCenter()
        }
    }
    
    private func handleDragEnded(_ value: DragGesture.Value, proxy: MapProxy) {
        holdTimer?.invalidate()
        holdTimer = nil
        interactionMode = .none
        isInteracting = false
        dragStartCoordinate = nil
        dragStartRadius = nil
        dragStartCorners = nil
        selectedCornerIndex = nil
    }
    
    private func findNearestCorner(to coord: CLLocationCoordinate2D, proxy: MapProxy, threshold: Double) -> Int? {
        var nearestIndex: Int?
        var nearestDistance = Double.infinity
        
        for (index, corner) in quadCorners.enumerated() {
            let distance = distanceBetweenCoordinates(coord, corner)
            
            if distance < threshold && distance < nearestDistance {
                nearestDistance = distance
                nearestIndex = index
            }
        }
        
        return nearestIndex
    }
    
    private func isPointInsideQuad(_ point: CLLocationCoordinate2D) -> Bool {
        // Ray casting algorithm
        var inside = false
        var j = quadCorners.count - 1
        
        for i in 0..<quadCorners.count {
            let xi = quadCorners[i].longitude
            let yi = quadCorners[i].latitude
            let xj = quadCorners[j].longitude
            let yj = quadCorners[j].latitude
            
            let intersect = ((yi > point.latitude) != (yj > point.latitude)) &&
                           (point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi)
            
            if intersect {
                inside = !inside
            }
            j = i
        }
        
        return inside
    }
    
    private func updateQuadCenter() {
        let avgLat = quadCorners.map { $0.latitude }.reduce(0, +) / Double(quadCorners.count)
        let avgLon = quadCorners.map { $0.longitude }.reduce(0, +) / Double(quadCorners.count)
        zoneCenter = CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon)
    }
    
    private func distanceBetweenCoordinates(_ coord1: CLLocationCoordinate2D, _ coord2: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: coord1.latitude, longitude: coord1.longitude)
        let location2 = CLLocation(latitude: coord2.latitude, longitude: coord2.longitude)
        return location1.distance(from: location2)
    }
    
    private func centerOnZone() {
        let region = MKCoordinateRegion(
            center: zoneCenter,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        withAnimation {
            cameraPosition = .region(region)
        }
    }
    
    private func performSearch() {
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = searchText
        
        let search = MKLocalSearch(request: searchRequest)
        search.start { response, error in
            guard let response = response, let firstItem = response.mapItems.first else { return }
            
            let coordinate = firstItem.placemark.coordinate
            zoneCenter = coordinate
            
            if shapeType == .quadrilateral {
                let offset = 0.002
                quadCorners = [
                    CLLocationCoordinate2D(latitude: coordinate.latitude + offset, longitude: coordinate.longitude - offset),
                    CLLocationCoordinate2D(latitude: coordinate.latitude + offset, longitude: coordinate.longitude + offset),
                    CLLocationCoordinate2D(latitude: coordinate.latitude - offset, longitude: coordinate.longitude + offset),
                    CLLocationCoordinate2D(latitude: coordinate.latitude - offset, longitude: coordinate.longitude - offset)
                ]
            }
            
            let region = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            withAnimation {
                cameraPosition = .region(region)
            }
        }
    }
    
    private func handleSave() {
        let shape: VaultShape
        if shapeType == .circle {
            shape = .circle(radius: circleRadius)
        } else {
            shape = .quadrilateral(corners: quadCorners)
        }
        
        let vault: VaultLocation
        if let existingVault = vaultToEdit {
            // Editing - preserve ID
            vault = VaultLocation(
                id: existingVault.id,
                name: vaultName,
                coordinate: zoneCenter,
                shape: shape,
                blockedApps: selectedApps,
                color: selectedColor,
                iconName: selectedIcon
            )
            let success = DatabaseManager.shared.updateVault(userId: userId, vault: vault)
            if success {
                onSave(vault)
            } else {
                print("Failed to update vault in database")
            }
        } else {
            // Creating new
            vault = VaultLocation(
                name: vaultName,
                coordinate: zoneCenter,
                shape: shape,
                blockedApps: selectedApps,
                color: selectedColor,
                iconName: selectedIcon
            )
            let success = DatabaseManager.shared.saveVault(userId: userId, vault: vault)
            if success {
                onSave(vault)
            } else {
                print("Failed to save vault to database")
            }
        }
    }
}
