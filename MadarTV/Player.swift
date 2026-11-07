import SwiftUI
import AVKit

@MainActor
final class PlayerCoordinator: ObservableObject {
    @Published var current: PlayRequest? = nil
    @Published var resolving = false

    func play(_ url: URL, title: String, headers: [String: String] = [:], live: Bool = false) {
        let local = DownloadManager.shared.localURL(for: url.absoluteString)
        current = PlayRequest(url: local ?? url, title: title, headers: headers, isLive: live)
    }
    func play(channel: Channel) {
        guard let u = URL(string: channel.url) else { return }
        play(u, title: channel.name, headers: channel.headers, live: true)
    }
    func play(item: MediaItem) {
        if let u = item.streamURL { play(u, title: item.displayTitle); return }
        if item.kind == .archive {
            resolving = true
            Task {
                let u = await ArchiveService.resolveMP4(identifier: item.id)
                self.resolving = false
                if let u = u { self.play(u, title: item.displayTitle) }
            }
        }
    }
}

struct AVPlayerControllerView: UIViewControllerRepresentable {
    let player: AVPlayer
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = player
        vc.allowsPictureInPicturePlayback = true
        vc.canStartPictureInPictureAutomaticallyFromInline = true
        vc.showsPlaybackControls = true
        vc.videoGravity = .resizeAspect
        return vc
    }
    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {}
}

struct PlayerScreen: View {
    let request: PlayRequest
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var downloads: DownloadManager
    @State private var player: AVPlayer? = nil
    @State private var status: String? = nil
    @State private var observer: NSKeyValueObservation? = nil

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            if let p = player {
                AVPlayerControllerView(player: p).ignoresSafeArea()
            }
            if let s = status {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.largeTitle).foregroundColor(Theme.accent)
                    Text(s).foregroundColor(.white).multilineTextAlignment(.center)
                }
                .padding().frame(maxHeight: .infinity)
            }
            HStack(spacing: 12) {
                Button { player?.pause(); dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 15, weight: .bold))
                        .frame(width: 36, height: 36).background(.ultraThinMaterial).clipShape(Circle())
                }
                Text(request.title).font(.subheadline.bold()).foregroundColor(.white).lineLimit(1)
                Spacer()
                if !request.isLive && !request.url.isFileURL && DownloadManager.canDownload(request.url) {
                    Button { downloads.start(title: request.title, url: request.url) } label: {
                        Image(systemName: downloads.isDownloaded(request.url.absoluteString) ? "checkmark.circle.fill" : "arrow.down.circle")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 36, height: 36).background(.ultraThinMaterial).clipShape(Circle())
                    }
                }
                if request.isLive {
                    Text("مباشر").font(.caption.bold()).padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Theme.accent2).cornerRadius(6)
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal).padding(.top, 8)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear(perform: start)
        .onDisappear { player?.pause(); observer = nil }
    }

    private func start() {
        var opts: [String: Any] = [:]
        if !request.headers.isEmpty { opts["AVURLAssetHTTPHeaderFieldsKey"] = request.headers }
        let asset = AVURLAsset(url: request.url, options: opts)
        let item = AVPlayerItem(asset: asset)
        let p = AVPlayer(playerItem: item)
        observer = item.observe(\.status, options: [.new]) { it, _ in
            DispatchQueue.main.async {
                if it.status == .failed {
                    let reason: String = it.error?.localizedDescription ?? ""
                    status = "تعذّر تشغيل هذا البث.\n\(reason)\nقد يكون الرابط متوقفاً أو محجوباً في منطقتك."
                }
            }
        }
        player = p
        p.play()
    }
}
