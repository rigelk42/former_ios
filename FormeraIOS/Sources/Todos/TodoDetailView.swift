import SwiftUI

/// Pushed from TodosListView. Matches the mockup's TodoDetail artboard:
/// a done toggle and a non-exclusive multi-select "Mentioned" section.
/// No stage picker (there's no stage concept). Title and Notes are both
/// plain free-text fields (Notes isn't a comment thread), edited in place;
/// a toolbar Save button appears while either differs from what's
/// persisted (blur also saves, as a fallback for tapping away without
/// using the button). An empty title reverts to the last saved value
/// instead of being submitted.
struct TodoDetailView: View {
    @State private var todo: Todo
    var viewModel: TodosViewModel

    @State private var isMentionUpdating = false
    @State private var isDeleteConfirming = false
    @State private var errorMessage: String?
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var title: String
    @State private var notes: String
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isNotesFocused: Bool
    @Environment(\.dismiss) private var dismiss

    init(todo: Todo, viewModel: TodosViewModel) {
        _todo = State(initialValue: todo)
        self.viewModel = viewModel
        let parsedDueDate = todo.dueDate.flatMap(DRFPlainDate.parse)
        _hasDueDate = State(initialValue: parsedDueDate != nil)
        _dueDate = State(initialValue: parsedDueDate ?? Date())
        _title = State(initialValue: todo.title)
        _notes = State(initialValue: todo.notes)
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Button {
                        Task { await toggleDone() }
                    } label: {
                        Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundStyle(todo.isDone ? .green : .secondary)
                    }
                    .buttonStyle(.plain)

                    TextField("Title", text: $title)
                        .strikethrough(todo.isDone)
                        .foregroundStyle(todo.isDone ? .secondary : .primary)
                        .focused($isTitleFocused)
                        .submitLabel(.done)
                        .onSubmit { Task { await updateTitle() } }
                        .onChange(of: isTitleFocused) { _, isFocused in
                            if !isFocused { Task { await updateTitle() } }
                        }
                }
            }

            Section("Notes") {
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...10)
                    .focused($isNotesFocused)
                    .onChange(of: isNotesFocused) { _, isFocused in
                        if !isFocused { Task { await updateNotes() } }
                    }
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
                            Text(member.displayName).foregroundStyle(.primary)
                            Spacer()
                            if todo.mentions.contains(where: { $0.id == member.id }) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(member.color.color)
                            }
                        }
                        .contentShape(Rectangle())
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
        .toolbar {
            if notes != todo.notes || title.trimmingCharacters(in: .whitespacesAndNewlines) != todo.title {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isTitleFocused = false
                        isNotesFocused = false
                        Task {
                            await updateTitle()
                            await updateNotes()
                        }
                    } label: {
                        Label("Save", systemImage: "checkmark")
                    }
                }
            }
        }
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

    private func updateTitle() async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            title = todo.title
            return
        }
        guard trimmed != todo.title else { return }
        do {
            todo = try await viewModel.update(todo, input: UpdateTodoInput(title: trimmed))
            title = todo.title
        } catch {
            errorMessage = apiErrorMessage(error)
        }
    }

    private func updateNotes() async {
        guard notes != todo.notes else { return }
        do {
            todo = try await viewModel.update(todo, input: UpdateTodoInput(notes: notes))
        } catch {
            errorMessage = apiErrorMessage(error)
        }
    }

    private func updateDueDate(_ date: Date?) async {
        do {
            todo = try await viewModel.update(
                todo, input: UpdateTodoInput(dueDate: .value(date.map(DRFPlainDate.format)))
            )
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
            todo: Todo(
                id: 1,
                title: "Call Riverside Farms",
                notes: "",
                isDone: false,
                dueDate: nil,
                remindAt: nil,
                mentions: [],
                createdBy: nil,
                createdAt: "",
                updatedAt: ""
            ),
            viewModel: TodosViewModel()
        )
    }
}
