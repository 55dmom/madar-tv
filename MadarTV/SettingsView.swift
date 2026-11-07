import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var playlists: PlaylistStore
    @EnvironmentObject var downloads: DownloadManager
    @State private var draft = ""
    @State private var loadingCustom = false

    var body: some View {
        Form {
            Section(header: Text("رابط قائمة التشغيل"), footer: Text("الصق رابط قائمة M3U أو بث HLS (m3u8) خاص بك، وسيعرض التطبيق القنوات في تبويب «مباشر» ← «قائمتي».")) {
                TextField("https://example.com/playlist.m3u", text: $draft)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .environment(\.layoutDirection, .leftToRight)
                HStack {
                    Button {
                        playlists.customURL = draft
                        loadingCustom = true
                        Task { await playlists.loadCustom(); loadingCustom = false }
                    } label: {
                        HStack {
                            if loadingCustom { ProgressView() }
                            Text("تحميل القائمة")
                        }
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                    .buttonStyle(.borderless)
                    Spacer()
                    Button("لصق") {
                        if let s = UIPasteboard.general.string { draft = s.trimmingCharacters(in: .whitespacesAndNewlines) }
                    }
                    .buttonStyle(.borderless)
                }
                if !playlists.custom.isEmpty {
                    Label("\(playlists.custom.count) قناة في قائمتك", systemImage: "checkmark.seal.fill").foregroundColor(Theme.accent)
                    Button(role: .destructive) { playlists.clearCustom(); draft = "" } label: { Text("حذف القائمة") }
                }
                if let e = playlists.lastError { Text(e).font(.caption).foregroundColor(Theme.accent2) }
            }

            Section(header: Text("قوائم جاهزة"), footer: Text("قوائم عامة من مشروع iptv-org المفتوح لقنوات البث المجاني. بعض القنوات قد تكون محجوبة جغرافياً أو متوقفة.")) {
                Button { Task { await playlists.loadArabic() } } label: {
                    HStack {
                        Label("القنوات العربية المجانية", systemImage: "antenna.radiowaves.left.and.right")
                        Spacer()
                        if playlists.loading.contains(PlaylistStore.arabicPreset) { ProgressView() }
                        else if !playlists.arabic.isEmpty { Text("\(playlists.arabic.count)").foregroundColor(Theme.text2) }
                    }
                }
                Button { Task { await playlists.loadAnime() } } label: {
                    HStack {
                        Label("قنوات الأنيميشن والأطفال", systemImage: "sparkles.tv")
                        Spacer()
                        if !playlists.loading.isEmpty && playlists.loading.contains(PlaylistStore.animationPreset) { ProgressView() }
                        else if !(playlists.animation.isEmpty && playlists.kids.isEmpty) { Text("\(playlists.animation.count + playlists.kids.count)").foregroundColor(Theme.text2) }
                    }
                }
            }

            Section(header: Text("التخزين")) {
                NavigationLink(destination: DownloadsView()) {
                    HStack {
                        Label("التحميلات", systemImage: "arrow.down.circle")
                        Spacer()
                        Text("\(downloads.items.filter { $0.state == .done }.count)").foregroundColor(Theme.text2)
                    }
                }
                NavigationLink(destination: BrowserView()) { Label("المتصفح", systemImage: "safari") }
            }

            Section(header: Text("حول التطبيق")) {
                HStack {
                    Text("الإصدار")
                    Spacer()
                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0").foregroundColor(Theme.text2)
                }
                Text("مَدار TV مشغّل وسائط عام. الأفلام المضمّنة من أرشيف الإنترنت (ملكية عامة) وأفلام Blender المفتوحة، والقنوات من قوائم iptv-org العامة. المستخدم مسؤول عن الروابط التي يضيفها.")
                    .font(.footnote).foregroundColor(Theme.text2)
            }
        }
        .navigationTitle("الإعدادات")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { draft = playlists.customURL }
    }
}

struct DownloadsView: View {
    @EnvironmentObject var downloads: DownloadManager
    @EnvironmentObject var player: PlayerCoordinator

    var body: some View {
        Group {
            if downloads.items.isEmpty {
                ScrollView { EmptyStateView(icon: "arrow.down.circle", title: "لا توجد تحميلات", message: "اضغط زر التحميل في صفحة الفيلم أو الحلقة أو داخل المشغل أو المتصفح، وشاهد بدون إنترنت.").padding(.top, 60) }
            } else {
                List {
                    ForEach(downloads.items) { item in
                        Button {
                            if item.state == .done, let u = downloads.localURL(item) { player.play(u, title: item.title) }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: icon(item)).font(.title2).foregroundColor(item.state == .failed ? Theme.accent2 : Theme.accent)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title).foregroundColor(.white).lineLimit(2)
                                    switch item.state {
                                    case .downloading, .queued:
                                        ProgressView(value: item.progress).tint(Theme.accent)
                                        Text("\(Int(item.progress * 100))٪ • \(ByteCountFormatter.string(fromByteCount: item.bytes, countStyle: .file))").font(.caption2).foregroundColor(Theme.text2)
                                    case .done:
                                        Text("جاهز للمشاهدة بدون إنترنت • \(ByteCountFormatter.string(fromByteCount: item.bytes, countStyle: .file))").font(.caption2).foregroundColor(Theme.text2)
                                    case .failed:
                                        Text("فشل التحميل — اضغط مطولاً للحذف ثم أعد المحاولة").font(.caption2).foregroundColor(Theme.accent2)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Theme.surface)
                        .swipeActions {
                            Button(role: .destructive) { downloads.delete(item) } label: { Label("حذف", systemImage: "trash") }
                        }
                        .contextMenu {
                            Button(role: .destructive) { downloads.delete(item) } label: { Label("حذف", systemImage: "trash") }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("التحميلات")
        .navigationBarTitleDisplayMode(.inline)
    }

    func icon(_ i: DownloadItem) -> String {
        switch i.state {
        case .done: return "play.circle.fill"
        case .failed: return "exclamationmark.circle.fill"
        default: return "arrow.down.circle"
        }
    }
}
