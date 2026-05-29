import AVFoundation

class BackgroundAudioManager {
    static let shared = BackgroundAudioManager()
    private let engine = AVAudioEngine()

    func start() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: .mixWithOthers)
            try session.setActive(true)

            let mainMixer = engine.mainMixerNode
            let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
            let silentBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
            silentBuffer.frameLength = 1024

            let playerNode = AVAudioPlayerNode()
            engine.attach(playerNode)
            engine.connect(playerNode, to: mainMixer, format: format)
            mainMixer.outputVolume = 0

            try engine.start()
            playerNode.scheduleBuffer(silentBuffer, at: nil, options: .loops)
            playerNode.play()
        } catch {
            print("Background audio error: \(error)")
        }
    }
}
