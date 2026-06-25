import AppKit
import FocusFlowCore

final class SoundService {
    func play(_ sound: TimerSound) {
        if let systemSound = NSSound(named: NSSound.Name(sound.rawValue)) {
            systemSound.play()
        } else {
            NSSound.beep()
        }
    }
}
