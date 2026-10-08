import SwiftUI

/// New-todo sheet, matching the mockup's NewTodo artboard: title field plus
/// a non-exclusive multi-select mention list. No stage field.
struct TodoFormView: View {
    var viewModel: TodosViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var notes = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var hasDueTime = false
    @State private var dueTime = Date()
    @State private var mentionedIds: Set<Int> = []
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What needs doing?", text: $title)
                } header: {
                    HStack {
                        Spacer()
                        NotePresetMenu { preset in
                            title = TodoNotePresets.prefix(preset, to: title)
                            notes = TodoNotePresets.apply(preset, to: notes)
                        }
                    }
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...10)
                }

                Section {
                    Toggle("Due Date", isOn: $hasDueDate.animation())
                    if hasDueDate {
                        DatePicker("Date", selection: $dueDate, displayedComponents: .date)
                        Toggle("Time", isOn: $hasDueTime.animation())
                        if hasDueTime {
                            DatePicker("Time", selection: $dueTime, displayedComponents: .hourAndMinute)
                        }
                    }
                }

                Section("Mention teammates") {
                    ForEach(viewModel.members) { member in
                        Button {
                            toggle(member)
                        } label: {
                            HStack {
                                Circle().fill(member.color.color).frame(width: 10, height: 10)
                                Text(member.displayName).foregroundStyle(.primary)
                                Spacer()
                                if mentionedIds.contains(member.id) {
                                    Image(systemName: "checkmark").foregroundStyle(member.color.color)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("New Todo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { Task { await submit() } }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                }
            }
            .disabled(isSubmitting)
            .toast($errorMessage)
        }
    }

    private func toggle(_ member: TeamMember) {
        if mentionedIds.contains(member.id) {
            mentionedIds.remove(member.id)
        } else {
            mentionedIds.insert(member.id)
        }
    }

    private func submit() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }
        let input = CreateTodoInput(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            dueDate: hasDueDate ? DRFPlainDate.format(dueDate) : nil,
            dueTime: hasDueDate && hasDueTime ? DRFPlainTime.format(dueTime) : nil,
            mentions: Array(mentionedIds)
        )
        do {
            _ = try await viewModel.create(input)
            dismiss()
        } catch {
            errorMessage = apiErrorMessage(error)
        }
    }
}

/// "Presets" menu -- picking one hands it to `onPick`. The new-todo form
/// prefixes it to the title (TodoNotePresets.prefix) and appends it to the
/// notes (TodoNotePresets.apply); the detail view only appends to the notes.
struct NotePresetMenu: View {
    var onPick: (String) -> Void

    var body: some View {
        Menu {
            ForEach(TodoNotePresets.all, id: \.self) { preset in
                Button(preset) { onPick(preset) }
            }
        } label: {
            Label("Presets", systemImage: "text.badge.plus")
                .font(.subheadline)
                .textCase(nil)
        }
    }
}

#Preview {
    TodoFormView(viewModel: TodosViewModel())
}
