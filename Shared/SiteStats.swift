import Foundation

/// Адрес файла со статистикой посещаемости.
let statsURL = URL(string: "https://ptmob.ru/people.num")!
let siteURL = URL(string: "https://ptmob.ru")!

struct PeriodStats: Codable, Hashable {
    let visitors: Int
    let views: Int
}

/// Формат файла people.num (JSON).
struct SiteStats: Codable {
    let site: String
    let updated: String
    let today: PeriodStats
    let week: PeriodStats
    let month: PeriodStats
    let total: PeriodStats
    let days: [String: PeriodStats]

    struct Day: Identifiable {
        let date: Date
        let visitors: Int
        let views: Int
        var id: Date { date }
    }

    /// Время последнего обновления статистики на сервере.
    var updatedDate: Date? {
        ISO8601DateFormatter().date(from: updated)
    }

    /// Последние `count` дней в хронологическом порядке.
    func lastDays(_ count: Int = 7) -> [Day] {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(identifier: "Europe/Moscow")
        fmt.dateFormat = "yyyy-MM-dd"
        return days
            .compactMap { key, value in
                fmt.date(from: key).map { Day(date: $0, visitors: value.visitors, views: value.views) }
            }
            .sorted { $0.date < $1.date }
            .suffix(count)
            .map { $0 }
    }

    static let sample = SiteStats(
        site: "ptmob.ru",
        updated: "2026-10-14T19:16:42+03:00",
        today: .init(visitors: 13, views: 21),
        week: .init(visitors: 35, views: 99),
        month: .init(visitors: 71, views: 177),
        total: .init(visitors: 71, views: 177),
        days: [
            "2026-10-08": .init(visitors: 12, views: 42),
            "2026-10-09": .init(visitors: 10, views: 10),
            "2026-10-10": .init(visitors: 9, views: 11),
            "2026-10-11": .init(visitors: 6, views: 15),
            "2026-10-12": .init(visitors: 12, views: 26),
            "2026-10-13": .init(visitors: 13, views: 52),
            "2026-10-14": .init(visitors: 13, views: 21),
        ]
    )
}

enum StatsLoader {
    private static let cacheKey = "lastStatsJSON"

    /// Загружает свежую статистику. При ошибке сети возвращает последнюю
    /// сохранённую копию (stale = true), если она есть.
    static func load() async -> (stats: SiteStats?, stale: Bool) {
        var request = URLRequest(url: statsURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw URLError(.badServerResponse)
            }
            let stats = try JSONDecoder().decode(SiteStats.self, from: data)
            UserDefaults.standard.set(data, forKey: cacheKey)
            return (stats, false)
        } catch {
            return (cached(), true)
        }
    }

    static func cached() -> SiteStats? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(SiteStats.self, from: data)
    }
}
