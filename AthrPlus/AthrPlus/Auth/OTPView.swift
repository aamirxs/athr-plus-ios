//
//  OTPView.swift
//  AthrPlus
//
//  6-digit OTP verification screen with SMS autofill, custom digit boxes, and resend timer.
//

import SwiftUI

/// 6-digit OTP entry and verification screen for Athr+.
public struct OTPView: View {
    @ObservedObject public var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFieldFocused: Bool

    // Brand accent color
    private let brandGreen = Color(red: 0.13, green: 0.77, blue: 0.36)

    public init(viewModel: AuthViewModel) {
        self.viewModel = viewModel
    }

    private var otpDigits: [String] {
        let clean = viewModel.otp.filter { $0.isNumber }
        return (0..<6).map { index in
            if index < clean.count {
                let stringIndex = clean.index(clean.startIndex, offsetBy: index)
                return String(clean[stringIndex])
            }
            return ""
        }
    }

    public var body: some View {
        ZStack {
            // Background
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
                .onTapGesture {
                    isFieldFocused = false
                }

            ScrollView {
                VStack(spacing: 32) {
                    // Header Section
                    VStack(spacing: 10) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 48))
                            .foregroundColor(brandGreen)
                            .padding(.top, 24)

                        Text("Enter verification code")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)

                        Text("Sent to \(viewModel.maskedPhoneNumber)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    // 6-Digit OTP Boxes Card
                    VStack(spacing: 20) {
                        ZStack {
                            // Hidden textfield capturing keyboard & SMS autofill
                            TextField("", text: Binding(
                                get: { viewModel.otp },
                                set: { newValue in
                                    let numbersOnly = newValue.filter { $0.isNumber }
                                    if numbersOnly.count <= 6 {
                                        viewModel.otp = numbersOnly
                                    } else {
                                        viewModel.otp = String(numbersOnly.prefix(6))
                                    }

                                    // Auto-verify when 6th digit is reached
                                    if viewModel.otp.count == 6 {
                                        isFieldFocused = false
                                        Task {
                                            await viewModel.verifyOTP()
                                        }
                                    }
                                }
                            ))
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .focused($isFieldFocused)
                            .accentColor(.clear)
                            .foregroundColor(.clear)
                            .opacity(0.01)
                            .frame(maxWidth: .infinity, maxHeight: 60)

                            // Visual 6-digit display boxes
                            HStack(spacing: 10) {
                                ForEach(0..<6, id: \.self) { index in
                                    let digit = otpDigits[index]
                                    let isCurrent = isFieldFocused && (
                                        (viewModel.otp.count == index) || (index == 5 && viewModel.otp.count == 6)
                                    )

                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(.secondarySystemBackground))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(isCurrent ? brandGreen : Color.clear, lineWidth: 2)
                                            )
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 56)

                                        Text(digit)
                                            .font(.title2.monospacedDigit().bold())
                                            .foregroundColor(.primary)
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        isFieldFocused = true
                                    }
                                }
                            }
                        }

                        // Inline Error Banner if present
                        if let errorMsg = viewModel.error {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .font(.subheadline)
                                Text(errorMsg)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .transition(.opacity)
                        }
                    }
                    .padding(20)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
                    .padding(.horizontal, 20)

                    // Verify Action Button
                    Button {
                        isFieldFocused = false
                        Task {
                            await viewModel.verifyOTP()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text("Verify")
                                .font(.headline)
                                .fontWeight(.bold)
                            Image(systemName: "checkmark")
                                .font(.subheadline.bold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(viewModel.otp.count == 6 && !viewModel.isLoading ? brandGreen : brandGreen.opacity(0.4))
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .shadow(color: viewModel.otp.count == 6 ? brandGreen.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
                    }
                    .disabled(viewModel.otp.count < 6 || viewModel.isLoading)
                    .padding(.horizontal, 20)

                    // Resend Timer Row
                    VStack(spacing: 8) {
                        if viewModel.resendCountdown > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.caption)
                                Text("Resend code in \(viewModel.resendCountdown)s")
                                    .font(.subheadline.monospacedDigit())
                            }
                            .foregroundColor(.secondary)
                        } else {
                            Button {
                                Task {
                                    await viewModel.resendOTP()
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.subheadline.bold())
                                    Text("Resend OTP")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(brandGreen)
                            }
                        }
                    }
                    .padding(.top, 4)

                    Spacer(minLength: 20)
                }
            }

            // Loading Overlay
            if viewModel.isLoading {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    VStack(spacing: 14) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.3)
                        Text("Verifying code...")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .fontWeight(.medium)
                    }
                    .padding(24)
                    .background(Color(.systemGray6).opacity(0.95))
                    .cornerRadius(16)
                    .shadow(radius: 10)
                }
                .transition(.opacity)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    isFieldFocused = false
                    viewModel.authState = .loggedOut
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                        Text("Back")
                    }
                    .foregroundColor(brandGreen)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFieldFocused = true
            }
        }
    }
}

#Preview {
    let vm = AuthViewModel()
    vm.phone = "9876543210"
    vm.authState = .otpSent
    return NavigationStack {
        OTPView(viewModel: vm)
    }
}
