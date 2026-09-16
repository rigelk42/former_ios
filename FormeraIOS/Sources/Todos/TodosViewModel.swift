import Foundation
import Observation

enum TodoDoneFilter: String, CaseIterable, Identifiable {
    case open, done, all

    var id: String { rawValue }

    var label: String {
        switch self {
        case .open: "Open"
        case .done: "Done"
        case .all: "All"
        }
    }
}

/// Owns both the todo list and the 3-member colored roster -- the two are
/// small and always loaded together (the roster drives the mention picker
/// and filter chips), unlike CustomersViewModel/ProductsViewModel which
/// each own a single paginated resource.
@MainActor
@Observable
final class TodosViewModel {
    private(set) var todos: [Todo] = []
    private(set) var members: [TeamMember] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    var doneFilter: TodoDoneFilter = .open
    var memberFilter: MemberColor?

    private var hasLoadedOnce = false
    private let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    var filteredTodos: [Todo] {
        todos.filter { todo in
            let matchesDone: Bool
            switch doneFilter {
            case .open: matchesDone = !todo.isDone
            case .done: matchesDone = todo.isDone
            case .all: matchesDone = true
            }
            let matchesMember = memberFilter.map { color in
                todo.mentions.contains { $0.color == color }
            } ?? true
            return matchesDone && matchesMember
        }
        // Soonest due date first; a todo with no due date sorts last --
        // dueDate is "YYYY-MM-DD" (see DRFPlainDate), which orders
        // correctly as a plain string comparison. Ties (including
        // nil == nil, e.g. two undated todos) break by newest-created
        // first, so a freshly-created todo lands at the top of its group
        // -- e.g. above other undated todos -- rather than in an
        // arbitrary spot.
        .sorted { lhs, rhs in
            switch (lhs.dueDate, rhs.dueDate) {
            case let (lhsDate?, rhsDate?) where lhsDate != rhsDate: lhsDate < rhsDate
            case (nil, _?): false
            case (_?, nil): true
            default: lhs.createdAt > rhs.createdAt
            }
        }
    }

    func loadInitial() async {
        guard !hasLoadedOnce else { return }
        await refresh()
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let membersRequest = apiClient.get("todos/members/", as: [TeamMember].self)
            // ?due=true -- hides a todo whose remind_at hasn't passed yet
            // (see TodoListCreateView.get_queryset), so e.g. the
            // automatic order follow-up/reorder-check todos stay out of
            // the list until the day before they're due.
            async let todosRequest = apiClient.get("todos/?due=true", as: [Todo].self)
            let (loadedMembers, loadedTodos) = try await (membersRequest, todosRequest)
            members = loadedMembers
            todos = loadedTodos
            hasLoadedOnce = true
        } catch {
            errorMessage = apiErrorMessage(error)
        }
    }

    /// Optimistic-feeling toggle: the row's checkmark should flip the
    /// instant it's tapped, so this replaces the local copy with the
    /// server's response (rather than waiting on a full list refresh).
    func toggleDone(_ todo: Todo) async {
        do {
            _ = try await update(todo, input: UpdateTodoInput(isDone: !todo.isDone))
        } catch {
            errorMessage = apiErrorMessage(error)
        }
    }

    @discardableResult
    func update(_ todo: Todo, input: UpdateTodoInput) async throws -> Todo {
        let updated = try await apiClient.patch("todos/\(todo.id)/", body: input, as: Todo.self)
        if let index = todos.firstIndex(where: { $0.id == todo.id }) {
            todos[index] = updated
        }
        return updated
    }

    func create(_ input: CreateTodoInput) async throws -> Todo {
        let created = try await apiClient.post("todos/", body: input, as: Todo.self)
        todos.insert(created, at: 0)
        return created
    }

    func delete(_ todo: Todo) async throws {
        try await apiClient.delete("todos/\(todo.id)/")
        todos.removeAll { $0.id == todo.id }
    }
}
