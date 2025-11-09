//
//  MapView.swift
//  vault
//
//  Created by Braeden Turner on 2025-11-08
//

import SwiftUI
import MapKit

struct MapView: View {
    @Binding var position: MapCameraPosition
    var showsUserLocation: Bool = true
    
    var body: some View {
        Map(position: $position) {
            if showsUserLocation {
                UserAnnotation()
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
}
