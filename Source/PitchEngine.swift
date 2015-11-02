import Foundation
import AVFoundation

public protocol PitchEngineDelegate: class {
  func pitchEngineDidRecieveFrequency(pitchEngine: PitchEngine, frequency: Float)
}

public class PitchEngine {

  public weak var delegate: PitchEngineDelegate?

  private let bufferSize: AVAudioFrameCount
  private var frequencies = [Float]()

  private lazy var audioInputProcessor: AudioInputProcessor = { [unowned self] in
    let audioInputProcessor = AudioInputProcessor(
      bufferSize: self.bufferSize,
      delegate: self
    )

    return audioInputProcessor
    }()

  private lazy var pitchDetector: PitchDetector = { [unowned self] in
    let pitchDetector = PitchDetector(
      sampleRate: 44100.0,
      lowBoundFrequency: 30.0,
      highBoundFrequency: 4500,
      delegate: self)

    return pitchDetector
    }()

  // MARK: - Initialization

  public init(bufferSize: AVAudioFrameCount = 2048, delegate: PitchEngineDelegate?) {
    self.bufferSize = bufferSize
    self.delegate = delegate
  }

  // MARK: - Processing

  public func start() {
    do {
      try audioInputProcessor.start()
    } catch {}
  }

  public func stop() {
    audioInputProcessor.stop()
    frequencies = [Float]()
  }

  // MARK: - Helpers

  private func averageFrequency(frequency: Float) -> Float {
    var result = frequency

    frequencies.insert(frequency, atIndex: 0)

    if frequencies.count > 22 {
      frequencies.removeAtIndex(frequencies.count - 1)
    }

    let count = frequencies.count

    if count > 1 {
      var sortedFrequencies = frequencies.sort { $0 > $1 }

      if count % 2 == 0 {
        let value1 = sortedFrequencies[count / 2 - 1]
        let value2 = sortedFrequencies[count / 2]
        result = (value1 + value2) / 2
      } else {
        result = sortedFrequencies[count / 2]
      }
    }

    return result
  }
}

// MARK: - AudioInputProcessorDelegate

extension PitchEngine: AudioInputProcessorDelegate {

  public func audioInputProcessorDidReceiveSamples(samples: UnsafeMutablePointer<Int16>,
    framesCount: Int) {
      pitchDetector.addSamples(samples, framesCount: framesCount)
  }
}

// MARK: - PitchDetectorDelegate

extension PitchEngine: PitchDetectorDelegate {

  public func pitchDetectorDidUpdateFrequency(pitchDetector: PitchDetector, frequency: Float) {
    delegate?.pitchEngineDidRecieveFrequency(self, frequency: averageFrequency(frequency))
  }
}