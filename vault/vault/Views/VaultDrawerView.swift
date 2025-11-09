//
//  VaultDrawerView.swift
//  vault
//
//  Created by Braeden Turner on 2025-11-08
//

import SwiftUI

struct VaultDrawerView: View {
    @Binding var isExpanded: Bool
    @Binding var locations: [VaultLocation]
    let userId: Int
    let onLocationTap: (VaultLocation) -> Void
    let onEditTap: (VaultLocation) -> Void
    let onAddTap: () -> Void
    let onUserLocationTap: () -> Void
    
    private let minHeight: CGFloat = 120
    @State private var currentHeight: CGFloat = 120
    @State private var isAddingNewVault = false
    
    var body: some View {
        GeometryReader { geometry in
            let maxHeight = geometry.size.height * 0.7
            let safeAreaBottom = geometry.safeAreaInsets.bottom
            
            ZStack {
                // Tappable overlay when expanded
                if isExpanded {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation {
                                isExpanded = false
                                isAddingNewVault = false
                                currentHeight = minHeight
                            }
                        }
                        .ignoresSafeArea()
                }
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    VStack(spacing: 0) {
                        // Handle bar
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.secondary.opacity(0.5))
                            .frame(width: 40, height: 5)
                            .padding(.top, 12)
                            .padding(.bottom, 8)
                            .onTapGesture {
                                withAnimation {
                                    isExpanded.toggle()
                                    if !isExpanded {
                                        isAddingNewVault = false
                                        currentHeight = minHeight
                                    } else {
                                        currentHeight = maxHeight
                                    }
                                }
                            }
                        
                        // Header
                        HStack {
                            Text("Vaults")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Text("\(locations.count)")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                        
                        Divider()
                        
                        // Locations list
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(locations) { location in
                                    SwipeableVaultCard(
                                        location: location,
                                        onTap: {
                                            onLocationTap(location)
                                        },
                                        onEdit: {
                                            onEditTap(location)
                                        },
                                        onDelete: {
                                            deleteVault(location)
                                        }
                                    )
                                    .padding(.horizontal)
                                }
                                
                                // New Vault button inside list when expanded
                                if isExpanded {
                                    Button(action: {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            isAddingNewVault = true
                                            onAddTap()
                                        }
                                    }) {
                                        Label("New Vault", systemImage: "plus")
                                            .font(.title3.weight(.semibold))
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                            .background(Capsule().fill(Color.orange))
                                            .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
                                    }
                                    .padding(.horizontal)
                                    .padding(.top, 8)
                                }
                            }
                            .padding(.vertical, 12)
                            .padding(.bottom, safeAreaBottom)
                        }
                    }
                    .frame(height: currentHeight + safeAreaBottom)
                    .frame(maxWidth: .infinity)
                    .background(
                        Color(.systemBackground)
                    )
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 20,
                            topTrailingRadius: 20
                        )
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: -5)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newHeight = currentHeight - value.translation.height
                                currentHeight = max(minHeight, min(maxHeight, newHeight))
                            }
                            .onEnded { value in
                              let _: CGFloat = 50
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    if currentHeight > (minHeight + maxHeight) / 2 {
                                        isExpanded = true
                                        currentHeight = maxHeight
                                    } else {
                                        isExpanded = false
                                        isAddingNewVault = false
                                        currentHeight = minHeight
                                    }
                                }
                            }
                    )
                }
                .ignoresSafeArea(edges: .bottom)
                
                // Floating buttons when drawer is collapsed
                if !isExpanded && !isAddingNewVault {
                    VStack {
                        Spacer()
                        
                        HStack(spacing: 12) {
                            // New Vault Button (left side)
                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    isAddingNewVault = true
                                    onAddTap()
                                }
                            }) {
                                Label("New Vault", systemImage: "plus")
                                    .font(.title3.weight(.semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Capsule().fill(Color.orange))
                                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
                            }
                            
                            Spacer()
                            
                            // User Location Button (right side)
                            Button(action: onUserLocationTap) {
                                Image(systemName: "location.fill")
                                    .font(.title3.weight(.semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 48, height: 48)
                                    .background(Circle().fill(Color.blue))
                                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
                            }
                        }
                        .padding(.horizontal, 24)
                        .offset(y: -(currentHeight + 24))
                        .transition(.scale.combined(with: .opacity))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
            }
            .onChange(of: isExpanded) { _, newValue in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    currentHeight = newValue ? maxHeight : minHeight
                }
            }
        }
    }
    
    private func deleteVault(_ location: VaultLocation) {
        withAnimation {
            // Delete from database
            let success = DatabaseManager.shared.deleteVault(userId: userId, vaultId: location.id)
            
            if success {
                // Remove from array only if database deletion succeeded
                locations.removeAll { $0.id == location.id }
            } else {
                // Handle failure - could show an alert to the user
                print("Failed to delete vault: \(location.name)")
                // Optionally show an alert to the user here
            }
        }
    }
}

// MARK: - Swipeable Vault Card

struct SwipeableVaultCard: View {
    let location: VaultLocation
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var isSwiped = false
    
    private let deleteButtonWidth: CGFloat = 100
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete button background - fills entire space
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    onDelete()
                }
            }) {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                            .font(.title2)
                        Text("Delete")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .frame(width: deleteButtonWidth)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.red)
            }
            .cornerRadius(12)
            
            // Main card content
            VaultLocationCard(
                location: location,
                onTap: onTap,
                onEdit: onEdit
            )
            .offset(x: offset)
            .simultaneousGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { gesture in
                        let translation = gesture.translation.width
                        
                        if isSwiped {
                            // Already swiped - allow closing or prevent further opening
                            let newOffset = -deleteButtonWidth + translation
                            offset = max(min(newOffset, 0), -deleteButtonWidth)
                        } else {
                            // Not swiped - only allow left swipe
                            if translation < 0 {
                                offset = max(translation, -deleteButtonWidth)
                            }
                        }
                    }
                    .onEnded { gesture in
                        let translation = gesture.translation.width
                        let velocity = gesture.velocity.width
                        
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            if isSwiped {
                                // Already open - check if closing
                                if translation > 30 || velocity > 500 {
                                    offset = 0
                                    isSwiped = false
                                } else {
                                    offset = -deleteButtonWidth
                                }
                            } else {
                                // Closed - check if opening
                                if translation < -30 || velocity < -500 {
                                    offset = -deleteButtonWidth
                                    isSwiped = true
                                } else {
                                    offset = 0
                                }
                            }
                        }
                    }
            )
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }
}

// MARK: - Vault Location Card

struct VaultLocationCard: View {
    let location: VaultLocation
    let onTap: () -> Void
    let onEdit: () -> Void
    @State private var appIcons: [String: URL] = [:]
    
    var body: some View {
        HStack(spacing: 16) {
            // Color indicator circle with selected icon
            Circle()
                .fill(Color(hex: location.color))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: location.iconName)
                        .foregroundColor(.white)
                        .font(.system(size: 20))
                )
            
            VStack(alignment: .leading, spacing: 8) {
                Text(location.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                // Blocked apps icons (up to 3)
                if !location.blockedApps.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(Array(location.blockedApps.prefix(3)), id: \.self) { appName in
                            if let iconURL = appIcons[appName] {
                                AsyncImage(url: iconURL) { phase in
                                    if let image = phase.image {
                                        image
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 32, height: 32)
                                            .cornerRadius(7)
                                    } else if phase.error != nil {
                                        Image(systemName: "app.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 32, height: 32)
                                            .foregroundColor(.gray)
                                    } else {
                                        ProgressView()
                                            .frame(width: 32, height: 32)
                                    }
                                }
                            } else {
                                Image(systemName: "app.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 32, height: 32)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        // Show "and more" indicator if there are more than 3 apps
                        if location.blockedApps.count > 3 {
                            Text("+\(location.blockedApps.count - 3)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Three dots menu button
            Button(action: onEdit) {
                Image(systemName: "ellipsis")
                    .foregroundColor(.secondary)
                    .font(.system(size: 18, weight: .bold))
                    .rotationEffect(.degrees(90))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onAppear {
            loadAppIcons()
        }
    }
    
    private func loadAppIcons() {
        // Load icons for the first 3 apps
        for appName in location.blockedApps.prefix(3) {
            // Find the bundle ID from AppList
            if let app = AppList.popularApps.first(where: { $0.name == appName }) {
                AppIconFetcher.fetchIconURL(for: app.bundleId) { url in
                    DispatchQueue.main.async {
                        if let url = url {
                            appIcons[appName] = url
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Helper extension for hex colors

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
