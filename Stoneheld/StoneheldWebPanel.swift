import SwiftUI
import WebKit

struct StoneheldWebPanel: UIViewRepresentable {
    let urlString: String
    var onFirstPaint: (() -> Void)? = nil

    final class Coordinator: NSObject, WKNavigationDelegate {
        var onFirstPaint: (() -> Void)?
        private var fired = false
        // didCommit, not didFinish — didFinish lands seconds after the page is usable.
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) { fire() }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                     withError error: Error) {
            let ns = error as NSError
            // A cancelled load is an ordinary redirect, not a failure.
            if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled { return }
            fire()
        }
        private func fire() { guard !fired else { return }; fired = true; onFirstPaint?() }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        // Required: the frame extends under the home indicator, and this is what
        // insets scrollable content back out of it. Never .never.
        webView.scrollView.contentInsetAdjustmentBehavior = .always
        webView.isOpaque = true
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        // The presenting branch runs in the dark scheme so the status bar glyphs
        // stay white; pin the page itself back to light.
        webView.overrideUserInterfaceStyle = .light
        context.coordinator.onFirstPaint = onFirstPaint
        webView.navigationDelegate = context.coordinator
        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    // MUST NEVER reload here — reloading causes an infinite reload loop.
    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.onFirstPaint = onFirstPaint
    }
}
