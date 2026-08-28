import Cocoa
import FlutterMacOS
import CoreAudio
import AudioToolbox
import AVFoundation

public class AudioOutputPickerPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var selectedOutputDeviceId: String? = nil
  private var selectedInputDeviceId: String? = nil
  private var eventSink: FlutterEventSink?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let methodChannel = FlutterMethodChannel(name: "audio_output_picker", binaryMessenger: registrar.messenger)
    let eventChannel = FlutterEventChannel(name: "audio_output_picker/events", binaryMessenger: registrar.messenger)

    let instance = AudioOutputPickerPlugin()
    registrar.addMethodCallDelegate(instance, channel: methodChannel)
    eventChannel.setStreamHandler(instance)
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events
    addAudioPropertyListeners()
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    removeAudioPropertyListeners()
    self.eventSink = nil
    return nil
  }

  private func notifyDeviceChanged() {
    DispatchQueue.main.async { [weak self] in
      self?.eventSink?(["event": "devices_changed"])
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
      self?.eventSink?(["event": "devices_changed_settled"])
    }
  }

  private var listenerBlock: AudioObjectPropertyListenerBlock?

  private func addAudioPropertyListeners() {
    var devicesAddress = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDevices,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var defaultOutputAddress = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultOutputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var defaultInputAddress = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultInputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )

    listenerBlock = { [weak self] _, _ in
      self?.selectedOutputDeviceId = nil
      self?.selectedInputDeviceId = nil
      self?.notifyDeviceChanged()
    }

    if let block = listenerBlock {
      AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &devicesAddress, DispatchQueue.main, block)
      AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defaultOutputAddress, DispatchQueue.main, block)
      AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defaultInputAddress, DispatchQueue.main, block)
    }
  }

  private func removeAudioPropertyListeners() {
    if let block = listenerBlock {
      var devicesAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
      )
      var defaultOutputAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
      )
      var defaultInputAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
      )
      AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &devicesAddress, DispatchQueue.main, block)
      AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defaultOutputAddress, DispatchQueue.main, block)
      AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defaultInputAddress, DispatchQueue.main, block)
      listenerBlock = nil
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
      safeResult("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
    case "checkBluetoothPermission", "checkPermission", "requestBluetoothPermission", "requestPermission":
      safeResult(true)
    case "checkMicrophonePermission":
      if #available(macOS 10.14, *) {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        safeResult(status == .authorized)
      } else {
        safeResult(true)
      }
    case "requestMicrophonePermission":
      if #available(macOS 10.14, *) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
          safeResult(granted)
        }
      } else {
        safeResult(true)
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
  // Core Audio Helpers
  // ==========================================

  private func getDefaultOutputDeviceID() -> AudioDeviceID {
    var deviceID = AudioDeviceID(0)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultOutputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
    return status == noErr ? deviceID : AudioDeviceID(0)
  }

  private func getDefaultInputDeviceID() -> AudioDeviceID {
    var deviceID = AudioDeviceID(0)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultInputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
    return status == noErr ? deviceID : AudioDeviceID(0)
  }

  private func getDeviceUID(deviceID: AudioDeviceID) -> String {
    var uid: CFString = "" as CFString
    var size = UInt32(MemoryLayout<CFString>.size)
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyDeviceUID,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &uid)
    if status == noErr {
      return uid as String
    }
    return "\(deviceID)"
  }

  private func isDeviceAlive(deviceID: AudioDeviceID) -> Bool {
    var isAlive: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyDeviceIsAlive,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &isAlive)
    return status == noErr && isAlive != 0
  }

  private func isDeviceHidden(deviceID: AudioDeviceID) -> Bool {
    var isHidden: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyIsHidden,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &isHidden)
    return status == noErr && isHidden != 0
  }

  private func getDeviceChannelCount(deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> Int {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyStreamConfiguration,
      mScope: scope,
      mElement: kAudioObjectPropertyElementMain
    )
    var size: UInt32 = 0
    let status = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size)
    guard status == noErr, size > 0 else { return 0 }

    let rawBufferList = malloc(Int(size))
    guard let rawBufferList = rawBufferList else { return 0 }
    defer { free(rawBufferList) }

    let bufferList = rawBufferList.bindMemory(to: AudioBufferList.self, capacity: 1)
    let getStatus = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, bufferList)
    guard getStatus == noErr else { return 0 }

    let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
    var channels = 0
    for buffer in buffers {
      channels += Int(buffer.mNumberChannels)
    }
    return channels
  }

  private func getTransportType(deviceID: AudioDeviceID) -> UInt32 {
    var transport: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyTransportType,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &transport)
    return status == noErr ? transport : 0
  }

  private func getDeviceName(deviceID: AudioDeviceID) -> String {
    var name: CFString = "" as CFString
    var size = UInt32(MemoryLayout<CFString>.size)
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyDeviceNameCFString,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &name)
    if status == noErr {
      return name as String
    }
    return "Audio Device \(deviceID)"
  }

  private func inferOutputType(name: String) -> String {
    let lower = name.lowercased()
    if lower.contains("speaker") || lower.contains("macbook") || lower.contains("imac") || lower.contains("built-in") {
      return "speaker"
    } else if lower.contains("headphone") || lower.contains("airpods") || lower.contains("buds") || lower.contains("earphones") {
      if lower.contains("bluetooth") || lower.contains("airpods") || lower.contains("wireless") {
        return "bluetooth"
      }
      return "wiredHeadphones"
    } else if lower.contains("bluetooth") {
      return "bluetooth"
    } else if lower.contains("usb") {
      return "usb"
    } else if lower.contains("hdmi") || lower.contains("display") {
      return "hdmi"
    } else if lower.contains("airplay") {
      return "airPlay"
    }
    return "speaker"
  }

  private func inferInputType(name: String) -> String {
    let lower = name.lowercased()
    if lower.contains("internal") || lower.contains("built-in") || lower.contains("macbook") || lower.contains("imac") {
      return "builtInMic"
    } else if lower.contains("airpods") || lower.contains("bluetooth") || lower.contains("wireless") {
      return "bluetooth"
    } else if lower.contains("headset") || lower.contains("headphone") {
      return "wiredHeadsetMic"
    } else if lower.contains("usb") {
      return "usb"
    }
    return "builtInMic"
  }

  private func getAllAudioDeviceIDs() -> [AudioDeviceID] {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDevices,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var size: UInt32 = 0
    var status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size)
    guard status == noErr, size > 0 else { return [] }

    let deviceCount = Int(size) / MemoryLayout<AudioDeviceID>.size
    guard deviceCount > 0 else { return [] }
    var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
    status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceIDs)
    guard status == noErr else { return [] }
    return deviceIDs
  }

  // ==========================================
  // Audio Outputs
  // ==========================================

  private func getAvailableAudioOutputs() -> [[String: Any]] {
    let deviceIDs = getAllAudioDeviceIDs()
    let defaultDeviceID = getDefaultOutputDeviceID()
    let defaultUID = getDeviceUID(deviceID: defaultDeviceID)

    var devicesList: [[String: Any]] = []
    for id in deviceIDs {
      guard isDeviceAlive(deviceID: id), !isDeviceHidden(deviceID: id) else { continue }
      guard getDeviceChannelCount(deviceID: id, scope: kAudioObjectPropertyScopeOutput) > 0 else { continue }
      guard getTransportType(deviceID: id) != kAudioDeviceTransportTypeVirtual else { continue }

      let uid = getDeviceUID(deviceID: id)
      let name = getDeviceName(deviceID: id)
      let isSelected = selectedOutputDeviceId != nil
          ? (selectedOutputDeviceId == uid || selectedOutputDeviceId == "\(id)")
          : (uid == defaultUID || id == defaultDeviceID)

      devicesList.append([
        "id": uid,
        "name": name,
        "type": inferOutputType(name: name),
        "isSelected": isSelected
      ])
    }

    if devicesList.isEmpty {
      devicesList.append([
        "id": "builtin_speaker",
        "name": "Mac Speakers",
        "type": "speaker",
        "isSelected": true
      ])
    }

    return devicesList
  }

  private func selectAudioOutput(deviceId: String) -> Bool {
    selectedOutputDeviceId = deviceId
    let deviceIDs = getAllAudioDeviceIDs()

    for id in deviceIDs {
      let uid = getDeviceUID(deviceID: id)
      if uid == deviceId || "\(id)" == deviceId {
        var targetID = id
        var setAddress = AudioObjectPropertyAddress(
          mSelector: kAudioHardwarePropertyDefaultOutputDevice,
          mScope: kAudioObjectPropertyScopeGlobal,
          mElement: kAudioObjectPropertyElementMain
        )
        let setStatus = AudioObjectSetPropertyData(
          AudioObjectID(kAudioObjectSystemObject),
          &setAddress,
          0,
          nil,
          UInt32(MemoryLayout<AudioDeviceID>.size),
          &targetID
        )
        notifyDeviceChanged()
        return setStatus == noErr
      }
    }
    return true
  }

  private func getCurrentAudioOutput() -> [String: Any]? {
    let list = getAvailableAudioOutputs()
    return list.first(where: { ($0["isSelected"] as? Bool) == true }) ?? list.first
  }

  // ==========================================
  // Audio Inputs / Microphones
  // ==========================================

  private func getAvailableMicrophones() -> [[String: Any]] {
    let deviceIDs = getAllAudioDeviceIDs()
    let defaultDeviceID = getDefaultInputDeviceID()
    let defaultUID = getDeviceUID(deviceID: defaultDeviceID)

    var devicesList: [[String: Any]] = []
    for id in deviceIDs {
      guard isDeviceAlive(deviceID: id), !isDeviceHidden(deviceID: id) else { continue }
      guard getDeviceChannelCount(deviceID: id, scope: kAudioObjectPropertyScopeInput) > 0 else { continue }
      guard getTransportType(deviceID: id) != kAudioDeviceTransportTypeVirtual else { continue }

      let uid = getDeviceUID(deviceID: id)
      let name = getDeviceName(deviceID: id)
      let isSelected = selectedInputDeviceId != nil
          ? (selectedInputDeviceId == uid || selectedInputDeviceId == "\(id)")
          : (uid == defaultUID || id == defaultDeviceID)

      devicesList.append([
        "id": uid,
        "name": name,
        "type": inferInputType(name: name),
        "isSelected": isSelected
      ])
    }

    if devicesList.isEmpty {
      devicesList.append([
        "id": "builtin_mic",
        "name": "Mac Microphone",
        "type": "builtInMic",
        "isSelected": true
      ])
    }

    return devicesList
  }

  private func selectMicrophone(deviceId: String) -> Bool {
    selectedInputDeviceId = deviceId
    let deviceIDs = getAllAudioDeviceIDs()

    for id in deviceIDs {
      let uid = getDeviceUID(deviceID: id)
      if uid == deviceId || "\(id)" == deviceId {
        var targetID = id
        var setAddress = AudioObjectPropertyAddress(
          mSelector: kAudioHardwarePropertyDefaultInputDevice,
          mScope: kAudioObjectPropertyScopeGlobal,
          mElement: kAudioObjectPropertyElementMain
        )
        let setStatus = AudioObjectSetPropertyData(
          AudioObjectID(kAudioObjectSystemObject),
          &setAddress,
          0,
          nil,
          UInt32(MemoryLayout<AudioDeviceID>.size),
          &targetID
        )
        notifyDeviceChanged()
        return setStatus == noErr
      }
    }
    return true
  }

  private func getCurrentMicrophone() -> [String: Any]? {
    let list = getAvailableMicrophones()
    return list.first(where: { ($0["isSelected"] as? Bool) == true }) ?? list.first
  }
}
