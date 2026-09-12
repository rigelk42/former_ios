import SwiftUI

/// Pushed from TodosListView. Matches the mockup's TodoDetail artboard:
/// a done toggle and a non-exclusive multi-select "Mentioned" section.
/// No stage picker (there's no stage concept) and no notes thread (see
/// [[team_todos_design]] memory -- notes were dropped from the feature).
struct TodoDetailView: View {
    @State private var todo: Todo
    var viewModel: TodosViewModel

    @State private var isMentionUpdating = false
    @State private var isDeleteConfirming = false
    @State private var errorMessage: String?
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @Environment(\.dismiss) private var dismiss

    init(todo: Todo, viewModel: TodosViewModel) {
        _todo = State(initialValue: todo)
        self.viewModel = viewModel
        let parsedDueDate = todo.dueDate.flatMap(DRFPlainDate.parse)
        _hasDueDate = State(initialValue: parsedDueDate != nil)
        _dueDate = State(initialValue: parsedDueDate ?? Date())
    }

    var body: some View {
        List {
            Section {
                Button {
                    Task { await toggleDone() }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundStyle(todo.isDone ? .green : .secondary)
                        Text(todo.title)
                            .strikethrough(todo.isDone)
                            .foregroundStyle(todo.isDone ? .secondary : .primary)
                    }
                }
                .buttonStyle(.plain)
            }

            Section {
                Toggle("Due Date", isOn: $hasDueDate.animation())
                    .onChange(of: hasDueDate) { _, newValue in
                        Task { await updateDueDate(newValue ? dueDate : nil) }
                    }
                if hasDueDate {
                    DatePicker("Date", selection: $dueDate, displayedComponents: .date)
                        .onChange(of: dueDate) { _, newValue in
                            Task { await updateDueDate(newValue) }
                        }
                }
            } footer: {
                if todo.isOverdue {
                    Text("Overdue").foregroundStyle(.red)
                }
            }

            Section("Mentioned") {
                ForEach(viewModel.members) { member in
                    Button {
                        Task { await toggleMention(member) }
                    } label: {
                        HStack {
                            Circle().fill(member.color.color).frame(width: 10, height: 10)
                            Text(member.username).foregroundStyle(.primary)
                            Spacer()
                            if todo.mentions.contains(where: { $0.id == member.id }) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(member.color.color)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .disabled(isMentionUpdating)

            Section {
                Button("Delete Todo", role: .destructive) {
                    isDeleteConfirming = true
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(todo.title)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete this todo?",
            isPresented: $isDeleteConfirming,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task { await performDelete() }
            }
        }
        .toast($errorMessage)
    }

    private func toggleDone() async {
        do {
            todo = try await viewModel.update(todo, input: UpdateTodoInput(isDone: !todo.isDone))
        } catch {
            errorMessage = apiErrorMessage(error)
        }
    }

    private func updateDueDate(_ date: Date?) async {
        do {
            todo = try await viewModel.update(todo, input: UpdateTodoInput(dueDate: .value(date.map(DRFPlainDate.format))))
        } catch {
            errorMessage = apiErrorMessage(error)
        }
    }

    private func toggleMention(_ member: TeamMember) async {
        isMentionUpdating = true
        defer { isMentionUpdating = false }
        var ids = todo.mentions.map(\.id)
        if let index = ids.firstIndex(of: member.id) {
            ids.remove(at: index)
        } else {
            ids.append(member.id)
        }
        do {
            todo = try await viewModel.update(todo, input: UpdateTodoInput(mentions: ids))
        } catch {
            errorMessage = apiErrorMessage(error)
        }
    }

    private func performDelete() async {
        do {
            try await viewModel.delete(todo)
            dismiss()
        } catch {
            errorMessage = apiErrorMessage(error)
        }
    }
}

#Preview {
    NavigationStack {
        TodoDetailView(
            todo: Todo(id: 1, title: "Call Riverside Farms", isDone: false, dueDate: nil, remindAt: nil, mentions: [], createdBy: nil, createdAt: "", updatedAt: ""),
            viewModel: TodosViewModel()
        )
    }
}
