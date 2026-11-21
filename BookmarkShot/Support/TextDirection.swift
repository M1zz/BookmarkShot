//
//  TextDirection.swift
//  밑줄 (BookmarkShot)
//
//  글 방향. 화면은 앱 언어를 따르고(아랍어면 오른쪽부터),
//  사용자가 담은 글(문장 · 메모 · 책 제목)은 그 글 자신의 방향을 따른다.
//  아랍어 화면에서 한국어 문장의 마침표가 앞으로 튀거나 줄이 오른쪽에 맞춰지지 않게 하고,
//  거꾸로 한국어 화면의 아랍어 문장도 오른쪽부터 읽히게 한다.
//  ⚠️ 위젯 타깃의 BookmarkShotWidget.swift 끝에 같은 `isRightToLeft` · `naturalDirection` 정의가 있다.
//

import SwiftUI

extension String {
    /// 첫 번째 방향을 가진 글자(문자)가 오른쪽→왼쪽 문자(아랍 · 히브리 등)인가
    var isRightToLeft: Bool {
        for scalar in unicodeScalars {
            switch scalar.value {
            case 0x0590...0x08FF, 0xFB1D...0xFDFF, 0xFE70...0xFEFF:
                return true
            default:
                if CharacterSet.letters.contains(scalar) { return false }
            }
        }
        return false
    }

    /// ١٢٣ · ۱۲۳ 같은 다른 숫자 글자도 0-9 와 같이 읽는다 (아랍어 키보드로 친 쪽 번호)
    var wholeNumber: Int? {
        let trimmed = trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let digits = trimmed.compactMap(\.wholeNumberValue)
        guard digits.count == trimmed.count, digits.allSatisfy({ $0 < 10 }) else { return nil }
        return Int(digits.map(String.init).joined())
    }
}

extension LayoutDirection {
    /// 앱이 지금 쓰는 언어의 방향. ImageRenderer 처럼 화면 밖에서 그릴 때 쓴다.
    static var app: LayoutDirection {
        Locale.Language(identifier: Bundle.main.preferredLocalizations.first ?? "en")
            .characterDirection == .rightToLeft ? .rightToLeft : .leftToRight
    }
}

extension View {
    /// 사용자가 담은 글은 앱 언어가 아니라 글 자신의 방향으로 놓는다.
    func naturalDirection(of text: String) -> some View {
        environment(\.layoutDirection, text.isRightToLeft ? .rightToLeft : .leftToRight)
    }
}
