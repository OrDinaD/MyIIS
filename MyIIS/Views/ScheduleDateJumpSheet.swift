import SwiftUI

struct ScheduleDateJumpSheet: View {
    @Binding var selectedDate: Date
    @Binding var targetDate: Date?
    @Binding var isPresented: Bool
    let dateRange: ClosedRange<Date>

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                DatePicker(
                    NSLocalizedString("schedule_choose_date", value: "Выберите дату", comment: ""),
                    selection: $selectedDate,
                    in: dateRange,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .padding()

                Button(NSLocalizedString("schedule_today_action", value: "Сегодня", comment: "")) {
                    targetDate = Date()
                    isPresented = false
                }
                .buttonStyle(.bordered)

                Spacer()
            }
            .navigationTitle(NSLocalizedString("schedule_jump_to_date", value: "Перейти к дате", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("common_cancel", comment: "")) {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("schedule_jump_action", value: "Перейти", comment: "")) {
                        targetDate = selectedDate
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
