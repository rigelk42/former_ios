import SwiftUI

/// Matches the mockup's MemberColors artboard: each member's row shows all
/// 3 swatches, with the current one solid and highlighted. Tapping a
/// swatch already held by someone else swaps it with them -- see
/// TodosViewModel.reassignColor and the backend's deferred uniqueness
/// constraint (TeamMemberProfile.Meta) that makes the swap atomic.
struct MemberColorsView: View {
    var viewModel: TodosViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(viewModel.members) { member in
                        HStack {
                            Circle().fill(member.color.color).frame(width: 14, height: 14)
                            Text(member.username)
                            Spacer()
                            HStack(spacing: 10) {
                                ForEach(MemberColor.allCases) { color in
                                    SwatchButton(color: color, isSelected: member.color == color) {
                                        Task { await viewModel.reassignColor(member, to: color) }
                                    }
                                }
                            }
                        }
                    }
                } footer: {
                    Text("Each color belongs to one teammate — picking a taken color swaps it with whoever has it.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Member Colors")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct SwatchButton: View {
    let color: MemberColor
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(color.color)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 26, height: 26)
            .opacity(isSelected ? 1 : 0.35)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MemberColorsView(viewModel: TodosViewModel())
}
