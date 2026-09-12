import SwiftUI

/// One of the 3 fixed colors a team member can be assigned -- unique per
/// member server-side (TeamMemberProfile.color), reassignable via
/// MemberColorsView.
enum MemberColor: String, Codable, CaseIterable, Identifiable {
    case blue, red, yellow

    var id: String { rawValue }

    var label: String { rawValue.capitalized }

    /// Plain iOS system colors, deliberately distinct from `.accentColor`
    /// so a member's identity dot never reads as a primary-action color.
    var color: Color {
        switch self {
        case .blue: .blue
        case .red: .red
        case .yellow: .yellow
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
    let color: MemberColor
}

/// One shared team todo. Visible to and editable by any authenticated team
/// member -- responsibility is signaled by `mentions` (zero or more),
/// there's no single fixed assignee and no stage/kanban concept.
struct Todo: Decodable, Identifiable, Hashable {
    let id: Int
    let title: String
    let isDone: Bool
    /// A user-facing target completion date -- "YYYY-MM-DD", same DRF
    /// DateField shape as Order.orderDate (see DRFPlainDate), not a
    /// timestamp. Distinct from remindAt below: this is when the todo is
    /// due, not when it starts being worth showing at all.
    let dueDate: String?
    /// Server-managed "don't surface until" date for auto-created
    /// reminders (e.g. the order-finalize follow-up) -- not user-editable
    /// anywhere in this app today.
    let remindAt: String?
    let mentions: [TeamMember]
    let createdBy: TeamMember?
    let createdAt: String
    let updatedAt: String

    /// Has a due date that's passed and isn't done yet -- drives the
    /// overdue styling in TodosListView/TodoDetailView.
    var isOverdue: Bool {
        guard !isDone, let dueDate, let date = DRFPlainDate.parse(dueDate) else { return false }
        return date < Calendar.current.startOfDay(for: Date())
    }
}
