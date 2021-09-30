import AVFoundation

public class PitchDetectorEngine {

  private static let BUFFER_SIZE: AVAudioFrameCount = 4096
  private static let LEVEL_THRESHOLD: Float = -30
  private static let ESTIMATOR = YINEstimator()

  private let captureSession = AVCaptureSession()
  private var audioEngine: AVAudioEngine!

  public init() {
    let audioDevice = AVCaptureDevice.default(for: AVMediaType.audio)!
    let audioCaptureInput = try! AVCaptureDeviceInput(device: audioDevice)

    captureSession.addInput(audioCaptureInput)

    let audioOutput = AVCaptureAudioDataOutput()
    captureSession.addOutput(audioOutput)
  }

  public func prepare() -> Bool {
    let audioSession = AVAudioSession.sharedInstance()

    do {
      try audioSession.setCategory(.playAndRecord)

      // Override input (not sure why this is needed, see https://github.com/vadymmarkov/Beethoven/issues/76)
      let lastPort = audioSession.currentRoute.outputs.last!
      try audioSession.overrideOutputAudioPort(lastPort.portType == .headphones ? .none : .speaker)

      try audioSession.setActive(true)
      return true
    } catch {
      return false
    }
  }

  public func startRecording(onMidiNumberDetected: @escaping (Int) -> Void) {
    audioEngine = AVAudioEngine()
    audioEngine.inputNode.installTap(
      onBus: 0,
      bufferSize: PitchDetectorEngine.BUFFER_SIZE,
      format: nil) { buffer, time in
      guard self.isChannelLoudEnough() else {
        return
      }
      let frequency = PitchDetectorEngine.getFrequency(buffer: buffer, time: time)
      let midiNumber = PitchDetectorEngine.frequencyToMidiNumber(frequency: frequency)
      onMidiNumberDetected(midiNumber)
    }

    try! audioEngine.start()
    captureSession.startRunning()
  }

  public func stopRecording() {
    captureSession.stopRunning()
    audioEngine.stop()
    audioEngine.reset()
    audioEngine = nil
    try! AVAudioSession.sharedInstance().setActive(false)
  }

  private func isChannelLoudEnough() -> Bool {
    return captureSession.outputs[0].connections[0].audioChannels[0].averagePowerLevel > PitchDetectorEngine.LEVEL_THRESHOLD
  }

  private static func getFrequency(buffer: AVAudioPCMBuffer, time: AVAudioTime) -> Float {
    let transformedBuffer = try! PitchDetectorEngine.ESTIMATOR.transformer.transform(buffer: buffer)
    return try! PitchDetectorEngine.ESTIMATOR.estimateFrequency(
      sampleRate: Float(time.sampleRate),
      buffer: transformedBuffer)
  }

  private static func frequencyToMidiNumber(frequency: Float) -> Int {
    return Int(round(12 * log2(frequency / 440))) + 69
  }
}
