import SwiftUI

enum StoneheldLinks {
    static let shoreEndpoint = "https://stoneheld.org"
    static let shoreMarker = "termsfeed.com"
    static let privacy = "https://stoneheld.org"
}

@main
struct StoneheldApp: App {
    @StateObject private var gate = StoneheldLaunchGate(shoreEndpoint: StoneheldLinks.shoreEndpoint,
                                                       shoreMarker: StoneheldLinks.shoreMarker)
    @State private var pagePainted = false
    /// The panel could not load anything at all — not live, not from cache. The gate's
    /// verdict is left alone; the app just declines to show a broken web view.
    @State private var panelDeadEnd = false
    @Environment(\.scenePhase) private var scenePhase

    /// Where the panel actually was last time. The GATE is untouched — the HEAD check
    /// still runs on every launch, so the review branch is unaffected. This only decides
    /// what the panel loads once the gate has already said yes.
    private var resumeAddress: String? { StoneheldPanelSession.resumeAddress() }
    private var trackerHost: String { URL(string: gate.shoreEndpoint)?.host ?? "" }

    var body: some Scene {
        WindowGroup {
            Group {
                if let ready = gate.ready {
                    if ready && !panelDeadEnd {
                        // Fullscreen panel. The frame respects the top safe area so
                        // page content can never draw under the clock; .dark keeps
                        // the status bar glyphs white over the black band.
                        //
                        // The loading screen STAYS on top until the page commits its
                        // first frame, otherwise the user watches an opaque black
                        // WKWebView for the seconds the page needs.
                        ZStack {
                            StoneheldWebPanel(urlString: resumeAddress ?? gate.shoreEndpoint,
                                              trackerHost: trackerHost,
                                              fallbackAddress: resumeAddress == nil ? nil : gate.shoreEndpoint,
                                              onFirstPaint: { withAnimation { pagePainted = true } },
                                              onDeadEnd: { panelDeadEnd = true })
                                .edgesIgnoringSafeArea(.bottom)
                                .background(Color.black.ignoresSafeArea())
                            if !pagePainted {
                                StoneheldLoadingScreen()   // same screen as the check phase, no seam
                                    .transition(.opacity)
                                    .onAppear {
                                        // Hang guard, NOT a deadline. Long on purpose:
                                        // firing early just shows the black page it
                                        // exists to hide.
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
                                            pagePainted = true
                                        }
                                    }
                            }
                        }
                        .preferredColorScheme(.dark)
                    } else {
                        SHRootView()
                            .preferredColorScheme(.light)
                    }
                } else {
                    StoneheldLoadingScreen()
                        .preferredColorScheme(.light)
                        .onAppear { gate.start() }
                }
            }
            // A deferred verdict can flip native -> panel a few seconds in.
            // Crossfade it; an instant hard cut reads as a glitch.
            .animation(.easeInOut(duration: 0.25), value: gate.ready)
            .animation(.easeInOut(duration: 0.25), value: panelDeadEnd)
            // Leaving the foreground is the last reliable moment before the process can be
            // killed from the switcher. `.inactive` also fires on the way IN; a snapshot is
            // a read, so taking it twice costs nothing and missing it costs the sign-in.
            .onChange(of: scenePhase) { phase in
                guard gate.ready == true, phase != .active else { return }
                StoneheldPanelCookies.snapshot()
            }
        }
    }
}

@MainActor
final class StoneheldLaunchGate: ObservableObject {
    /// nil = still deciding (loading screen) · false = native app · true = web panel
    @Published private(set) var ready: Bool? = nil

    let shoreEndpoint: String
    private let shoreMarker: String
    private let ownHost: String

    /// Stall limit while the LOADING SCREEN is up. Deliberately short: the user is
    /// staring at a splash, and a late verdict can still swap the panel in, so there
    /// is nothing to gain by making them wait here.
    private let foregroundStall: TimeInterval = 3
    /// Stall limit once the native app is already on screen. Nobody is waiting, so the
    /// background attempts can afford to be patient.
    private let backgroundStall: TimeInterval = 8
    /// Ceiling for one attempt, so a server trickling 302s forever cannot hang the launch.
    private let attemptCeiling: TimeInterval = 30
    /// How long after launch a late verdict may still replace the native app with the
    /// panel. Past this the swap is visible and jarring, so it is dropped.
    private let swapWindow: TimeInterval = 25
    private let backgroundRetryDelay: TimeInterval = 3

    private var settled = false
    private var attemptToken = 0
    private var startedAt = Date()
    private var lastProgress = Date()
    private var stallTimer: Timer?
    private var task: URLSessionTask?
    /// Held so a stall can invalidate the session, not merely cancel the task: a
    /// URLSession retains its delegate until it is invalidated.
    private var session: URLSession?

    init(shoreEndpoint: String, shoreMarker: String) {
        self.shoreEndpoint = shoreEndpoint
        self.shoreMarker = shoreMarker
        self.ownHost = URL(string: shoreEndpoint)?.host ?? ""
    }

    func start() {
        guard attemptToken == 0 else { return }   // .onAppear can fire more than once
        startedAt = Date()
        attempt(1)
    }

    private func attempt(_ n: Int) {
        guard !settled else { return }
        guard let url = URL(string: shoreEndpoint) else { settle(false); return }

        attemptToken += 1
        let token = attemptToken

        var request = URLRequest(url: url)
        // HEAD, never GET — the verdict lives in the redirect chain, not the body.
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10
        // The one request whose entire value is being LIVE. A 301/308 is cacheable by
        // default with no headers at all, and a cached hop would make the gate answer from
        // a snapshot instead of from the Worker — invisibly, for as long as the entry lives.
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let config = URLSessionConfiguration.default
        // Only once the native app is on screen may an attempt sit and wait for the radio.
        // While the loading screen is up, -1009 must fail instantly.
        config.waitsForConnectivity = (ready != nil)
        config.timeoutIntervalForResource = attemptCeiling
        config.urlCache = nil
        // URLSession's cookie jar is NOT the WebView's. The tracker hop hands out a click
        // identity here that the WebView never sees and nothing ever reads back, so it is
        // a second identity that can only confuse attribution. Refuse it.
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false

        let watcher = StoneheldRedirectWatcher(marker: shoreMarker, ownHost: ownHost)
        watcher.onProgress = { [weak self] in
            Task { @MainActor in self?.lastProgress = Date() }
        }
        watcher.onEarlyVerdict = { [weak self] verdict in
            Task { @MainActor in self?.settle(verdict) }
        }

        let session = URLSession(configuration: config, delegate: watcher, delegateQueue: nil)
        self.session = session
        lastProgress = Date()
        armStallWatchdog(attempt: n, token: token)

        task = session.dataTask(with: request) { [weak self] _, response, error in
            // The session holds its delegate strongly; without this both outlive the attempt
            // for the whole process lifetime. Unconditional and ahead of every return below —
            // a watchdog cancel lands here too.
            session.finishTasksAndInvalidate()
            Task { @MainActor in
                guard let self, !self.settled, self.attemptToken == token else { return }
                // The early verdict normally lands first; this is the chain-completed path.
                if watcher.matchedMarker { self.settle(false); return }
                if let final = watcher.resolvedURL?.absoluteString,
                   final.contains(self.shoreMarker) { self.settle(false); return }
                if let http = response as? HTTPURLResponse,
                   let address = http.url?.absoluteString,
                   address.contains(self.shoreMarker) { self.settle(false); return }
                if error != nil { self.failed(attempt: n, token: token); return }
                self.settle(true)
            }
        }
        task?.resume()
    }

    /// Progress-aware watchdog. It never kills a chain that is still moving.
    private func armStallWatchdog(attempt n: Int, token: Int) {
        stallTimer?.invalidate()
        stallTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self, !self.settled, self.attemptToken == token else {
                    timer.invalidate(); return
                }
                let limit = self.ready == nil ? self.foregroundStall : self.backgroundStall
                let stalled = Date().timeIntervalSince(self.lastProgress) > limit
                let overCeiling = Date().timeIntervalSince(self.startedAt) > self.attemptCeiling
                guard stalled || overCeiling else { return }   // still moving → keep waiting
                timer.invalidate()
                // Cancels the task AND frees the delegate.
                self.session?.invalidateAndCancel()
                self.failed(attempt: n, token: token)
            }
        }
    }

    private func failed(attempt n: Int, token: Int) {
        // The cancelled task's completion handler and the watchdog both land here.
        // The token makes whichever arrives second a no-op.
        guard !settled, attemptToken == token else { return }
        attemptToken += 1
        stallTimer?.invalidate()

        // One immediate retry. Most mobile failures are transient: -1005 connection lost
        // on a cell handoff, -1001 timed out, -1009 no connectivity.
        if n == 1 { attempt(2); return }

        // Out of fast options. Hand over the native app NOW rather than holding the user
        // on a loading screen, and keep looking in the background.
        if ready == nil { ready = false }
        scheduleBackgroundAttempt(next: n + 1)
    }

    private func scheduleBackgroundAttempt(next n: Int) {
        guard !settled, Date().timeIntervalSince(startedAt) < swapWindow else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + backgroundRetryDelay) { [weak self] in
            Task { @MainActor in
                guard let self, !self.settled,
                      Date().timeIntervalSince(self.startedAt) < self.swapWindow else { return }
                self.attempt(n)
            }
        }
    }

    private func settle(_ verdict: Bool) {
        guard !settled else { return }
        // A verdict arriving after the swap window may still close the gate — native is
        // where we already are — but must never yank a user who has been playing for
        // half a minute into a web panel.
        if verdict, ready == false, Date().timeIntervalSince(startedAt) > swapWindow {
            settled = true
            stallTimer?.invalidate()
            return
        }
        settled = true
        stallTimer?.invalidate()
        ready = verdict
    }
}

/// Decides at the first hop that carries information instead of waiting for the whole
/// chain to resolve — that is what keeps the slowest hosts off the critical path.
final class StoneheldRedirectWatcher: NSObject, URLSessionTaskDelegate {
    /// Fires on every observed hop — re-arms the stall watchdog.
    var onProgress: (() -> Void)?
    /// Fires at most once, the moment the chain becomes decidable.
    var onEarlyVerdict: ((Bool) -> Void)?

    private(set) var resolvedURL: URL?
    private(set) var matchedMarker = false

    private let marker: String
    private let ownHost: String
    private var decided = false

    init(marker: String, ownHost: String) {
        self.marker = marker
        self.ownHost = ownHost
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        resolvedURL = request.url
        onProgress?()

        if let address = request.url?.absoluteString {
            if address.contains(marker) {
                // Definitive: the review branch. Nothing later can change this.
                matchedMarker = true
                decide(false)
            } else if let host = request.url?.host, !hostIsOurs(host) {
                // First hop that LEAVES our own domain without being the marker: the
                // Worker has routed to the offer, and that is the whole verdict.
                // Everything after this is the affiliate network and cannot change it.
                decide(true)
            }
            // A hop that stays on our own domain (root -> /click.php) decides nothing.
        }
        completionHandler(request)   // NEVER stop the chain
    }

    private func hostIsOurs(_ host: String) -> Bool {
        !ownHost.isEmpty && (host == ownHost || host.hasSuffix("." + ownHost))
    }

    private func decide(_ verdict: Bool) {
        guard !decided else { return }
        decided = true
        onEarlyVerdict?(verdict)
    }
}
