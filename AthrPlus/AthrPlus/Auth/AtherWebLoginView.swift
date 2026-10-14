//
//  AtherWebLoginView.swift
//  AthrPlus
//
//  Zero-proxy in-app web login using WKWebView to authenticate via Ather's web portal.
//

import SwiftUI
import WebKit

public struct AtherWebLoginView: View {
    @ObservedObject public var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading: Bool = true
    @State private var currentURL: String = "https://app.atherenergy.com"
    @State private var webViewRef: WKWebView? = nil

    private let brandGreen = Color(red: 0.13, green: 0.77, blue: 0.36)

    public init(viewModel: AuthViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AtherWebViewRepresentable(
                    viewModel: viewModel,
                    isLoading: $isLoading,
                    currentURL: $currentURL,
                    webViewRef: $webViewRef,
                    onTokenFound: { token in
                        Task { @MainActor in
                            await viewModel.loginWithToken(token)
                            dismiss()
                        }
                    }
                )
                .ignoresSafeArea(edges: .bottom)

                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading Ather Portal...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.1), radius: 10)
                }
            }
            .navigationTitle("Sign in with OTP")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        extractTokenManually()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Done")
                        }
                        .foregroundColor(brandGreen)
                        .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    private func extractTokenManually() {
        guard let webView = webViewRef else { return }
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
            for cookie in cookies {
                if cookie.name.lowercased().contains("token") || cookie.name.lowercased().contains("auth") {
                    let val = cookie.value
                    if val.hasPrefix("eyJ") || val.count > 25 {
                        Task { @MainActor in
                            await viewModel.loginWithToken(val)
                            dismiss()
                        }
                        return
                    }
                }
            }
        }

        let js = "localStorage.getItem('token') || localStorage.getItem('auth_token') || localStorage.getItem('accessToken') || sessionStorage.getItem('token')"
        webView.evaluateJavaScript(js) { result, _ in
            if let token = result as? String, !token.isEmpty {
                Task { @MainActor in
                    await viewModel.loginWithToken(token)
                    dismiss()
                }
            }
        }
    }
}

struct AtherWebViewRepresentable: UIViewRepresentable {
    @ObservedObject var viewModel: AuthViewModel
    @Binding var isLoading: Bool
    @Binding var currentURL: String
    @Binding var webViewRef: WKWebView?
    var onTokenFound: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"

        DispatchQueue.main.async {
            self.webViewRef = webView
        }

        if let url = URL(string: "https://app.atherenergy.com") {
            let request = URLRequest(url: url)
            webView.load(request)
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: AtherWebViewRepresentable

        init(_ parent: AtherWebViewRepresentable) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                if let url = webView.url?.absoluteString {
                    self.parent.currentURL = url
                }
            }

            checkForAuthToken(in: webView)
        }

        private func checkForAuthToken(in webView: WKWebView) {
            // 1. Check cookies
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
                guard let self = self else { return }
                for cookie in cookies {
                    let name = cookie.name.lowercased()
                    if name.contains("token") || name.contains("auth") {
                        let value = cookie.value
                        if value.hasPrefix("eyJ") || value.count > 30 {
                            self.parent.onTokenFound(value)
                            return
                        }
                    }
                }
            }

            // 2. Check localStorage & sessionStorage
            let script = """
            (function() {
                try {
                    for (var i = 0; i < localStorage.length; i++) {
                        var k = localStorage.key(i);
                        var v = localStorage.getItem(k);
                        if (v && (v.startsWith('eyJ') || (k && k.toLowerCase().indexOf('token') !== -1))) {
                            return v;
                        }
                    }
                } catch(e) {}
                return null;
            })();
            """
            webView.evaluateJavaScript(script) { [weak self] result, _ in
                guard let self = self else { return }
                if let token = result as? String, (token.hasPrefix("eyJ") || token.count > 30) {
                    self.parent.onTokenFound(token)
                }
            }
        }
    }
}
