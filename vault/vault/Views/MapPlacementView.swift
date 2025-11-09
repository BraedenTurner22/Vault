//
//  MapPlacementView.swift
//  vault
//
//  Interactive map for placing and resizing vault zones
//  Supports both creating new vaults and editing existing ones
//

import SwiftUI
import MapKit
import CoreLocation

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
    @State private var isInteracting: Bool = false

    // Drag delta helpers (used to compute smooth movement without jumps)
    @State private var dragStartTouchCoord: CLLocationCoordinate2D? = nil
    @State private var dragInitialZoneCenter: CLLocationCoordinate2D? = nil
    @State private var dragInitialCorners: [CLLocationCoordinate2D]? = nil
    @State private var dragInitialCorner: CLLocationCoordinate2D? = nil
    @State private var dragInitialRadius: Double? = nil

    // Icon and color selection
    private let availableColors = ["#FF6B6B", "#4ECDC4", "#95E1D3", "#FFD93D", "#A78BFA", "#F472B6", "#FB923C"]
    private let availableIcons = ["dumbbell.fill", "book.fill", "briefcase.fill", "fork.knife", "house.fill", "person.2.fill", "pawprint.fill"]
    @State private var selectedColor: String
    @State private var selectedIcon: String

    enum InteractionMode: Equatable {
        case none
        case resizingCircle
        case movingShape
        case draggingCorner(Int)
    }
    @State private var interactionMode: InteractionMode = .none

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

        if let vault = vaultToEdit {
            _zoneCenter = State(initialValue: vault.coordinate)
            _selectedColor = State(initialValue: vault.color)
            _selectedIcon = State(initialValue: vault.iconName)

            switch vault.shape {
            case .circle(let radius):
                _circleRadius = State(initialValue: radius)
                let offset = 0.002
                _quadCorners = State(initialValue: [
                    CLLocationCoordinate2D(latitude: vault.coordinate.latitude + offset, longitude: vault.coordinate.longitude - offset),
                    CLLocationCoordinate2D(latitude: vault.coordinate.latitude + offset, longitude: vault.coordinate.longitude + offset),
                    CLLocationCoordinate2D(latitude: vault.coordinate.latitude - offset, longitude: vault.coordinate.longitude + offset),
                    CLLocationCoordinate2D(latitude: vault.coordinate.latitude - offset, longitude: vault.coordinate.longitude - offset)
                ])
            case .quadrilateral(let corners):
                _quadCorners = State(initialValue: corners)
                _circleRadius = State(initialValue: 150.0)
            }

            let region = MKCoordinateRegion(
                center: vault.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            _currentRegion = State(initialValue: region)
        } else {
            let center = userLocation?.coordinate ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
            _zoneCenter = State(initialValue: center)
            _selectedColor = State(initialValue: "#FF6B6B") // Default color
            _selectedIcon = State(initialValue: "dumbbell.fill") // Default icon

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
            MapReader { proxy in
                ZStack {
                    // Disable map gestures while interacting with a vault element to avoid conflicts
                    Map(position: $cameraPosition, interactionModes: isInteracting ? [] : .all) {
                        UserAnnotation()

                        if shapeType == .circle {
                            // Circle overlay
                            MapCircle(center: zoneCenter, radius: circleRadius)
                                .foregroundStyle(Color(hex: selectedColor).opacity(0.3))
                                .stroke(Color(hex: selectedColor), lineWidth: 2)

                            // Center annotation - immediate drag uses delta mapping to avoid jumps
                            Annotation(vaultName, coordinate: zoneCenter) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: selectedColor))
                                        .frame(width: 30, height: 30)
                                    Image(systemName: selectedIcon)
                                        .foregroundColor(.white)
                                        .font(.system(size: 12))
                                }
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            // initialize start touch + initial center once
                                            if dragStartTouchCoord == nil {
                                                if let startCoord = proxy.convert(value.startLocation, from: .local) {
                                                    dragStartTouchCoord = startCoord
                                                    dragInitialZoneCenter = zoneCenter
                                                    isInteracting = true
                                                    interactionMode = .movingShape
                                                } else {
                                                    return
                                                }
                                            }

                                            guard let startTouch = dragStartTouchCoord,
                                                  let initialCenter = dragInitialZoneCenter,
                                                  let currentTouch = proxy.convert(value.location, from: .local) else { return }

                                            let deltaLat = currentTouch.latitude - startTouch.latitude
                                            let deltaLon = currentTouch.longitude - startTouch.longitude

                                            zoneCenter = CLLocationCoordinate2D(
                                                latitude: initialCenter.latitude + deltaLat,
                                                longitude: initialCenter.longitude + deltaLon
                                            )
                                        }
                                        .onEnded { _ in
                                            dragStartTouchCoord = nil
                                            dragInitialZoneCenter = nil
                                            isInteracting = false
                                            interactionMode = .none
                                        }
                                )
                            }

                          // Circle resize handle – fully stable, precise resizing
                          if let edge = coordinate(at: zoneCenter, distanceMeters: circleRadius, bearingDegrees: 45) {
                              Annotation("", coordinate: edge) {
                                  Circle()
                                      .fill(Color.white)
                                      .frame(width: 22, height: 22)
                                      .overlay(Circle().stroke(Color(hex: selectedColor), lineWidth: 3))
                                      .gesture(
                                          DragGesture(minimumDistance: 0)
                                              .onChanged { value in
                                                  // Initialize drag start once
                                                  if dragStartTouchCoord == nil {
                                                      // Record where the finger first touched in map coordinates
                                                      dragStartTouchCoord = proxy.convert(value.startLocation, from: .global)
                                                      dragInitialRadius = circleRadius
                                                      isInteracting = true
                                                      interactionMode = .resizingCircle
                                                  }

                                                  guard let startCoord = dragStartTouchCoord,
                                                        let currentCoord = proxy.convert(value.location, from: .global),
                                                        let startRadius = dragInitialRadius else { return }

                                                  // Compute change in distance from center between start and current
                                                  let startDist = distanceBetweenCoordinates(zoneCenter, startCoord)
                                                  let currentDist = distanceBetweenCoordinates(zoneCenter, currentCoord)
                                                  let delta = currentDist - startDist
                                                  let newRadius = startRadius + delta

                                                  // Clamp between 50m and 1000m
                                                  circleRadius = max(50, min(1000, newRadius))
                                              }
                                              .onEnded { _ in
                                                  dragStartTouchCoord = nil
                                                  dragInitialRadius = nil
                                                  isInteracting = false
                                                  interactionMode = .none
                                              }
                                      )
                              }
                          }


                        } else {
                            // Quadrilateral polygon
                            MapPolygon(coordinates: quadCorners)
                                .foregroundStyle(Color(hex: selectedColor).opacity(0.3))
                                .stroke(Color(hex: selectedColor), lineWidth: 2)

                            // Center annotation - drag whole quad
                            Annotation(vaultName, coordinate: zoneCenter) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: selectedColor))
                                        .frame(width: 30, height: 30)
                                    Image(systemName: selectedIcon)
                                        .foregroundColor(.white)
                                        .font(.system(size: 12))
                                }
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            // Initialize on first move
                                            if dragStartTouchCoord == nil {
                                                if let startCoord = proxy.convert(value.startLocation, from: .local) {
                                                    dragStartTouchCoord = startCoord
                                                    dragInitialCorners = quadCorners
                                                    dragInitialZoneCenter = zoneCenter
                                                    isInteracting = true
                                                    interactionMode = .movingShape
                                                } else {
                                                    return
                                                }
                                            }

                                            guard let startTouch = dragStartTouchCoord,
                                                  let initialCorners = dragInitialCorners,
                                                  let currentTouch = proxy.convert(value.location, from: .local) else { return }

                                            let deltaLat = currentTouch.latitude - startTouch.latitude
                                            let deltaLon = currentTouch.longitude - startTouch.longitude

                                            var newCorners = initialCorners
                                            for i in 0..<newCorners.count {
                                                newCorners[i] = CLLocationCoordinate2D(
                                                    latitude: initialCorners[i].latitude + deltaLat,
                                                    longitude: initialCorners[i].longitude + deltaLon
                                                )
                                            }
                                            quadCorners = newCorners

                                            if let initialCenter = dragInitialZoneCenter {
                                                zoneCenter = CLLocationCoordinate2D(
                                                    latitude: initialCenter.latitude + deltaLat,
                                                    longitude: initialCenter.longitude + deltaLon
                                                )
                                            } else {
                                                updateQuadCenter()
                                            }
                                        }
                                        .onEnded { _ in
                                            dragStartTouchCoord = nil
                                            dragInitialCorners = nil
                                            dragInitialZoneCenter = nil
                                            isInteracting = false
                                            interactionMode = .none
                                        }
                                )
                            }

                            // Corner handles - drag each corner precisely
                            ForEach(Array(quadCorners.enumerated()), id: \.offset) { index, corner in
                                Annotation("", coordinate: corner) {
                                    Circle()
                                        .fill(Color(hex: selectedColor))
                                        .frame(width: 20, height: 20)
                                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                        .shadow(radius: 2)
                                        .gesture(
                                            DragGesture(minimumDistance: 0)
                                                .onChanged { value in
                                                    // initialize per-corner start states
                                                    if dragStartTouchCoord == nil {
                                                        if let startCoord = proxy.convert(value.startLocation, from: .local) {
                                                            dragStartTouchCoord = startCoord
                                                            dragInitialCorner = quadCorners[index]
                                                            dragInitialCorners = quadCorners
                                                            isInteracting = true
                                                            interactionMode = .draggingCorner(index)
                                                        } else {
                                                            return
                                                        }
                                                    }

                                                    guard let startTouch = dragStartTouchCoord,
                                                          let initialCorner = dragInitialCorner,
                                                          let currentTouch = proxy.convert(value.location, from: .local) else { return }

                                                    let deltaLat = currentTouch.latitude - startTouch.latitude
                                                    let deltaLon = currentTouch.longitude - startTouch.longitude

                                                    // Apply delta to this corner (so movement tracks finger exactly)
                                                    quadCorners[index] = CLLocationCoordinate2D(
                                                        latitude: initialCorner.latitude + deltaLat,
                                                        longitude: initialCorner.longitude + deltaLon
                                                    )

                                                    // Optionally update other corners relative to initial if you want uniform scaling — for now, only moving single corner
                                                    updateQuadCenter()
                                                }
                                                .onEnded { _ in
                                                    dragStartTouchCoord = nil
                                                    dragInitialCorner = nil
                                                    dragInitialCorners = nil
                                                    isInteracting = false
                                                    interactionMode = .none
                                                }
                                        )
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
                    if !isInteracting {
                        Text("Drag to resize • Drag to move")
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

    // MARK: - Helper Methods

    private func updateQuadCenter() {
        guard quadCorners.count > 0 else { return }
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
                updateQuadCenter()
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

    // Helper: compute a coordinate a given distance/bearing from a center (approx using Earth radius)
    private func coordinate(at center: CLLocationCoordinate2D, distanceMeters: Double, bearingDegrees: Double) -> CLLocationCoordinate2D? {
        let radiusEarth = 6_371_000.0
        let dist = distanceMeters / radiusEarth
        let bearing = bearingDegrees * .pi / 180.0
        let lat1 = center.latitude * .pi / 180.0
        let lon1 = center.longitude * .pi / 180.0

        let lat2 = asin(sin(lat1) * cos(dist) + cos(lat1) * sin(dist) * cos(bearing))
        let lon2 = lon1 + atan2(sin(bearing) * sin(dist) * cos(lat1), cos(dist) - sin(lat1) * sin(lat2))

        return CLLocationCoordinate2D(latitude: lat2 * 180.0 / .pi, longitude: lon2 * 180.0 / .pi)
    }
}
