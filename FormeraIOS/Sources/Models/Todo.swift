import SwiftUI

/// One of a fixed set of colors a team member can be assigned -- unique per
/// member server-side (TeamMemberProfile.color). Assigned via the Django
/// admin, not from the app.
enum MemberColor: String, Codable, CaseIterable, Identifiable {
    case blue, red, yellow, purple

    var id: String { rawValue }

    var label: String { rawValue.capitalized }

    /// Plain iOS system colors, deliberately distinct from `.accentColor`
    /// so a member's identity dot never reads as a primary-action color.
    var color: Color {
        switch self {
        case .blue: .blue
        case .red: .red
        case .yellow: .yellow
        case .purple: .purple
        }
    }
}

/// A real login account plus its assigned color -- mirrors
/// todos/serializers.py's TeamMemberSerializer. `id` is the user id
/// (matching Todo.mentions/createdBy elsewhere), not the underlying
/// TeamMemberProfile row's own id.
struct TeamMember: Decodable, Identifiable, Hashable {
    let id: Int
    let username: String
    let email: String
    /// The friendly name to show anywhere a member appears -- e.g. "Derek"
    /// rather than the Django admin login "dbrainard". Set via the Django
    /// admin, not from the app. `username` is kept for reference but
    /// shouldn't be shown in the UI.
    let displayName: String
    let color: MemberColor
}

/// One shared team todo. Visible to and editable by any authenticated team
/// member -- responsibility is signaled by `mentions` (zero or more),
/// there's no single fixed assignee and no stage/kanban concept.
struct Todo: Decodable, Identifiable, Hashable {
    let id: Int
    let title: String
    let notes: String
    let isDone: Bool
    /// A user-facing target completion date -- "YYYY-MM-DD", same DRF
    /// DateField shape as Order.orderDate (see DRFPlainDate), not a
    /// timestamp. Distinct from remindAt below: this is when the todo is
    /// due, not when it starts being worth showing at all.
    let dueDate: String?
    /// Optional time of day on dueDate -- "HH:MM:SS", a DRF TimeField (see
    /// DRFPlainTime), read as the phone's local time. Always nil when
    /// dueDate is nil.
    let dueTime: String?
    /// Server-managed "don't surface until" date for auto-created
    /// reminders (e.g. the order-finalize follow-up) -- not user-editable
    /// anywhere in this app today.
    let remindAt: String?
    let mentions: [TeamMember]
    let createdBy: TeamMember?
    let createdAt: String
    let updatedAt: String

    /// dueDate combined with dueTime, in the phone's local time zone -- nil
    /// when there's no due time (a date-only due date has no exact moment).
    var dueDateTime: Date? {
        guard let dueDate, let dueTime, let date = DRFPlainDate.parse(dueDate) else { return nil }
        return DRFPlainTime.combine(date: date, time: dueTime)
    }

    /// Has a due date (and time, if set) that's passed and isn't done yet
    /// -- drives the overdue styling in TodosListView/TodoDetailView.
    var isOverdue: Bool {
        guard !isDone else { return false }
        if let dueDateTime { return dueDateTime < Date() }
        guard let dueDate, let date = DRFPlainDate.parse(dueDate) else { return false }
        return date < Calendar.current.startOfDay(for: Date())
    }

    /// "Oct 1, 2026" or "Oct 1, 2026, 2:30 PM" -- for the list row.
    var dueLabel: String? {
        guard let dueDate else { return nil }
        if let dueDateTime {
            return dueDateTime.formatted(date: .abbreviated, time: .shortened)
        }
        return dueDate.formattedAsPlainDate()
    }
}

/// Quick-pick notes offered next to the free-typing notes field on a todo.
/// Placeholder wording until the team sends their preferred list -- edit
/// here to change what shows up in the menu.
enum TodoNotePresets {
    static let all = ["Check in", "Follow up", "Call back", "Waiting on payment"]

    /// Appends `preset` to `notes` on its own line, or uses it as the whole
    /// note when notes is empty.
    static func apply(_ preset: String, to notes: String) -> String {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? preset : trimmed + "\n" + preset
    }
}
