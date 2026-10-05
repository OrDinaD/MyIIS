import Foundation

extension ScheduleServiceViewModel {
    static func isPublicationPendingError(_ error: Error) -> Bool {
        guard let apiError = error as? APIError else { return false }
        switch apiError {
        case .serverError(_, let message), .serviceUnavailable(let message):
            return message.localizedCaseInsensitiveContains("формирование")
        default:
            return false
        }
    }

    func handleScheduleLoadError(
        _ error: Error,
        fallbackSchedule: PublicScheduleResponse?,
        applyFallback: (PublicScheduleResponse) -> Void
    ) {
        if let fallbackSchedule {
            applyFallback(fallbackSchedule)
            staleErrorMessage = userFacingScheduleError(error)
            isShowingStaleDataWarning = true
            errorMessage = nil
            return
        }

        let technicalDescription = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        if isScheduleMissingMessage(technicalDescription) {
            errorMessage = NSLocalizedString("services_schedule_publication_pending", comment: "")
        } else {
            errorMessage = userFacingScheduleError(error)
        }
    }

    func userFacingScheduleError(_ error: Error) -> String {
        if let urlError = (error as? APIError).flatMap({ apiError -> URLError? in
            guard case .networkError(let underlying) = apiError else { return nil }
            return underlying as? URLError
        }), urlError.code == .notConnectedToInternet {
            return NSLocalizedString(
                "schedule_error_offline",
                value: "Нет подключения к интернету. Сохранённое расписание будет доступно после первой успешной загрузки.",
                comment: ""
            )
        }

        return NSLocalizedString(
            "schedule_error_temporary",
            value: "Не удалось загрузить расписание. Проверьте подключение и попробуйте ещё раз.",
            comment: ""
        )
    }

    private func isScheduleMissingMessage(_ message: String) -> Bool {
        let normalized = message.lowercased()
        return normalized.contains("распис")
            || normalized.contains("schedule")
            || normalized.contains("расклад")
            || normalized.contains("розклад")
    }

    func clearStaleDataWarning() {
        errorMessage = nil
        staleErrorMessage = nil
        isShowingStaleDataWarning = false
    }
}
