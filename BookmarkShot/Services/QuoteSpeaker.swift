//
//  QuoteSpeaker.swift
//  밑줄 (BookmarkShot)
//
//  모은 문장을 소리로 들려준다. 눈이 피곤한 날, 보이지 않는 사람, 걸으며 다시 듣고 싶은 사람 모두를 위해.
//  문장의 언어를 알아내 그 나라 목소리로 읽는다 (영어 책 문장은 영어 목소리로). 기기 안에서만 처리한다.
//

import AVFoundation
import NaturalLanguage
import SwiftUI

@MainActor
@Observable
final class QuoteSpeaker: NSObject, AVSpeechSynthesizerDelegate {

    static let shared = QuoteSpeaker()

    /// 지금 읽고 있는 글. nil 이면 조용하다.
    private(set) var speakingText: String?

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    func isSpeaking(_ text: String) -> Bool { speakingText == text }

    /// 읽고 있던 글이면 멈추고, 아니면 처음부터 읽는다.
    func toggle(_ text: String) {
        if isSpeaking(text) { stop(); return }
        stop()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: Self.language(of: text))
        speakingText = text
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        speakingText = nil
    }

    /// 문장의 언어 (BCP-47). 알 수 없으면 기기 언어.
    private static func language(of text: String) -> String? {
        NLLanguageRecognizer.dominantLanguage(for: text)?.rawValue
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in if self.speakingText == utterance.speechString { self.speakingText = nil } }
    }
}

/// '들려주기' 단추. 누르면 읽고, 다시 누르면 멈춘다. 화면을 떠나면 멈춘다.
struct SpeakButton: View {
    let text: String
    private var speaker: QuoteSpeaker { .shared }

    var body: some View {
        let speaking = speaker.isSpeaking(text)
        Button {
            speaker.toggle(text)
        } label: {
            Label(speaking ? String(localized: "멈추기") : String(localized: "들려주기"),
                  systemImage: speaking ? "stop.fill" : "speaker.wave.2")
        }
        .onDisappear { if speaker.isSpeaking(text) { speaker.stop() } }
    }
}
