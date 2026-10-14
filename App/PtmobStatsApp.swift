import SwiftUI
import WidgetKit

/// Небольшое приложение-контейнер: оно нужно macOS, чтобы зарегистрировать виджет.
/// Заодно показывает текущую статистику и позволяет обновить виджет вручную.
@main
struct PtmobStatsApp: App {
    var body: some Scene {
        WindowGroup("Посещаемость ptmob.ru") {
            ContentView()
                .frame(minWidth: 360, minHeight: 300)
        }
        .windowResizability(.contentSize)
    }
}

struct ContentView: View {
    @State private var stats: SiteStats?
    @State private var stale = false
    @State private var loading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("ptmob.ru").font(.title2.bold())
                Spacer()
                Button {
                    Task { await refresh() }
                } label: {
                    Label("Обновить", systemImage: "arrow.clockwise")
                }
                .disabled(loading)
            }

            if let stats {
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                    GridRow {
                        Text("").gridColumnAlignment(.leading)
                        Text("Посетители").foregroundStyle(.secondary)
                        Text("Просмотры").foregroundStyle(.secondary)
                    }
                    row("Сегодня", stats.today)
                    row("Неделя", stats.week)
                    row("Месяц", stats.month)
                    row("Всего", stats.total)
                }
                if let updated = stats.updatedDate {
                    Text("Данные на сервере обновлены: \(updated.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if stale {
                    Text("Нет связи — показаны последние сохранённые данные.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            } else if loading {
                ProgressView()
            } else {
                Text("Не удалось загрузить статистику.").foregroundStyle(.secondary)
            }

            Spacer()
            Text("Чтобы добавить виджет: правый клик по рабочему столу → «Изменить виджеты…» → найдите «Посещаемость ptmob.ru».")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .task { await refresh() }
    }

    private func row(_ title: String, _ value: PeriodStats) -> some View {
        GridRow {
            Text(title)
            Text(value.visitors, format: .number).font(.body.weight(.semibold)).monospacedDigit()
            Text(value.views, format: .number).monospacedDigit()
        }
    }

    private func refresh() async {
        loading = true
        let result = await StatsLoader.load()
        stats = result.stats
        stale = result.stale
        loading = false
        WidgetCenter.shared.reloadAllTimelines()
    }
}
