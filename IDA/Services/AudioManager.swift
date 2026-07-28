import Foundation
import AVFoundation
import Combine

@MainActor
class AudioManager: ObservableObject {
    static let shared = AudioManager()

    private var audioPlayer: AVAudioPlayer?
    private var delegateProxy: AudioPlayerDelegateProxy?
    
    @Published var isPlaying = false
    @Published var volume: Double = 0.5 {
        didSet {
            audioPlayer?.volume = Float(volume)
        }
    }

    private let trackNames = ["XXOO", "OXOX", "XOXO", "OOXX"]
    private var currentTrackIndex = 0

    private init() {
        setupAudio()
    }

    private func setupAudio() {
        playTrack(at: currentTrackIndex)
    }

    private func playTrack(at index: Int) {
        guard index >= 0 && index < trackNames.count else { return }
        guard let audioURL = Bundle.main.url(forResource: trackNames[index], withExtension: "mp3") else {
            print("⚠️ 未找到音乐文件 \(trackNames[index]).mp3")
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: audioURL)
            player.numberOfLoops = 0
            player.volume = Float(volume)
            player.prepareToPlay()
            
            let proxy = AudioPlayerDelegateProxy { [weak self] in
                Task { @MainActor in
                    self?.handleTrackFinished()
                }
            }
            player.delegate = proxy
            delegateProxy = proxy
            audioPlayer = player
        } catch {
            print("❌ 音频初始化失败: \(error)")
        }
    }

    private func handleTrackFinished() {
        guard isPlaying else { return }
        currentTrackIndex = (currentTrackIndex + 1) % trackNames.count
        playTrack(at: currentTrackIndex)
        audioPlayer?.play()
    }

    func play() {
        if audioPlayer == nil {
            playTrack(at: currentTrackIndex)
        }
        guard let player = audioPlayer else { return }
        if !player.isPlaying {
            player.play()
            isPlaying = true
        }
    }

    func pause() {
        guard let player = audioPlayer else { return }
        if player.isPlaying {
            player.pause()
            isPlaying = false
        }
    }

    func toggle() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        isPlaying = false
    }

    func nextTrack() {
        let wasPlaying = isPlaying
        stop()
        currentTrackIndex = (currentTrackIndex + 1) % trackNames.count
        playTrack(at: currentTrackIndex)
        if wasPlaying {
            play()
        }
    }

    func previousTrack() {
        let wasPlaying = isPlaying
        stop()
        currentTrackIndex = (currentTrackIndex - 1 + trackNames.count) % trackNames.count
        playTrack(at: currentTrackIndex)
        if wasPlaying {
            play()
        }
    }
}

class AudioPlayerDelegateProxy: NSObject, AVAudioPlayerDelegate {
    private let onFinish: () -> Void
    
    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        super.init()
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish()
    }
}
