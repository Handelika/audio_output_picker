import Flutter
import UIKit
import AVFoundation

public class AudioOutputPickerPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var selectedOutputDeviceId: String? = nil
  private var selectedInputDeviceId: String? = nil
  private var eventSink: FlutterEventSink?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let methodChannel = FlutterMethodChannel(name: "audio_output_picker", binaryMessenger: registrar.messenger())
    let eventChannel = FlutterEventChannel(name: "audio_output_picker/events", binaryMessenger: registrar.messenger())
    
    let instance = AudioOutputPickerPlugin()
    registrar.addMethodCallDelegate(instance, channel: methodChannel)
    eventChannel.setStreamHandler(instance)
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleAudioRouteChange),
      name: AVAudioSession.routeChangeNotification,
      object: AVAudioSession.sharedInstance()
    )
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    NotificationCenter.default.removeObserver(
      self,
      name: AVAudioSession.routeChangeNotification,
      object: AVAudioSession.sharedInstance()
    )
    self.eventSink = nil
    return nil
  }

  @objc private func handleAudioRouteChange(notification: Notification) {
    if let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
       let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) {
      if reason == .newDeviceAvailable || reason == .oldDeviceUnavailable || reason == .categoryChange || reason == .routeConfigurationChange {
        selectedOutputDeviceId = nil
        selectedInputDeviceId = nil
      }
    }
    DispatchQueue.main.async { [weak self] in
      self?.eventSink?(["event": "route_change"])
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
      self?.eventSink?(["event": "route_change_settled"])
    }
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    var hasReplied = false
    let safeResult: FlutterResult = { res in
      DispatchQueue.main.async {
        if !hasReplied {
          hasReplied = true
          result(res)
        }
      }
    }

    switch call.method {
    case "getPlatformVersion":
      safeResult("iOS " + UIDevice.current.systemVersion)
    case "checkBluetoothPermission", "checkPermission", "requestBluetoothPermission", "requestPermission":
      safeResult(true)
    case "checkMicrophonePermission":
      do {
        if #available(iOS 17.0, *) {
          let status = AVAudioApplication.shared.recordPermission
          safeResult(status == .granted)
        } else {
          let status = AVAudioSession.sharedInstance().recordPermission
          safeResult(status == .granted)
        }
      } catch {
        safeResult(false)
      }
    case "requestMicrophonePermission":
      if #available(iOS 17.0, *) {
        AVAudioApplication.requestRecordPermission { granted in
          safeResult(granted)
        }
      } else {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
          safeResult(granted)
        }
      }
    case "getAvailableAudioOutputs":
      safeResult(getAvailableAudioOutputs())
    case "selectAudioOutput":
      if let args = call.arguments as? [String: Any],
         let deviceId = args["deviceId"] as? String {
        safeResult(selectAudioOutput(deviceId: deviceId))
      } else {
        safeResult(FlutterError(code: "INVALID_ARGUMENT", message: "deviceId is required", details: nil))
      }
    case "getCurrentAudioOutput":
      safeResult(getCurrentAudioOutput())
    case "getAvailableMicrophones":
      safeResult(getAvailableMicrophones())
    case "selectMicrophone":
      if let args = call.arguments as? [String: Any],
         let deviceId = args["deviceId"] as? String {
        safeResult(selectMicrophone(deviceId: deviceId))
      } else {
        safeResult(FlutterError(code: "INVALID_ARGUMENT", message: "deviceId is required", details: nil))
      }
    case "getCurrentMicrophone":
      safeResult(getCurrentMicrophone())
    default:
      safeResult(FlutterMethodNotImplemented)
    }
  }

  // ==========================================
  // Audio Outputs (Speakers, Headphones, BT)
  // ==========================================

  private func mapOutputPortTypeToString(_ type: AVAudioSession.Port) -> String {
    switch type {
    case .builtInSpeaker:
      return "speaker"
    case .builtInReceiver:
      return "receiver"
    case .headphones:
      return "wiredHeadphones"
    case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
      return "bluetooth"
    case .airPlay:
      return "airPlay"
    case .usbAudio:
      return "usb"
    case .HDMI:
      return "hdmi"
    default:
      return "speaker"
    }
  }

  private func getAvailableAudioOutputs() -> [[String: Any]] {
    var devicesList: [[String: Any]] = []

    do {
      let session = AVAudioSession.sharedInstance()
      let currentOutputs = session.currentRoute.outputs
      let currentInputs = session.availableInputs ?? []

      let isHeadphonesRouted = currentOutputs.contains { $0.portType == .headphones }
      let isBluetoothRouted = currentOutputs.contains {
        $0.portType == .bluetoothA2DP || $0.portType == .bluetoothHFP || $0.portType == .bluetoothLE
      }
      let isUsbRouted = currentOutputs.contains { $0.portType == .usbAudio }
      let isAirPlayRouted = currentOutputs.contains { $0.portType == .airPlay }
      let isSpeakerRouted = currentOutputs.contains { $0.portType == .builtInSpeaker || $0.portType == .builtInReceiver }

      // 1. Check Wired Headphones
      let hasWiredOutput = currentOutputs.contains { $0.portType == .headphones }
      let hasWiredInput = currentInputs.contains { $0.portType == .headsetMic }
      if hasWiredOutput || hasWiredInput {
        let isSelected = (selectedOutputDeviceId == "wired_headphones") ||
                         (selectedOutputDeviceId == nil && isHeadphonesRouted)
        devicesList.append([
          "id": "wired_headphones",
          "name": "Wired Headphones",
          "type": "wiredHeadphones",
          "isSelected": isSelected
        ])
      }

      // 2. Check Bluetooth devices
      var bluetoothNames: Set<String> = []
      for output in currentOutputs {
        if output.portType == .bluetoothA2DP || output.portType == .bluetoothHFP || output.portType == .bluetoothLE {
          let cleanName = cleanOutputName(output.portName, type: "bluetooth")
          if !bluetoothNames.contains(cleanName) {
            bluetoothNames.insert(cleanName)
            let id = "bluetooth_\(output.uid)"
            let isSelected = (selectedOutputDeviceId == id) ||
                             (selectedOutputDeviceId == nil && isBluetoothRouted)
            devicesList.append([
              "id": id,
              "name": cleanName,
              "type": "bluetooth",
              "isSelected": isSelected
            ])
          }
        }
      }
      for input in currentInputs {
        if input.portType == .bluetoothHFP || input.portType == .bluetoothLE {
          let cleanName = cleanOutputName(input.portName, type: "bluetooth")
          if !bluetoothNames.contains(cleanName) {
            bluetoothNames.insert(cleanName)
            let id = "bluetooth_\(input.uid)"
            let isSelected = (selectedOutputDeviceId == id) ||
                             (selectedOutputDeviceId == nil && isBluetoothRouted && currentOutputs.contains { $0.portName == input.portName || $0.uid == input.uid })
            devicesList.append([
              "id": id,
              "name": cleanName,
              "type": "bluetooth",
              "isSelected": isSelected
            ])
          }
        }
      }

      // 3. Check USB Audio
      let hasUsbOutput = currentOutputs.contains { $0.portType == .usbAudio }
      let hasUsbInput = currentInputs.contains { $0.portType == .usbAudio }
      if hasUsbOutput || hasUsbInput {
        let id = "usb_audio"
        let isSelected = (selectedOutputDeviceId == id) ||
                         (selectedOutputDeviceId == nil && isUsbRouted)
        devicesList.append([
          "id": "usb_audio",
          "name": "USB Audio",
          "type": "usb",
          "isSelected": isSelected
        ])
      }

      // 4. Check AirPlay
      for output in currentOutputs where output.portType == .airPlay {
        let id = "airplay_\(output.uid)"
        let isSelected = (selectedOutputDeviceId == id) ||
                         (selectedOutputDeviceId == nil && isAirPlayRouted)
        devicesList.append([
          "id": id,
          "name": output.portName.isEmpty ? "AirPlay" : output.portName,
          "type": "airPlay",
          "isSelected": isSelected
        ])
      }

      // 5. Speaker is ALWAYS available on iOS
      let isExternalSelected = devicesList.contains { ($0["isSelected"] as? Bool) == true }
      let isSpeakerSelected: Bool
      if let selectedId = selectedOutputDeviceId {
        isSpeakerSelected = selectedId == "builtin_speaker" || selectedId.contains("speaker")
      } else {
        isSpeakerSelected = !isExternalSelected || isSpeakerRouted
      }

      devicesList.append([
        "id": "builtin_speaker",
        "name": "Speaker",
        "type": "speaker",
        "isSelected": isSpeakerSelected && !isExternalSelected
      ])

      // Ensure exactly ONE item has isSelected: true
      var selectedFound = false
      for i in 0..<devicesList.count {
        if (devicesList[i]["isSelected"] as? Bool) == true {
          if selectedFound {
            devicesList[i]["isSelected"] = false
          } else {
            selectedFound = true
          }
        }
      }
      if !selectedFound && !devicesList.isEmpty {
        if let speakerIdx = devicesList.firstIndex(where: { ($0["type"] as? String) == "speaker" }) {
          devicesList[speakerIdx]["isSelected"] = true
        } else {
          devicesList[0]["isSelected"] = true
        }
      }
    } catch {
      // Fallback
    }

    if devicesList.isEmpty {
      devicesList.append([
        "id": "builtin_speaker",
        "name": "Speaker",
        "type": "speaker",
        "isSelected": true
      ])
    }

    return devicesList
  }

  private func cleanOutputName(_ rawName: String, type: String) -> String {
    if type == "speaker" {
      return "Speaker"
    }
    if type == "receiver" {
      return "Earpiece"
    }
    if type == "wiredHeadphones" {
      return "Wired Headphones"
    }
    var name = rawName
      .replacingOccurrences(of: " Microphone", with: "", options: .caseInsensitive)
      .replacingOccurrences(of: " Mic", with: "", options: .caseInsensitive)
      .replacingOccurrences(of: "Microphone", with: "", options: .caseInsensitive)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    if name.isEmpty {
      switch type {
      case "bluetooth":
        return "Bluetooth Audio"
      case "usb":
        return "USB Audio"
      default:
        return "Audio Output"
      }
    }
    return name
  }

  private func selectAudioOutput(deviceId: String) -> Bool {
    selectedOutputDeviceId = deviceId
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP, .allowAirPlay])
      try session.setActive(true)

      if deviceId == "builtin_speaker" || deviceId.contains("speaker") {
        try session.overrideOutputAudioPort(.speaker)
      } else {
        try session.overrideOutputAudioPort(.none)

        if let availableInputs = session.availableInputs {
          if deviceId.starts(with: "bluetooth") {
            if let btInput = availableInputs.first(where: { $0.portType == .bluetoothHFP || $0.portType == .bluetoothLE }) {
              try? session.setPreferredInput(btInput)
            }
          } else if deviceId == "wired_headphones" || deviceId.contains("headphone") {
            if let wiredInput = availableInputs.first(where: { $0.portType == .headsetMic }) {
              try? session.setPreferredInput(wiredInput)
            }
          } else if deviceId.starts(with: "usb") {
            if let usbInput = availableInputs.first(where: { $0.portType == .usbAudio }) {
              try? session.setPreferredInput(usbInput)
            }
          } else {
            if let target = availableInputs.first(where: { $0.uid == deviceId || $0.portName == deviceId }) {
              try? session.setPreferredInput(target)
            }
          }
        }
      }
      DispatchQueue.main.async { [weak self] in
        self?.eventSink?(["event": "route_change"])
      }
      return true
    } catch {
      return false
    }
  }

  private func getCurrentAudioOutput() -> [String: Any]? {
    let list = getAvailableAudioOutputs()
    return list.first(where: { ($0["isSelected"] as? Bool) == true }) ?? list.first
  }

  // ==========================================
  // Audio Inputs / Microphones
  // ==========================================

  private func mapInputPortTypeToString(_ type: AVAudioSession.Port) -> String {
    switch type {
    case .builtInMic:
      return "builtInMic"
    case .headsetMic:
      return "wiredHeadsetMic"
    case .bluetoothHFP, .bluetoothLE:
      return "bluetooth"
    case .usbAudio:
      return "usb"
    default:
      return "builtInMic"
    }
  }

  private func getAvailableMicrophones() -> [[String: Any]] {
    var micList: [[String: Any]] = []

    do {
      let session = AVAudioSession.sharedInstance()
      let currentInput = session.currentRoute.inputs.first

      if let availableInputs = session.availableInputs {
        for input in availableInputs {
          let isCurrent = selectedInputDeviceId != nil
              ? (selectedInputDeviceId == input.uid || selectedInputDeviceId == input.portName)
              : (currentInput?.uid == input.uid)

          let typeStr = mapInputPortTypeToString(input.portType)
          micList.append([
            "id": input.uid,
            "name": cleanInputName(input.portName, type: typeStr),
            "type": typeStr,
            "isSelected": isCurrent
          ])
        }
      }
    } catch {
      // Fallback
    }

    if micList.isEmpty {
      micList.append([
        "id": "builtin_mic",
        "name": "Built-in Microphone",
        "type": "builtInMic",
        "isSelected": true
      ])
    } else {
      let hasSelected = micList.contains { ($0["isSelected"] as? Bool) == true }
      if !hasSelected {
        var first = micList[0]
        first["isSelected"] = true
        micList[0] = first
      }
    }

    return micList
  }

  private func cleanInputName(_ rawName: String, type: String) -> String {
    if type == "builtInMic" {
      return "Built-in Microphone"
    }
    if type == "wiredHeadsetMic" {
      return "Headset Microphone"
    }
    if rawName.lowercased().contains("mic") || rawName.lowercased().contains("microphone") {
      return rawName
    }
    switch type {
    case "bluetooth":
      return rawName.isEmpty ? "Bluetooth Microphone" : "\(rawName) Microphone"
    case "usb":
      return rawName.isEmpty ? "USB Microphone" : "\(rawName) Microphone"
    default:
      return "\(rawName) Microphone"
    }
  }

  private func selectMicrophone(deviceId: String) -> Bool {
    selectedInputDeviceId = deviceId
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP, .allowAirPlay])
      try session.setActive(true)

      if let availableInputs = session.availableInputs {
        if deviceId == "builtin_mic" {
          if let builtIn = availableInputs.first(where: { $0.portType == .builtInMic }) {
            try session.setPreferredInput(builtIn)
          } else {
            try session.setPreferredInput(nil)
          }
        } else if let target = availableInputs.first(where: { $0.uid == deviceId || $0.portName == deviceId }) {
          try session.setPreferredInput(target)
        }
      }
      DispatchQueue.main.async { [weak self] in
        self?.eventSink?(["event": "route_change"])
      }
      return true
    } catch {
      return false
    }
  }

  private func getCurrentMicrophone() -> [String: Any]? {
    do {
      let session = AVAudioSession.sharedInstance()
      if let currentInput = session.currentRoute.inputs.first {
        return [
          "id": currentInput.uid,
          "name": currentInput.portName,
          "type": mapInputPortTypeToString(currentInput.portType),
          "isSelected": true
        ]
      }
    } catch {}
    let list = getAvailableMicrophones()
    return list.first(where: { ($0["isSelected"] as? Bool) == true }) ?? list.first
  }
}
