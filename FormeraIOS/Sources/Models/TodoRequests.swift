import Foundation

struct CreateTodoInput: Encodable {
    var title: String
    /// "YYYY-MM-DD" (see DRFPlainDate), or nil for no due date.
    var dueDate: String?
    var mentions: [Int]
}

/// Every field optional -- send only what's changing. `remindAt` isn't
/// exposed here since nothing in the UI edits it (it's only ever set
/// server-side, by OrderFinalizeView's automatic follow-up reminder).
/// `dueDate` is `Omittable` (see Omittable.swift), not a plain Optional,
/// because clearing a previously-set due date needs to send an explicit
/// JSON null -- omitting the key would leave the old date in place.
struct UpdateTodoInput: Encodable {
    var title: String?
    var isDone: Bool?
    var dueDate: Omittable<String> = .omit
    var mentions: [Int]?

    private enum CodingKeys: String, CodingKey {
        case title, isDone, dueDate, mentions
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(isDone, forKey: .isDone)
        try container.encodeIfPresent(mentions, forKey: .mentions)
        switch dueDate {
        case .omit:
            break
        case .value(let value):
            if let value {
                try container.encode(value, forKey: .dueDate)
            } else {
                try container.encodeNil(forKey: .dueDate)
            }
        }
    }
}
