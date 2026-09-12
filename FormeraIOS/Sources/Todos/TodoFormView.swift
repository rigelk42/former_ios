import SwiftUI

/// New-todo sheet, matching the mockup's NewTodo artboard: title field plus
/// a non-exclusive multi-select mention list. No stage field.
struct TodoFormView: View {
    var viewModel: TodosViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var mentionedIds: Set<Int> = []
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What needs doing?", text: $title)
                }

                Section {
                    Toggle("Due Date", isOn: $hasDueDate.animation())
                    if hasDueDate {
                        DatePicker("Date", selection: $dueDate, displayedComponents: .date)
                    }
                }

                Section("Mention teammates") {
                    ForEach(viewModel.members) { member in
                        Button {
                            toggle(member)
                        } label: {
                            HStack {
                                Circle().fill(member.color.color).frame(width: 10, height: 10)
                                Text(member.username).foregroundStyle(.primary)
                                Spacer()
                                if mentionedIds.contains(member.id) {
                                    Image(systemName: "checkmark").foregroundStyle(member.color.color)
                                }
                            }
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
            dueDate: hasDueDate ? DRFPlainDate.format(dueDate) : nil,
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

#Preview {
    TodoFormView(viewModel: TodosViewModel())
}
