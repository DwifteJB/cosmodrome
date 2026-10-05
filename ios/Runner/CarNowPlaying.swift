import CarPlay
import Flutter
import MediaPlayer

// messenger for carplay

class CarNowPlaying: NSObject, CPNowPlayingTemplateObserver {
  static let shared = CarNowPlaying()
  private var channel: FlutterMethodChannel?

  func attach(to messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "me.rmfosho.cosmodrome/car", binaryMessenger: messenger)
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "setModes", let args = call.arguments as? [String: Any] else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.apply(
        shuffle: args["shuffle"] as? Bool ?? false,
        repeatMode: args["repeat"] as? String ?? "off")
      result(nil)
    }

    let template = CPNowPlayingTemplate.shared
    template.add(self)
    template.isUpNextButtonEnabled = true
    template.upNextTitle = "Queue"
    template.updateNowPlayingButtons([
      CPNowPlayingShuffleButton { [weak self] _ in
        self?.channel?.invokeMethod("toggleShuffle", arguments: nil)
      },
      CPNowPlayingRepeatButton { [weak self] _ in
        self?.channel?.invokeMethod("toggleRepeat", arguments: nil)
      },
    ])
  }

  private func apply(shuffle: Bool, repeatMode: String) {
    let center = MPRemoteCommandCenter.shared()
    center.changeShuffleModeCommand.currentShuffleType = shuffle ? .items : .off
    switch repeatMode {
    case "one": center.changeRepeatModeCommand.currentRepeatType = .one
    case "all": center.changeRepeatModeCommand.currentRepeatType = .all
    default: center.changeRepeatModeCommand.currentRepeatType = .off
    }
  }

  func nowPlayingTemplateUpNextButtonTapped(_ nowPlayingTemplate: CPNowPlayingTemplate) {
    channel?.invokeMethod("upNext", arguments: nil)
  }
}
