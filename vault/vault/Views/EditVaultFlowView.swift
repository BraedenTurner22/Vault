//
//  EditVaultFlowView.swift
//  vault
//
//  Edit existing vault flow
//

import SwiftUI
import CoreLocation
import MapKit

struct EditVaultFlowView: View {
    @Binding var isPresented: Bool
    @Binding var vaultLocations: [VaultLocation]
    let vaultToEdit: VaultLocation
    let userLocation: CLLocation?
    let userId: Int
    
    @State private var currentStep: VaultCreationStep = .nameAndShape
    @State private var vaultName: String
    @State private var selectedShape: ShapeType
    @State private var selectedApps: Set<String>
    
    init(isPresented: Binding<Bool>, vaultLocations: Binding<[VaultLocation]>, vaultToEdit: VaultLocation, userLocation: CLLocation?, userId: Int) {
        self._isPresented = isPresented
        self._vaultLocations = vaultLocations
        self.vaultToEdit = vaultToEdit
        self.userLocation = userLocation
        self.userId = userId
        
        // Initialize with existing vault data
        _vaultName = State(initialValue: vaultToEdit.name)
        
        // Determine shape type from vault
        switch vaultToEdit.shape {
        case .circle:
            _selectedShape = State(initialValue: .circle)
        case .quadrilateral:
            _selectedShape = State(initialValue: .quadrilateral)
        }
        
        _selectedApps = State(initialValue: Set(vaultToEdit.blockedApps))
    }
    
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
                            EmptyView()
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
            
            // Map placement overlay - now uses unified MapPlacementView
            if currentStep == .mapPlacement {
                MapPlacementView(
                    isPresented: $isPresented,
                    vaultName: vaultName,
                    shapeType: selectedShape,
                    selectedApps: Array(selectedApps),
                    userLocation: userLocation,
                    userId: userId,
                    vaultToEdit: vaultToEdit,  // Pass the vault to edit
                    onSave: { updatedVault in
                        // Replace the old vault with the updated one
                        if let index = vaultLocations.firstIndex(where: { $0.id == vaultToEdit.id }) {
                            vaultLocations[index] = updatedVault
                        }
                        isPresented = false
                    }
                )
            }
        }
    }
    
    private var stepTitle: String {
        switch currentStep {
        case .nameAndShape: return "Edit Vault"
        case .appSelection: return "Edit Apps"
        case .mapPlacement: return "Edit Zone"
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
