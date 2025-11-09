//
//  NewVaultFlowView.swift
//  vault
//
//  Multi-step vault creation flow
//

import SwiftUI
import CoreLocation
import Combine

enum VaultCreationStep {
    case nameAndShape
    case appSelection
    case mapPlacement
}

struct NewVaultFlowView: View {
    @Binding var isPresented: Bool
    @Binding var vaultLocations: [VaultLocation]
    let userLocation: CLLocation?
    let userId: Int
    
    @State private var currentStep: VaultCreationStep = .nameAndShape
    @State private var vaultName = ""
    @State private var selectedShape: ShapeType = .circle
    @State private var selectedApps: Set<String> = []
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    if currentStep == .nameAndShape {
                        isPresented = false
                    }
                }
            
            VStack {
                Spacer()
                
                VStack(spacing: 0) {
                    // Header with progress
                    VStack(spacing: 12) {
                        HStack {
                            if currentStep != .nameAndShape {
                                Button(action: handleBack) {
                                    Image(systemName: "chevron.left")
                                        .font(.title3)
                                        .foregroundColor(.primary)
                                }
                            } else {
                                // Empty spacer to maintain layout balance
                                Color.clear
                                    .frame(width: 44, height: 44)
                            }
                            
                            Spacer()
                            
                            Text(stepTitle)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Button(action: { isPresented = false }) {
                                Image(systemName: "xmark")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Progress indicator
                        HStack(spacing: 8) {
                            ForEach(0..<3) { index in
                                Rectangle()
                                    .fill(index <= stepIndex ? Color.orange : Color.gray.opacity(0.3))
                                    .frame(height: 4)
                                    .cornerRadius(2)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 16)
                    
                    Divider()
                    
                    // Content based on step
                    Group {
                        switch currentStep {
                        case .nameAndShape:
                            NameAndShapeView(
                                vaultName: $vaultName,
                                selectedShape: $selectedShape,
                                onNext: { currentStep = .appSelection }
                            )
                        case .appSelection:
                            AppSelectionView(
                                selectedApps: $selectedApps,
                                onNext: { currentStep = .mapPlacement }
                            )
                        case .mapPlacement:
                            EmptyView() // This will be overlaid on the map
                        }
                    }
                }
                .frame(height: currentStep == .mapPlacement ? 0 : UIScreen.main.bounds.height * 0.6)
                .frame(maxWidth: .infinity)
                .background(Color(.systemBackground))
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: -5)
                .opacity(currentStep == .mapPlacement ? 0 : 1)
            }
            .ignoresSafeArea(edges: .bottom)
            
            // Map placement overlay
            if currentStep == .mapPlacement {
                MapPlacementView(
                    isPresented: $isPresented,
                    vaultName: vaultName,
                    shapeType: selectedShape,
                    selectedApps: Array(selectedApps),
                    userLocation: userLocation,
                    userId: userId,
                    vaultToEdit: nil,  // No vault to edit - creating new
                    onSave: { vault in
                        vaultLocations.append(vault)
                        isPresented = false
                    }
                )
            }
        }
    }
    
    private var stepTitle: String {
        switch currentStep {
        case .nameAndShape: return "New Vault"
        case .appSelection: return "Block Apps"
        case .mapPlacement: return "Place Zone"
        }
    }
    
    private var stepIndex: Int {
        switch currentStep {
        case .nameAndShape: return 0
        case .appSelection: return 1
        case .mapPlacement: return 2
        }
    }
    
    private func handleBack() {
        switch currentStep {
        case .nameAndShape:
            isPresented = false
        case .appSelection:
            currentStep = .nameAndShape
        case .mapPlacement:
            currentStep = .appSelection
        }
    }
}

// MARK: - Step 1: Name and Shape

enum ShapeType: String, CaseIterable {
    case circle = "Circle"
    case quadrilateral = "Quadrilateral"
}

struct NameAndShapeView: View {
    @Binding var vaultName: String
    @Binding var selectedShape: ShapeType
    let onNext: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Name input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Vault Name")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    TextField("e.g. Library, Gym, Work", text: $vaultName)
                        .textFieldStyle(RoundedTextFieldStyle())
                }
                
                // Shape selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Zone Shape")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        ForEach(ShapeType.allCases, id: \.self) { shape in
                            ShapeOptionCard(
                                shape: shape,
                                isSelected: selectedShape == shape,
                                onTap: { selectedShape = shape }
                            )
                        }
                    }
                }
                
                Spacer()
                
                // Next button
                Button(action: onNext) {
                    Text("Next")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(vaultName.isEmpty ? Color.gray : Color.orange)
                        .cornerRadius(12)
                }
                .disabled(vaultName.isEmpty)
            }
            .padding()
        }
    }
}

struct ShapeOptionCard: View {
    let shape: ShapeType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: shape == .circle ? "circle" : "square")
                    .font(.system(size: 40))
                    .foregroundColor(isSelected ? .orange : .secondary)
                
                Text(shape.rawValue)
                    .font(.subheadline)
                    .foregroundColor(isSelected ? .orange : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.orange : Color.gray.opacity(0.3), lineWidth: 2)
            )
        }
    }
}

// MARK: - Step 2: App Selection

struct AppSelectionView: View {
    @Binding var selectedApps: Set<String>
    let onNext: () -> Void
    @State private var searchText = ""
    @StateObject private var viewModel = AppListViewModel()

    private var filteredApps: [MockApp] {
        if searchText.isEmpty {
            return viewModel.apps
        }
        return viewModel.apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search apps", text: $searchText)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding()
            
            // Selected count
            if !selectedApps.isEmpty {
                HStack {
                    Text("\(selectedApps.count) app\(selectedApps.count == 1 ? "" : "s") selected")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Clear All") {
                        selectedApps.removeAll()
                    }
                    .font(.subheadline)
                    .foregroundColor(.orange)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            
            // Apps list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredApps) { app in
                        AppToggleRow(
                            app: app,
                            isSelected: selectedApps.contains(app.name),
                            onToggle: {
                                if selectedApps.contains(app.name) {
                                    selectedApps.remove(app.name)
                                } else {
                                    selectedApps.insert(app.name)
                                }
                            }
                        )
                        
                        if app.id != filteredApps.last?.id {
                            Divider()
                                .padding(.leading, 70)
                        }
                    }
                }
            }
            
            // Next button
            Button(action: onNext) {
                Text("Next")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedApps.isEmpty ? Color.gray : Color.orange)
                    .cornerRadius(12)
            }
            .disabled(selectedApps.isEmpty)
            .padding()
        }
        .onAppear {
            viewModel.loadIcons()
        }
    }
}

// MARK: - AppToggleRow with real icons

struct AppToggleRow: View {
    let app: MockApp
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 16) {
                // App icon
                if let url = app.iconURL {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(width: 44, height: 44)
                                .cornerRadius(10)
                        } else if phase.error != nil {
                            Image(systemName: "app.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 44, height: 44)
                                .foregroundColor(.gray)
                        } else {
                            ProgressView()
                                .frame(width: 44, height: 44)
                        }
                    }
                } else {
                    Image(systemName: "app.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .foregroundColor(.gray)
                }
                
                // App name
                Text(app.name)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Toggle
                Toggle("", isOn: .constant(isSelected))
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
                    .allowsHitTesting(false)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - ViewModel for icon fetching

@MainActor
class AppListViewModel: ObservableObject {
    @Published var apps: [MockApp] = AppList.popularApps

    func loadIcons() {
        for i in apps.indices {
            AppIconFetcher.fetchIconURL(for: apps[i].bundleId) { url in
                DispatchQueue.main.async {
                    self.apps[i].iconURL = url
                }
            }
        }
    }
}
