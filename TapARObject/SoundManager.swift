//
//  SoundManager.swift
//  TapARObject
//
//  Created by ミズキ on 2023/02/08.
//

import AVKit
enum SoundError: Error {
    case notFile
    case notContent
}

final class SoundManager {
    static let shared = SoundManager()
    private init() { }
    
    func playAudio(fileName: String) throws {
        if let soundURL = Bundle.main.url(forResource: fileName, withExtension: "mp3") {
            do {
                let player = try AVAudioPlayer(contentsOf: soundURL)
                player.play()
            } catch {
                throw SoundError.notContent
            }
        } else {
            throw SoundError.notFile
        }
    }
}
