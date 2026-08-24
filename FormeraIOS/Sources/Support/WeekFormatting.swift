import Foundation

/// Mirrors lib/weekGroups.ts's formatWeekRange(): "Week of Aug 11 - Aug 17,
/// 2026" for the calendar week starting on weekStart.
func formatWeekRange(weekStart: Date) -> String {
    let calendar = Calendar(identifier: .gregorian)
    let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart

    let day = Date.FormatStyle().month(.abbreviated).day()
    let year = calendar.component(.year, from: weekEnd)
    return "Week of \(weekStart.formatted(day)) - \(weekEnd.formatted(day)), \(year)"
}

extension String {
    /// Parses a "yyyy-MM-dd" week_start string as local midnight (no
    /// "Z"/offset suffix, so DateFormatter's default lenient parsing keeps
    /// it local rather than UTC) -- avoids the week label showing the
    /// wrong day in timezones behind UTC, same reasoning as the web's
    /// `${week.week_start}T00:00:00` parse.
    var asLocalMidnight: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.date(from: self)
    }
}
