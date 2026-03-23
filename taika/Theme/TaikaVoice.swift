//
//  TaikaVoice.swift
//  taika
//
//  Created by product on 20.02.2026.
//


//
//  TaikaVoice.swift
//  taika
//

import Foundation
import AVFoundation

// MARK: - Taika Voice Reaction Types

enum TaikaReaction {
    case success
    case fail
    case combo(Int)
}

// MARK: - Taika Voice Manager

final class TaikaVoice {

    static let shared = TaikaVoice()

    private var player: AVAudioPlayer?

    private init() {}

    // MARK: - Public API

    func play(_ reaction: TaikaReaction) {
        let soundName = pickSound(for: reaction)
        playSound(named: soundName)
    }

    // MARK: - Sound Selection Logic

    private func pickSound(for reaction: TaikaReaction) -> String {
        switch reaction {

        case .success:
            return random(from: [
                "taika_success_1",
                "taika_success_2",
                "taika_success_3"
            ])

        case .fail:
            return random(from: [
                "taika_fail_1",
                "taika_fail_2",
                "taika_fail_3"
            ])

        case .combo(let count):
            if count >= 5 {
                return "taika_combo_big"
            } else {
                return "taika_combo_small"
            }
        }
    }

    private func random(from array: [String]) -> String {
        array.randomElement() ?? array[0]
    }

    // MARK: - Audio Playback

    private func playSound(named name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3")
            ?? Bundle.main.url(forResource: name, withExtension: "mp3", subdirectory: "Resourses/Sounds") else {
            return
        }

        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.volume = 0.8
            player?.prepareToPlay()
            player?.play()
        } catch {
            print("taika voice error:", error.localizedDescription)
        }
    }

    /// Звук при верном матче — случайно один из доступных.
    func playMatchSuccess() {
        let name = random(from: ["match_success", "match_success_2"])
        playSound(named: name)
    }

    /// Звук при неверном матче (annoyed / match_fail.mp3).
    func playMatchFail() {
        playSound(named: "match_fail")
    }
}
