import Charts
import SwiftUI
import WidgetKit

// MARK: - Timeline

struct StatsEntry: TimelineEntry {
    let date: Date
    let stats: SiteStats?
    let stale: Bool
}

struct Provider: TimelineProvider {
    /// Как часто виджет перезапрашивает файл (система может немного сдвигать время).
    private let refreshInterval: TimeInterval = 15 * 60

    func placeholder(in context: Context) -> StatsEntry {
        StatsEntry(date: .now, stats: .sample, stale: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (StatsEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        Task {
            let result = await StatsLoader.load()
            completion(StatsEntry(date: .now, stats: result.stats, stale: result.stale))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatsEntry>) -> Void) {
        Task {
            let result = await StatsLoader.load()
            let entry = StatsEntry(date: .now, stats: result.stats, stale: result.stale)
            // При ошибке пробуем снова раньше — через 5 минут.
            let next = Date.now.addingTimeInterval(result.stale ? 5 * 60 : refreshInterval)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }
}

// MARK: - Views

private let accent = Color(red: 0.20, green: 0.55, blue: 1.0)

struct PtmobWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StatsEntry

    var body: some View {
        Group {
            if let stats = entry.stats {
                switch family {
                case .systemSmall: SmallView(stats: stats, stale: entry.stale)
                case .systemMedium: MediumView(stats: stats, stale: entry.stale)
                default: LargeView(stats: stats, stale: entry.stale)
                }
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "wifi.exclamationmark").font(.title2)
                    Text("Нет данных").font(.headline)
                    Text("Не удалось загрузить ptmob.ru/people.num")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(nsColor: .windowBackgroundColor), accent.opacity(0.12)],
                startPoint: .top, endPoint: .bottom
            )
        }
        .widgetURL(siteURL)
    }
}

private struct Header: View {
    let stats: SiteStats
    let stale: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "chart.bar.fill").foregroundStyle(accent)
            Text(stats.site).font(.caption.weight(.semibold))
            Spacer(minLength: 0)
            if stale {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help("Нет связи — показаны последние сохранённые данные")
            }
            if let updated = stats.updatedDate {
                Text(updated, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct BigNumber: View {
    let value: PeriodStats
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value.visitors, format: .number)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Label {
                Text("\(value.views.formatted()) просмотров")
            } icon: {
                Image(systemName: "eye")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }
}

private struct PeriodRow: View {
    let title: String
    let value: PeriodStats

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Text(value.visitors, format: .number).font(.callout.weight(.semibold)).monospacedDigit()
            Text("/ \(value.views.formatted())").font(.caption2).foregroundStyle(.secondary).monospacedDigit()
        }
    }
}

private struct SmallView: View {
    let stats: SiteStats
    let stale: Bool

    var body: some View {
        VStack(alignment: .leading) {
            Header(stats: stats, stale: stale)
            Spacer(minLength: 0)
            BigNumber(value: stats.today, title: "Посетители сегодня")
            Spacer(minLength: 0)
            PeriodRow(title: "Неделя", value: stats.week)
        }
    }
}

private struct MediumView: View {
    let stats: SiteStats
    let stale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Header(stats: stats, stale: stale)
            HStack(alignment: .center, spacing: 16) {
                BigNumber(value: stats.today, title: "Сегодня")
                    .frame(maxWidth: .infinity, alignment: .leading)
                VStack(spacing: 6) {
                    PeriodRow(title: "Неделя", value: stats.week)
                    PeriodRow(title: "Месяц", value: stats.month)
                    PeriodRow(title: "Всего", value: stats.total)
                    Text("посетители / просмотры")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity)
        }
    }
}

private struct LargeView: View {
    let stats: SiteStats
    let stale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Header(stats: stats, stale: stale)
            HStack(alignment: .top) {
                BigNumber(value: stats.today, title: "Посетители сегодня")
                Spacer()
                VStack(spacing: 6) {
                    PeriodRow(title: "Неделя", value: stats.week)
                    PeriodRow(title: "Месяц", value: stats.month)
                    PeriodRow(title: "Всего", value: stats.total)
                }
                .frame(width: 150)
            }
            Divider()
            Text("Последние 7 дней").font(.caption.weight(.semibold))
            Chart(stats.lastDays(7)) { day in
                BarMark(
                    x: .value("День", day.date, unit: .day),
                    y: .value("Просмотры", day.views)
                )
                .foregroundStyle(accent.opacity(0.25))
                BarMark(
                    x: .value("День", day.date, unit: .day),
                    y: .value("Посетители", day.visitors)
                )
                .foregroundStyle(accent)
                .annotation(position: .top) {
                    Text("\(day.visitors)").font(.system(size: 9)).foregroundStyle(.secondary)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                }
            }
            .chartYAxis(.hidden)
            .environment(\.locale, Locale(identifier: "ru_RU"))
            HStack(spacing: 12) {
                Label("посетители", systemImage: "square.fill").foregroundStyle(accent)
                Label("просмотры", systemImage: "square.fill").foregroundStyle(accent.opacity(0.35))
            }
            .font(.caption2)
            .labelStyle(.titleAndIcon)
        }
    }
}

// MARK: - Widget

@main
struct PtmobWidget: Widget {
    let kind = "PtmobWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            PtmobWidgetView(entry: entry)
        }
        .configurationDisplayName("Посещаемость ptmob.ru")
        .description("Посетители и просмотры сайта ptmob.ru: сегодня, за неделю, месяц и всё время.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemMedium) {
    PtmobWidget()
} timeline: {
    StatsEntry(date: .now, stats: .sample, stale: false)
}
