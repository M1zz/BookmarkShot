//
//  DailyReminder.swift
//  밑줄 (BookmarkShot)
//
//  하루 한 번, 정한 시각에 그날의 첫 문장을 알림으로 보낸다. 사진첩에 잠들지 않게 — 문장이 먼저 찾아온다.
//  알림은 앞으로 14일치를 기기 안에서 미리 만들어 둔다(서버 없음). 문장이 바뀌거나 앱이 앞으로 오면 다시 만든다.
//

import Foundation
import UserNotifications

@MainActor
enum DailyReminder {

    private static let enabledKey = "reminder.enabled"
    private static let minutesKey = "reminder.minutes"
    private static let idPrefix = "daily-quote-"
    private static let days = 14

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    /// 하루 중 몇 분째에 보낼까. 처음엔 오전 8시.
    static var minuteOfDay: Int {
        get { UserDefaults.standard.object(forKey: minutesKey) as? Int ?? 8 * 60 }
        set { UserDefaults.standard.set(newValue, forKey: minutesKey) }
    }

    /// 켜면서 허락을 받는다. 허락하지 않으면 false (켜지 않는다).
    static func enable() async -> Bool {
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
        isEnabled = granted
        return granted
    }

    /// 지금 문장들로 알림을 다시 만든다. 꺼져 있으면 모두 지운다.
    static func reschedule(with quotes: [Quote]) {
        let center = UNUserNotificationCenter.current()
        let ids = (0..<days).map { idPrefix + String($0) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        guard isEnabled, !quotes.isEmpty else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let fire = calendar.date(byAdding: .minute, value: minuteOfDay, to: day),
                  fire > .now,
                  let quote = ReviewPicker.picks(from: quotes, on: day).first else { continue }

            let content = UNMutableNotificationContent()
            content.title = String(localized: "오늘의 문장")
            content.body = quote.book.map { "“\(quote.text)”\n— \($0.title)" } ?? "“\(quote.text)”"
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire), repeats: false)
            center.add(UNNotificationRequest(identifier: idPrefix + String(offset), content: content, trigger: trigger))
        }
    }
}
