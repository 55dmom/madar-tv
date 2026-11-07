import Foundation

enum M3UParser {
    static func parse(_ text: String) -> [Channel] {
        var result: [Channel] = []
        var pendingName: String? = nil
        var pendingAttrs: [String: String] = [:]
        var pendingReferrer: String? = nil
        var pendingUA: String? = nil

        let lines = text.replacingOccurrences(of: "\r", with: "").components(separatedBy: "\n")
        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line.hasPrefix("#EXTINF") {
                let (attrs, name) = parseExtInf(line)
                pendingAttrs = attrs
                pendingName = name
                if let r = attrs["http-referrer"] ?? attrs["referrer"] { pendingReferrer = r }
                if let u = attrs["http-user-agent"] ?? attrs["user-agent"] { pendingUA = u }
            } else if line.hasPrefix("#EXTVLCOPT:") {
                let opt = String(line.dropFirst("#EXTVLCOPT:".count))
                if opt.hasPrefix("http-referrer=") { pendingReferrer = String(opt.dropFirst("http-referrer=".count)) }
                if opt.hasPrefix("http-user-agent=") { pendingUA = String(opt.dropFirst("http-user-agent=".count)) }
            } else if line.hasPrefix("#") {
                continue
            } else {
                let name = (pendingName?.isEmpty == false ? pendingName! : (pendingAttrs["tvg-name"] ?? line))
                var group = pendingAttrs["group-title"] ?? ""
                if let first = group.split(separator: ";").first { group = String(first) }
                if group.isEmpty || group.lowercased() == "undefined" { group = "أخرى" }
                let logo = pendingAttrs["tvg-logo"].flatMap { $0.isEmpty ? nil : $0 }
                result.append(Channel(name: name, url: line, logo: logo, group: group, referrer: pendingReferrer, userAgent: pendingUA))
                pendingName = nil; pendingAttrs = [:]; pendingReferrer = nil; pendingUA = nil
            }
        }
        return result
    }

    private static func parseExtInf(_ line: String) -> ([String: String], String) {
        var attrs: [String: String] = [:]
        var inQuotes = false
        var commaIndex: String.Index? = nil
        var i = line.startIndex
        while i < line.endIndex {
            let c = line[i]
            if c == "\"" { inQuotes.toggle() }
            else if c == "," && !inQuotes { commaIndex = i; break }
            i = line.index(after: i)
        }
        let head = commaIndex.map { String(line[..<$0]) } ?? line
        let name = commaIndex.map { String(line[line.index(after: $0)...]).trimmingCharacters(in: .whitespaces) } ?? ""
        if let regex = try? NSRegularExpression(pattern: "([A-Za-z0-9_-]+)=\"([^\"]*)\"") {
            let ns = head as NSString
            for m in regex.matches(in: head, range: NSRange(location: 0, length: ns.length)) {
                attrs[ns.substring(with: m.range(at: 1)).lowercased()] = ns.substring(with: m.range(at: 2))
            }
        }
        return (attrs, name)
    }
}

@MainActor
final class PlaylistStore: ObservableObject {
    static let arabicPreset = "https://iptv-org.github.io/iptv/languages/ara.m3u"
    static let animationPreset = "https://iptv-org.github.io/iptv/categories/animation.m3u"
    static let kidsPreset = "https://iptv-org.github.io/iptv/categories/kids.m3u"

    @Published var arabic: [Channel] = []
    @Published var animation: [Channel] = []
    @Published var kids: [Channel] = []
    @Published var custom: [Channel] = []
    @Published var loading: Set<String> = []
    @Published var lastError: String? = nil
    @Published var customURL: String {
        didSet { UserDefaults.standard.set(customURL, forKey: "customPlaylistURL") }
    }
    @Published var arabicEnabled: Bool {
        didSet { UserDefaults.standard.set(arabicEnabled, forKey: "arabicPresetEnabled") }
    }

    init() {
        customURL = UserDefaults.standard.string(forKey: "customPlaylistURL") ?? ""
        arabicEnabled = UserDefaults.standard.bool(forKey: "arabicPresetEnabled")
        arabic = Self.cached(Self.arabicPreset)
        animation = Self.cached(Self.animationPreset)
        kids = Self.cached(Self.kidsPreset)
        if !customURL.isEmpty { custom = Self.cached(customURL) }
    }

    func groups(_ list: [Channel]) -> [(String, [Channel])] {
        var order: [String] = []; var map: [String: [Channel]] = [:]
        for c in list {
            if map[c.group] == nil { order.append(c.group); map[c.group] = [] }
            map[c.group]!.append(c)
        }
        return order.map { ($0, map[$0]!) }
    }

    func loadArabic() async { arabicEnabled = true; arabic = await fetch(Self.arabicPreset) ?? arabic }
    func loadAnime() async {
        async let a = fetch(Self.animationPreset)
        async let k = fetch(Self.kidsPreset)
        let (aa, kk) = await (a, k)
        if let aa = aa { animation = aa }
        if let kk = kk { kids = kk }
    }
    func loadCustom() async {
        let u = customURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !u.isEmpty else { custom = []; return }
        if let list = await fetch(u) { custom = list }
    }
    func clearCustom() { customURL = ""; custom = [] }

    private func fetch(_ urlString: String) async -> [Channel]? {
        guard let url = URL(string: urlString) else { lastError = "الرابط غير صالح"; return nil }
        loading.insert(urlString)
        defer { loading.remove(urlString) }
        do {
            var req = URLRequest(url: url, timeoutInterval: 25)
            req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: req)
            let text = String(decoding: data, as: UTF8.self)
            if text.contains("#EXT-X-") && !text.contains("#EXTINF:-1") {
                // A single HLS stream rather than a channel list.
                lastError = nil
                let one = [Channel(name: url.deletingPathExtension().lastPathComponent, url: urlString, group: "بث مباشر")]
                Self.store(urlString, one)
                return one
            }
            let list = M3UParser.parse(text)
            if list.isEmpty { lastError = "لم يتم العثور على قنوات في هذا الرابط"; return nil }
            lastError = nil
            Self.store(urlString, list)
            return list
        } catch {
            lastError = "تعذّر تحميل القائمة: \(error.localizedDescription)"
            return nil
        }
    }

    private static func cacheURL(_ key: String) -> URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let safe = key.data(using: .utf8)!.base64EncodedString().replacingOccurrences(of: "/", with: "_").prefix(120)
        return dir.appendingPathComponent("pl_\(safe).json")
    }
    private static func store(_ key: String, _ list: [Channel]) {
        if let d = try? JSONEncoder().encode(list) { try? d.write(to: cacheURL(key)) }
    }
    private static func cached(_ key: String) -> [Channel] {
        guard let d = try? Data(contentsOf: cacheURL(key)) else { return [] }
        return (try? JSONDecoder().decode([Channel].self, from: d)) ?? []
    }
}
