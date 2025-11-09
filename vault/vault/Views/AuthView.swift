//
//  AuthView.swift
//  vault
//
//  Login and Registration Screen
//

import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let htmlString: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(htmlString, baseURL: nil)
    }
}

struct AuthView: View {
    @State private var isLogin = true
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isKeyboardVisible = false
    @Binding var isAuthenticated: Bool
    @Binding var currentUserId: Int?
    
  var body: some View {
      ZStack {
          // Background gradient
          LinearGradient(
              colors: [Color.orange.opacity(0.6), Color.orange.opacity(0.3)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
          )
          .ignoresSafeArea()
          
          VStack(spacing: 30) {
              Spacer()
              
              // Logo/Title
              VStack(spacing: 8) {
                  // Animated vault SVG - hidden when keyboard is visible
                  if !isKeyboardVisible {
                      WebView(htmlString: """
                      <!DOCTYPE html>
                      <html>
                      <head>
                          <meta name="viewport" content="width=device-width, initial-scale=1.0">
                          <style>
                              body {
                                  margin: 0;
                                  padding: 0;
                                  background: transparent;
                                  display: flex;
                                  justify-content: center;
                                  align-items: center;
                                  height: 100vh;
                                  width: 100vw;
                              }
                              svg {
                                  max-width: 100%;
                                  max-height: 100%;
                              }
                          </style>
                      </head>
                      <body>
                          \(SVGs.vaultAnimated)
                      </body>
                      </html>
                      """)
                      .frame(width: 100, height: 100)
                      .transition(.opacity)
                  }
                  
                Text("VAULT")
                    .font(.custom("Futura-CondensedExtraBold", size: 48))
                    .foregroundColor(.white)
              }
              .padding(.bottom, 20)
              
              // Auth Form
              VStack(spacing: 20) {
                  // Custom Segmented Control
                  HStack {
                      Spacer()
                      
                      Button(action: {
                          withAnimation(.easeInOut(duration: 0.25)) {
                              isLogin = true
                          }
                      }) {
                          Text("Login")
                              .font(.headline)
                              .foregroundColor(isLogin ? .white : .orange)
                              .frame(maxWidth: .infinity)
                      }
                      
                      Button(action: {
                          withAnimation(.easeInOut(duration: 0.25)) {
                              isLogin = false
                          }
                      }) {
                          Text("Register")
                              .font(.headline)
                              .foregroundColor(!isLogin ? .white : .orange)
                              .frame(maxWidth: .infinity)
                      }
                      
                      Spacer()
                  }
                  .padding(6)
                  .background(
                      ZStack(alignment: isLogin ? .leading : .trailing) {
                          RoundedRectangle(cornerRadius: 12)
                              .fill(Color.white.opacity(0.2))
                          
                          RoundedRectangle(cornerRadius: 12)
                              .fill(Color.orange)
                              .frame(width: UIScreen.main.bounds.width / 2.5)
                              .padding(.horizontal, 4)
                              .animation(.easeInOut(duration: 0.25), value: isLogin)
                      }
                  )
                  .clipShape(RoundedRectangle(cornerRadius: 12))
                  .padding(.horizontal)
                  
                  // Form fields
                  VStack(spacing: 16) {
                      if !isLogin {
                          TextField("Full Name", text: $name)
                              .textFieldStyle(RoundedTextFieldStyle())
                              .autocapitalization(.words)
                              .foregroundColor(.black)
                      }
                      
                      TextField("Email", text: $email)
                          .textFieldStyle(RoundedTextFieldStyle())
                          .autocapitalization(.none)
                          .keyboardType(.emailAddress)
                          .foregroundColor(.black)
                      
                      SecureField("Password", text: $password)
                          .textFieldStyle(RoundedTextFieldStyle())
                          .foregroundColor(.black)
                      
                      if !isLogin {
                          SecureField("Confirm Password", text: $confirmPassword)
                              .textFieldStyle(RoundedTextFieldStyle())
                              .foregroundColor(.black)
                      }
                  }
                  .padding(.horizontal)
                  
                  // Error message
                  if showError {
                      Text(errorMessage)
                          .font(.caption)
                          .foregroundColor(.red)
                          .padding(.horizontal)
                  }
                  
                  // Submit button
                  Button(action: handleSubmit) {
                      Text(isLogin ? "Login" : "Register")
                          .font(.headline)
                          .foregroundColor(.orange)
                          .frame(maxWidth: .infinity)
                          .padding()
                          .background(Color.white)
                          .cornerRadius(12)
                          .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                  }
                  .padding(.horizontal)
                  .padding(.top, 10)
              }
              .padding(.vertical, 30)
              .background(
                  RoundedRectangle(cornerRadius: 20)
                      .fill(Color.white.opacity(0.95))
              )
              .padding(.horizontal, 20)
              
              Spacer()
          }
      }
      .onChange(of: isLogin) { _, _ in
          showError = false
          errorMessage = ""
      }
      .onAppear {
          // Listen for keyboard show notification
          NotificationCenter.default.addObserver(
              forName: UIResponder.keyboardWillShowNotification,
              object: nil,
              queue: .main
          ) { _ in
              withAnimation(.easeInOut(duration: 0.2)) {
                  isKeyboardVisible = true
              }
          }
          
          // Listen for keyboard hide notification
          NotificationCenter.default.addObserver(
              forName: UIResponder.keyboardWillHideNotification,
              object: nil,
              queue: .main
          ) { _ in
              withAnimation(.easeInOut(duration: 0.2)) {
                  isKeyboardVisible = false
              }
          }
      }
  }
    
    private func handleSubmit() {
        showError = false
        
        // Validation
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all fields"
            showError = true
            return
        }
        
        if !isLogin {
            guard !name.isEmpty else {
                errorMessage = "Please enter your name"
                showError = true
                return
            }
            
            guard password == confirmPassword else {
                errorMessage = "Passwords do not match"
                showError = true
                return
            }
            
            guard password.count >= 6 else {
                errorMessage = "Password must be at least 6 characters"
                showError = true
                return
            }
            
            // Register
            let result = DatabaseManager.shared.registerUser(name: name, email: email, password: password)
            if result.success, let userId = result.userId {
                currentUserId = userId
                isAuthenticated = true
            } else {
                errorMessage = result.error ?? "Registration failed"
                showError = true
            }
        } else {
            // Login
            let result = DatabaseManager.shared.loginUser(email: email, password: password)
            if result.success, let userId = result.userId {
                currentUserId = userId
                isAuthenticated = true
            } else {
                errorMessage = "Invalid email or password"
                showError = true
            }
        }
    }
}

// Custom text field style
struct RoundedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.white)
            .cornerRadius(10)
            .foregroundColor(.black)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
    }
}
