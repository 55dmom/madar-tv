import Foundation

enum MediaKind: String, Codable, Hashable {
    case movie, openMovie, series, cartoon, archive
}

struct Episode: Codable, Hashable, Identifiable {
    var id: String { stream }
    let title: String
    let stream: String
    let minutes: Int?
}

struct MediaItem: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    var subtitle: String? = nil
    var year: Int? = nil
    var genre: String? = nil
    var minutes: Int? = nil
    var stream: String? = nil
    var thumb: String? = nil
    var source: String? = nil
    var episodes: [Episode]? = nil
    var kind: MediaKind? = nil
    var overview: String? = nil

    var thumbURL: URL? { thumb.flatMap { URL(string: $0) } }
    var streamURL: URL? { stream.flatMap { URL(string: $0) } }
    var isSeries: Bool { !(episodes ?? []).isEmpty }
    var displayTitle: String { subtitle ?? title }
    var badge: String? {
        switch kind {
        case .openMovie: return "HD"
        case .series, .cartoon: return "\((episodes ?? []).count) حلقة"
        default: return nil
        }
    }
    var metaLine: String {
        var parts: [String] = []
        if let y = year { parts.append(String(y)) }
        if let g = genre { parts.append(g) }
        if let m = minutes, m > 0 { parts.append("\(m) د") }
        return parts.joined(separator: " • ")
    }
    var about: String {
        if let o = overview, !o.isEmpty { return o }
        switch kind {
        case .series:
            return "مسلسل كلاسيكي من الأرشيف العام (ملكية عامة). اختر حلقة من القائمة وابدأ المشاهدة مباشرة أو حمّلها للمشاهدة بدون إنترنت."
        case .cartoon:
            return "حلقات كرتون كلاسيكية من العصر الذهبي للرسوم المتحركة، متاحة للجميع ضمن الملكية العامة."
        case .openMovie:
            return "فيلم رسوم متحركة مفتوح المصدر من إنتاج مؤسسة Blender، مرخّص للمشاهدة والمشاركة بحرية."
        default:
            return "فيلم كلاسيكي من أرشيف الإنترنت ضمن الملكية العامة. \(title)" + (year != nil ? " (\(year!))." : ".")
        }
    }
}

struct Catalog: Codable {
    var movies: [MediaItem]
    var open_movies: [MediaItem]
    var series: [MediaItem]
    var cartoons: [MediaItem]
    var test_streams: [MediaItem]
}

struct Channel: Codable, Hashable, Identifiable {
    var id: String { url + "|" + name }
    let name: String
    let url: String
    var logo: String? = nil
    var group: String = "عام"
    var referrer: String? = nil
    var userAgent: String? = nil

    var logoURL: URL? { logo.flatMap { URL(string: $0) } }
    var headers: [String: String] {
        var h: [String: String] = [:]
        if let r = referrer, !r.isEmpty { h["Referer"] = r }
        if let u = userAgent, !u.isEmpty { h["User-Agent"] = u }
        return h
    }
}

struct PlayRequest: Identifiable {
    let id = UUID()
    let url: URL
    let title: String
    var headers: [String: String] = [:]
    var isLive: Bool = false
}
