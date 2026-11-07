import SwiftUI
import WebKit

final class BrowserModel: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    @Published var address = ""
    @Published var title = ""
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var progress: Double = 0
    @Published var pendingMedia: URL? = nil
    let webView: WKWebView
    private var observers: [NSKeyValueObservation] = []
    static let videoExts: Set<String> = ["mp4", "m4v", "mov", "webm", "mkv", "avi", "3gp", "mp3", "m4a"]

    override init() {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        cfg.allowsPictureInPictureMediaPlayback = true
        if #available(iOS 15.4, *) { cfg.preferences.isElementFullscreenEnabled = true }
        webView = WKWebView(frame: .zero, configuration: cfg)
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = .black
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        observers = [
            webView.observe(\.estimatedProgress) { [weak self] w, _ in DispatchQueue.main.async { self?.progress = w.estimatedProgress } },
            webView.observe(\.canGoBack) { [weak self] w, _ in DispatchQueue.main.async { self?.canGoBack = w.canGoBack } },
            webView.observe(\.canGoForward) { [weak self] w, _ in DispatchQueue.main.async { self?.canGoForward = w.canGoForward } },
            webView.observe(\.title) { [weak self] w, _ in DispatchQueue.main.async { self?.title = w.title ?? "" } },
            webView.observe(\.url) { [weak self] w, _ in DispatchQueue.main.async { if let u = w.url { self?.address = u.absoluteString } } },
        ]
    }

    func go() {
        var s = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return }
        if !s.contains("://") {
            if s.contains(".") && !s.contains(" ") { s = "https://" + s }
            else { s = "https://duckduckgo.com/?q=" + (s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s) }
        }
        guard let u = URL(string: s) else { return }
        if Self.isMedia(u) { pendingMedia = u; return }
        webView.load(URLRequest(url: u))
    }

    static func isMedia(_ u: URL) -> Bool { videoExts.contains(u.pathExtension.lowercased()) }

    // Intercept direct media files
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let u = navigationAction.request.url, Self.isMedia(u), navigationAction.targetFrame?.isMainFrame ?? true {
            DispatchQueue.main.async { self.pendingMedia = u }
            decisionHandler(.cancel); return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if navigationResponse.isForMainFrame, let mime = navigationResponse.response.mimeType, mime.hasPrefix("video/"), let u = navigationResponse.response.url {
            DispatchQueue.main.async { self.pendingMedia = u }
            decisionHandler(.cancel); return
        }
        decisionHandler(.allow)
    }

    // target=_blank links open in the same view
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil { webView.load(navigationAction.request) }
        return nil
    }

    // Long-press on a link: offer play / download
    func webView(_ webView: WKWebView, contextMenuConfigurationForElement elementInfo: WKContextMenuElementInfo, completionHandler: @escaping (UIContextMenuConfiguration?) -> Void) {
        guard let link = elementInfo.linkURL else { completionHandler(nil); return }
        let cfg = UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { suggested in
            let play = UIAction(title: "تشغيل في المشغّل", image: UIImage(systemName: "play.circle")) { [weak self] _ in
                DispatchQueue.main.async { self?.pendingMedia = link }
            }
            let dl = UIAction(title: "تحميل الملف", image: UIImage(systemName: "arrow.down.circle")) { _ in
                DownloadManager.shared.start(title: link.lastPathComponent, url: link)
            }
            let mine: [UIMenuElement] = [play, dl]
            return UIMenu(title: link.absoluteString, children: mine + suggested)
        }
        completionHandler(cfg)
    }
}

struct WebViewHost: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct BrowserView: View {
    @StateObject private var model = BrowserModel()
    @EnvironmentObject var player: PlayerCoordinator
    @EnvironmentObject var downloads: DownloadManager
    @State private var showMediaSheet = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "globe").foregroundColor(Theme.text2)
                TextField("اكتب رابطاً أو ابحث", text: $model.address, onCommit: { model.go() })
                    .keyboardType(.webSearch)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .foregroundColor(.white)
                    .environment(\.layoutDirection, .leftToRight)
                if !model.address.isEmpty {
                    Button { model.address = "" } label: { Image(systemName: "xmark.circle.fill").foregroundColor(Theme.text2) }
                }
            }
            .padding(10).background(Theme.surface2).cornerRadius(10)
            .padding(.horizontal).padding(.vertical, 8)

            if model.progress > 0 && model.progress < 1 {
                ProgressView(value: model.progress).tint(Theme.accent).padding(.horizontal)
            }

            ZStack {
                WebViewHost(webView: model.webView)
                if model.webView.url == nil {
                    EmptyStateView(icon: "safari", title: "المتصفح", message: "افتح أي موقع. عند فتح رابط فيديو مباشر (mp4) يمكنك تشغيله أو تحميله، أو اضغط مطولاً على أي رابط.")
                        .background(Theme.bg)
                }
            }

            HStack {
                Button { model.webView.goBack() } label: { Image(systemName: "chevron.forward") }.disabled(!model.canGoBack)
                Spacer()
                Button { model.webView.goForward() } label: { Image(systemName: "chevron.backward") }.disabled(!model.canGoForward)
                Spacer()
                Button { model.webView.reload() } label: { Image(systemName: "arrow.clockwise") }
                Spacer()
                Button {
                    if let u = model.webView.url { UIPasteboard.general.string = u.absoluteString }
                } label: { Image(systemName: "doc.on.doc") }
            }
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(Theme.accent)
            .padding(.horizontal, 30).padding(.vertical, 10)
            .background(Theme.surface)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle(model.title.isEmpty ? "المتصفح" : model.title)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: model.pendingMedia) { v in showMediaSheet = v != nil }
        .confirmationDialog("ملف فيديو", isPresented: $showMediaSheet, titleVisibility: .visible) {
            if let u = model.pendingMedia {
                Button("تشغيل") { player.play(u, title: u.lastPathComponent); model.pendingMedia = nil }
                Button("تحميل") { downloads.start(title: u.lastPathComponent, url: u); model.pendingMedia = nil }
            }
            Button("إلغاء", role: .cancel) { model.pendingMedia = nil }
        } message: {
            Text(model.pendingMedia?.lastPathComponent ?? "")
        }
    }
}
