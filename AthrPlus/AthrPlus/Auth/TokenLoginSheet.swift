//
//  TokenLoginSheet.swift
//  AthrPlus
//
//  Reusable "Sign in with Ather Token" sheet, presented from the login and OTP screens.
//

import SwiftUI

/// Sheet that connects an Ather account by pasting an existing Bearer token.
struct TokenLoginSheet: View {
    @ObservedObject var viewModel: AuthViewModel

    private let brandGreen = Color(red: 0.13, green: 0.77, blue: 0.36)

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Ather Account Token")
                    .font(.headline)
                    .padding(.top, 8)

                Text("Ather's servers enforce Firebase App Check on account sign-in for third-party apps. The OTP screen confirms your number, but completing the login requires your Ather Bearer token — paste it below to connect directly.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .lineSpacing(3)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("TOKEN")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        Spacer()
                        if let clip = UIPasteboard.general.string, !clip.isEmpty {
                            Button("Paste from Clipboard") {
                                viewModel.tokenInput = clip
                            }
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(brandGreen)
                        }
                    }

                    TextEditor(text: $viewModel.tokenInput)
                        .frame(height: 110)
                        .font(.system(.footnote, design: .monospaced))
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                }

                Button {
                    Task {
                        await viewModel.loginWithToken(viewModel.tokenInput)
                    }
                } label: {
                    HStack {
                        Image(systemName: "bolt.fill")
                        Text("Connect Scooter")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(!viewModel.tokenInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? brandGreen : brandGreen.opacity(0.4))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(viewModel.tokenInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                VStack(alignment: .leading, spacing: 6) {
                    Text("How to obtain your token:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text("• Option A: From Android app data (/data/data/com.athermobileapp/shared_prefs/)\n• Option B: Via HTTP proxy (PCAPdroid, Reqable, or Proxyman) on your phone when opening the official Ather app.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineSpacing(2)
                }
                .padding(12)
                .background(Color(.secondarySystemBackground).opacity(0.7))
                .cornerRadius(10)

                Spacer()
            }
            .padding(20)
            .navigationTitle("Token Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.showTokenLoginSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
