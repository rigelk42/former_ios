import SwiftUI

/// Team Todos' root screen: a shared, whole-team list (see TodosViewModel)
/// filtered by done-state and by mentioned member, matching the approved
/// Claude Design mockup ("Team Todos", 4-artboard prototype).
struct TodosListView: View {
    @State private var viewModel = TodosViewModel()
    @State private var isCreatePresented = false
    @State private var isMemberColorsPresented = false

    var body: some View {
        List {
            ForEach(viewModel.filteredTodos) { todo in
                NavigationLink(value: todo) {
                    TodoRow(todo: todo) {
                        Task { await viewModel.toggleDone(todo) }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .top) {
            TodoFiltersBar(
                doneFilter: $viewModel.doneFilter,
                memberFilter: $viewModel.memberFilter,
                members: viewModel.members
            )
            .padding(.top, 4)
            .background(.bar)
        }
        .overlay {
            if viewModel.isLoading && viewModel.todos.isEmpty {
                ProgressView()
            } else if viewModel.filteredTodos.isEmpty {
                ContentUnavailableView(
                    viewModel.errorMessage ?? "No todos here",
                    systemImage: viewModel.errorMessage == nil ? "checklist" : "exclamationmark.triangle"
                )
            }
        }
        .navigationTitle("Team Todos")
        .navigationDestination(for: Todo.self) { todo in
            TodoDetailView(todo: todo, viewModel: viewModel)
        }
        .refreshable { await viewModel.refresh() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isMemberColorsPresented = true
                } label: {
                    Label("Member Colors", systemImage: "paintpalette")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isCreatePresented = true
                } label: {
                    Label("New Todo", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isCreatePresented) {
            TodoFormView(viewModel: viewModel)
        }
        .sheet(isPresented: $isMemberColorsPresented) {
            MemberColorsView(viewModel: viewModel)
        }
        .task { await viewModel.loadInitial() }
    }
}

/// One row: a tappable done-toggle circle, the title (strikethrough when
/// done), and a small dot per mentioned member. `.buttonStyle(.borderless)`
/// on the toggle keeps it independently tappable inside the row's
/// NavigationLink -- without it, tapping the circle would also navigate.
private struct TodoRow: View {
    let todo: Todo
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .strokeBorder(todo.isDone ? Color.green : Color.secondary.opacity(0.5), lineWidth: 1.5)
                        .background(Circle().fill(todo.isDone ? Color.green : Color.clear))
                        .frame(width: 22, height: 22)
                    if todo.isDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.borderless)

            VStack(alignment: .leading, spacing: 5) {
                Text(todo.title)
                    .strikethrough(todo.isDone)
                    .foregroundStyle(todo.isDone ? .secondary : .primary)
                    .lineLimit(1)
                if !todo.mentions.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(todo.mentions) { member in
                            Circle().fill(member.color.color).frame(width: 8, height: 8)
                        }
                    }
                }
            }

            if let dueDate = todo.dueDate {
                Spacer()
                Text(dueDate.formattedAsPlainDate())
                    .font(.caption)
                    .foregroundStyle(todo.isOverdue ? .red : .secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

/// Open/Done/All segmented control plus member filter chips, pinned above
/// the list -- mirrors the mockup's Main artboard.
private struct TodoFiltersBar: View {
    @Binding var doneFilter: TodoDoneFilter
    @Binding var memberFilter: MemberColor?
    let members: [TeamMember]

    var body: some View {
        VStack(spacing: 10) {
            Picker("", selection: $doneFilter) {
                ForEach(TodoDoneFilter.allCases) { filter in
                    Text(filter.label).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    MemberFilterChip(label: "All", color: nil, isSelected: memberFilter == nil) {
                        memberFilter = nil
                    }
                    ForEach(members) { member in
                        MemberFilterChip(
                            label: member.username,
                            color: member.color.color,
                            isSelected: memberFilter == member.color
                        ) {
                            memberFilter = member.color
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

private struct MemberFilterChip: View {
    let label: String
    let color: Color?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let color {
                    Circle().fill(color).frame(width: 8, height: 8)
                }
                Text(label)
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(chipBackground, in: Capsule())
            .overlay(Capsule().strokeBorder(chipBorder, lineWidth: 1))
            .foregroundStyle(chipForeground)
        }
        .buttonStyle(.plain)
    }

    private var chipBackground: Color {
        guard isSelected else { return Color(.secondarySystemGroupedBackground) }
        return (color ?? .primary).opacity(0.15)
    }

    private var chipBorder: Color {
        guard isSelected else { return .clear }
        return color ?? .primary.opacity(0.5)
    }

    private var chipForeground: Color {
        isSelected ? (color ?? .primary) : .secondary
    }
}

#Preview {
    NavigationStack { TodosListView() }
}
