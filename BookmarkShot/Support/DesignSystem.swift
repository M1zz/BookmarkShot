//
//  DesignSystem.swift
//  밑줄
//
//  앱 전체에서 공유하는 디자인 토큰과 버튼 스타일.
//  화면마다 제각각이던 버튼/여백/모서리를 여기 한곳에서 통일한다.
//

import SwiftUI

enum Theme {
    /// 카드·버튼 공통 모서리 둥글기
    static let corner: CGFloat = 14
    /// 큰 카드(오늘의 문장 등) 모서리
    static let cornerLarge: CGFloat = 20

    /// 화면 가장자리 기본 여백
    static let screenPadding: CGFloat = 20
    /// 버튼 안쪽 세로 여백 (터치 타깃 충분히 크게)
    static let buttonVPadding: CGFloat = 15

    /// 아이콘의 네이비 잉크색 — 강조 텍스트/포인트에 사용
    static let ink = Color(red: 0.10, green: 0.16, blue: 0.26)
}

// MARK: - Button Styles

/// 채워진 강조 버튼(주 행동). 넓게 펴지는 pill 형태 + 눌림 피드백.
struct BrandPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.buttonVPadding)
            .background(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .fill(Color.accentColor)
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// 보조 버튼. 강조색을 옅게 깐 배경 + 강조색 텍스트. 강조 버튼과 크기·모서리 동일.
struct BrandSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.accentColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.buttonVPadding)
            .background(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .fill(Color.accentColor.opacity(0.14))
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == BrandPrimaryButtonStyle {
    /// 주 행동 버튼: `.buttonStyle(.brandPrimary)`
    static var brandPrimary: BrandPrimaryButtonStyle { .init() }
}

extension ButtonStyle where Self == BrandSecondaryButtonStyle {
    /// 보조 행동 버튼: `.buttonStyle(.brandSecondary)`
    static var brandSecondary: BrandSecondaryButtonStyle { .init() }
}
