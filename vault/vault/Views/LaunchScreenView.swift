//
//  LaunchScreenView.swift
//  vault
//

import SwiftUI

struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            // Same gradient as AuthView
            LinearGradient(
                colors: [Color.orange.opacity(0.6), Color.orange.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Your custom vault icon from Assets
                Image("VaultIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                
                Text("VAULT")
                    .font(.custom("Futura-CondensedExtraBold", size: 48))
                    .foregroundColor(.white)
            }
        }
    }
}
