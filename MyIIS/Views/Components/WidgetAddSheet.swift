//
//  WidgetAddSheet.swift
//  MyIIS
//
//  Created by OpenAI Assistant on 11.03.2026.
//

import SwiftUI

struct WidgetAddSheet: View {
    let shortcut: AppShortcut
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                header
                steps
                tip
                Spacer()
                Button(action: dismiss.callAsFunction) {
                    Text("Понятно")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.accentPurple))
                        .foregroundStyle(.white)
                }
            }
            .padding(24)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var title: String {
        switch shortcut {
        case .addAttendanceWidget:
            return "Добавление виджета"
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(.linearGradient(colors: [.accentPurple, .accentPurple.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Text("Закрепите пропуски на рабочем столе")
                .font(.title3)
                .multilineTextAlignment(.center)
        }
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 16) {
            step(number: 1, text: "Перейдите на главный экран и зажмите пустое место.")
            step(number: 2, text: "Нажмите кнопку плюс в левом верхнем углу.")
            step(number: 3, text: "В списке выберите MyIIS и добавьте виджет \"Пропуски\" нужного размера.")
        }
    }

    private func step(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.accentPurple.opacity(0.15)))
                .foregroundStyle(Color.accentPurple)
            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
        }
    }

    private var tip: some View {
        Label {
            Text("После добавления виджета данные обновляются автоматически при входе в приложение.")
                .font(.footnote)
        } icon: {
            Image(systemName: "info.circle")
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.accentPurple.opacity(0.08)))
    }
}

#Preview {
    WidgetAddSheet(shortcut: .addAttendanceWidget)
}
