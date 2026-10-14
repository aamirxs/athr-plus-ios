//
//  AppCheckSheetView.swift
//  AthrPlus
//
//  Sheet to configure Firebase App Check token or exchange a Debug Token for official Ather API access.
//

import SwiftUI

public struct AppCheckSheetView: View {
    @ObservedObject public var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var debugTokenInput: String = ""
    @State private var jwtInput: String = ""
    @State private var statusMessage: String? = nil
    @State private var isProcessing: Bool = false

    private let brandGreen = Color(red: 0.13, green: 0.77, blue: 0.36)

    public init(viewModel: AuthViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Ather Gateway App Check", systemImage: "shield.checkmark.fill")
                            .font(.headline)
                            .foregroundColor(brandGreen)

                        Text("Ather's Cerberus API gateway requires an active Firebase App Check token for native OTP requests. If you are developing or testing internally, enter your Firebase Debug Token or App Check JWT below.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Firebase Debug Token (Internal Testing)") {
                    TextField("Enter Firebase Debug Token UUID", text: $debugTokenInput)
                        .font(.body.monospaced())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    Button {
                        Task {
                            isProcessing = true
                            statusMessage = nil
                            await viewModel.exchangeAppCheckDebugToken(debugTokenInput)
                            isProcessing = false
                            if viewModel.error == nil {
                                statusMessage = "Successfully activated App Check Token!"
                            }
                        }
                    } label: {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .padding(.trailing, 4)
                            }
                            Text("Exchange & Activate Token")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(brandGreen)
                    }
                    .disabled(debugTokenInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)

                    Text("Debug token UUID registered under ather-production in Firebase Console.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Section("Direct App Check JWT") {
                    TextEditor(text: $jwtInput)
                        .frame(minHeight: 80)
                        .font(.caption.monospaced())
                        .overlay(
                            Group {
                                if jwtInput.isEmpty {
                                    Text("Paste raw eyJ... token")
                                        .foregroundColor(.secondary.opacity(0.6))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 8)
                                        .allowsHitTesting(false)
                                }
                            },
                            alignment: .topLeading
                        )

                    Button("Save App Check JWT") {
                        Task {
                            await viewModel.saveAppCheckToken(jwtInput)
                            statusMessage = "App Check Token saved!"
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(brandGreen)
                    .disabled(jwtInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if let msg = statusMessage {
                    Section {
                        Text(msg)
                            .font(.footnote)
                            .foregroundColor(.green)
                    }
                }

                if let err = viewModel.error {
                    Section {
                        Text(err)
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button("Clear App Check Credentials", role: .destructive) {
                        Task {
                            await viewModel.saveAppCheckToken("")
                            debugTokenInput = ""
                            jwtInput = ""
                            statusMessage = "Cleared App Check token."
                        }
                    }
                }
            }
            .navigationTitle("App Check Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                self.debugTokenInput = viewModel.appCheckDebugTokenInput
                self.jwtInput = viewModel.appCheckTokenInput
            }
        }
    }
}
