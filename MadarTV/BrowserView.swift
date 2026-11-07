import SwiftUI
import WebKit
import AVFoundation

final class BrowserModel: NSObject, ObservableObject,
                          WKNavigationDelegate, WKUIDelegate {

    @Published var address = ""
    @Published var title = ""
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var progress: Double = 0
    @Published var pendingMedia: URL?

    let webView: WKWebView
    private var observers: [NSKeyValueObservation] = []

    static let videoExts: Set<String> = [
        "mp4", "m4v", "mov", "webm", "mkv",
        "avi", "3gp", "mp3", "m4a", "m3u8", "mpd"
    ]

    override init() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsPictureInPictureMediaPlayback = true

        if #available(iOS 15.4, *) {
            config.preferences.isElementFullscreenEnabled = true
        }

        webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = .black

        super.init()

        webView.navigationDelegate = self
        webView.uiDelegate = self

        observers = [
            webView.observe(\.estimatedProgress) { [weak self] w, _ in
                DispatchQueue.main.async {
                    self?.progress = w.estimatedProgress
                }
            },
            webView.observe(\.canGoBack) { [weak self] w, _ in
                DispatchQueue.main.async {
                    self?.canGoBack = w.canGoBack
                }
            },
            webView.observe(\.canGoForward) { [weak self] w, _ in
                DispatchQueue.main.async {
                    self?.canGoForward = w.canGoForward
                }
            },
            webView.observe(\.title) { [weak self] w, _ in
                DispatchQueue.main.async {
                    self?.title = w.title ?? ""
                }
            },
            webView.observe(\.url) { [weak self] w, _ in
                DispatchQueue.main.async {
                    if let url = w.url {
                        self?.address = url.absoluteString
                    }
                }
            }
        ]
    }

    func go() {
        var value = address.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !value.isEmpty else { return }

        if !value.contains("://") {
            if value.contains(".") && !value.contains(" ") {
                value = "https://" + value
            } else {
                let query = value.addingPercentEncoding(
                    withAllowedCharacters: .urlQueryAllowed
                ) ?? value

                value = "https://duckduckgo.com/?q=" + query
            }
        }

        guard let url = URL(string: value) else { return }

        if Self.isMedia(url) {
            pendingMedia = url
            return
        }

        webView.load(URLRequest(url: url))
    }

    static func isMedia(_ url: URL) -> Bool {
        videoExts.contains(url.pathExtension.lowercased())
    }

    private func isVideoResponse(_ response: URLResponse) -> Bool {
        let mime = response.mimeType?.lowercased() ?? ""

        if mime.hasPrefix("video/") ||
            mime.contains("mpegurl") ||
            mime.contains("dash+xml") ||
            mime.contains("audio/") {
            return true
        }

        if let url = response.url, Self.isMedia(url) {
            return true
        }

        return false
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if let url = navigationAction.request.url,
           Self.isMedia(url),
           navigationAction.targetFrame?.isMainFrame ?? true {

            DispatchQueue.main.async {
                self.pendingMedia = url
            }

            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        guard navigationResponse.isForMainFrame,
              let url = navigationResponse.response.url else {
            decisionHandler(.allow)
            return
        }

        if isVideoResponse(navigationResponse.response) {
            DispatchQueue.main.async {
                self.pendingMedia = url
            }

            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }

    func webView(
        _ webView: WKWebView,
        contextMenuConfigurationForElement elementInfo: WKContextMenuElementInfo,
        completionHandler: @escaping (UIContextMenuConfiguration?) -> Void
    ) {
        guard let link = elementInfo.linkURL else {
            completionHandler(nil)
            return
        }

        let configuration = UIContextMenuConfiguration(
            identifier: nil,
            previewProvider: nil
        ) { suggested in

            let play = UIAction(
                title: "تشغيل في المشغّل",
                image: UIImage(systemName: "play.circle")
            ) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.pendingMedia = link
                }
            }

            let download = UIAction(
                title: "تحميل الملف",
                image: UIImage(systemName: "arrow.down.circle")
            ) { _ in
                DownloadManager.shared.start(
                    title: link.lastPathComponent,
                    url: link
                )
            }

            return UIMenu(
                title: link.lastPathComponent,
                children: [play, download] + suggested
            )
        }

        completionHandler(configuration)
    }
}

struct WebViewHost: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        webView
    }

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
                Image(systemName: "globe")
                    .foregroundColor(Theme.text2)

                TextField(
                    "اكتب رابطاً أو ابحث",
                    text: $model.address,
                    onCommit: { model.go() }
                )
                .keyboardType(.webSearch)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .foregroundColor(.white)
                .environment(\.layoutDirection, .leftToRight)

                if !model.address.isEmpty {
                    Button {
                        model.address = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Theme.text2)
                    }
                }
            }
            .padding(10)
            .background(Theme.surface2)
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.vertical, 8)

            if model.progress > 0 && model.progress < 1 {
                ProgressView(value: model.progress)
                    .tint(Theme.accent)
                    .padding(.horizontal)
            }

            ZStack {
                WebViewHost(webView: model.webView)

                if model.webView.url == nil {
                    EmptyStateView(
                        icon: "safari",
                        title: "متصفح مدار",
                        message: "افتح موقعاً أو رابط فيديو. يمكنك تشغيل الروابط المباشرة المتوافقة مع المشغّل."
                    )
                    .background(Theme.bg)
                }
            }

            HStack {
                Button {
                    model.webView.goBack()
                } label: {
                    Image(systemName: "chevron.backward")
                }
                .disabled(!model.canGoBack)

                Spacer()

                Button {
                    model.webView.goForward()
                } label: {
                    Image(systemName: "chevron.forward")
                }
                .disabled(!model.canGoForward)

                Spacer()

                Button {
                    model.webView.reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }

                Spacer()

                Button {
                    if let url = model.webView.url {
                        UIPasteboard.general.string = url.absoluteString
                    }
                } label: {
                    Image(systemName: "doc.on.doc")
                }
            }
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(Theme.accent)
            .padding(.horizontal, 30)
            .padding(.vertical, 10)
            .background(Theme.surface)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle(
            model.title.isEmpty ? "متصفح مدار" : model.title
        )
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: model.pendingMedia) { value in
            showMediaSheet = value != nil
        }
        .confirmationDialog(
            "ملف وسائط",
            isPresented: $showMediaSheet,
            titleVisibility: .visible
        ) {
            if let url = model.pendingMedia {
                Button("تشغيل في مدار") {
                    player.play(url, title: url.lastPathComponent)
                    model.pendingMedia = nil
                }

                Button("تحميل") {
                    downloads.start(
                        title: url.lastPathComponent,
                        url: url
                    )
                    model.pendingMedia = nil
                }
            }

            Button("إلغاء", role: .cancel) {
                model.pendingMedia = nil
            }
        } message: {
            Text(model.pendingMedia?.lastPathComponent ?? "")
        }
    }
}
