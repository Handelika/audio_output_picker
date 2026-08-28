/// Type of audio output device.
enum AudioOutputType {
  speaker,
  receiver,
  wiredHeadphones,
  bluetooth,
  usb,
  airPlay,
  hdmi,
  unknown;

  static AudioOutputType fromString(String? type) {
    switch (type?.toLowerCase()) {
      case 'speaker':
      case 'builtin_speaker':
      case 'builtinspeaker':
        return AudioOutputType.speaker;
      case 'receiver':
      case 'builtin_earpiece':
      case 'builtinreceiver':
        return AudioOutputType.receiver;
      case 'wiredheadphones':
      case 'wired_headphones':
      case 'wired_headset':
      case 'headphones':
      case 'headset':
        return AudioOutputType.wiredHeadphones;
      case 'bluetooth':
      case 'bluetooth_a2dp':
      case 'bluetooth_sco':
      case 'bluetooth_le':
      case 'ble_headset':
      case 'ble_speaker':
      case 'hearing_aid':
        return AudioOutputType.bluetooth;
      case 'usb':
      case 'usb_device':
      case 'usb_headset':
      case 'usb_audio':
        return AudioOutputType.usb;
      case 'airplay':
        return AudioOutputType.airPlay;
      case 'hdmi':
      case 'hdmi_arc':
      case 'hdmi_earc':
        return AudioOutputType.hdmi;
      default:
        return AudioOutputType.unknown;
    }
  }

  /// Whether this output is headphones, earphones, bluetooth, or external accessory.
  bool get isHeadphonesOrBluetooth {
    return this == AudioOutputType.wiredHeadphones ||
        this == AudioOutputType.bluetooth ||
        this == AudioOutputType.usb ||
        this == AudioOutputType.airPlay;
  }

  /// Whether this output is an external audio device (not built-in speaker/receiver).
  bool get isExternal =>
      this != AudioOutputType.speaker &&
      this != AudioOutputType.receiver &&
      this != AudioOutputType.unknown;

  String toDisplayString() {
    switch (this) {
      case AudioOutputType.speaker:
        return 'Speaker';
      case AudioOutputType.receiver:
        return 'Earpiece / Receiver';
      case AudioOutputType.wiredHeadphones:
        return 'Wired Headphones';
      case AudioOutputType.bluetooth:
        return 'Bluetooth';
      case AudioOutputType.usb:
        return 'USB Audio';
      case AudioOutputType.airPlay:
        return 'AirPlay';
      case AudioOutputType.hdmi:
        return 'HDMI';
      case AudioOutputType.unknown:
        return 'Audio Output';
    }
  }
}

/// Represents an audio output device.
class AudioOutputDevice {
  const AudioOutputDevice({
    required this.id,
    required this.name,
    required this.type,
    this.isSelected = false,
  });

  /// Unique identifier of the device.
  final String id;

  /// Human-readable name of the device.
  final String name;

  /// Type category of the device.
  final AudioOutputType type;

  /// Whether this device is currently the active/selected output.
  final bool isSelected;

  /// Whether this output is a headphone, earphone, bluetooth, or external accessory.
  bool get isHeadphonesOrBluetooth => type.isHeadphonesOrBluetooth;

  /// Whether this output is an external accessory.
  bool get isExternal => type.isExternal;

  factory AudioOutputDevice.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) {
      return const AudioOutputDevice(
        id: 'unknown',
        name: 'Unknown Device',
        type: AudioOutputType.unknown,
      );
    }
    return AudioOutputDevice(
      id: map['id']?.toString() ?? 'unknown',
      name: map['name']?.toString() ?? 'Unknown Device',
      type: AudioOutputType.fromString(map['type']?.toString()),
      isSelected: map['isSelected'] == true || map['isCurrent'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'isSelected': isSelected,
    };
  }

  AudioOutputDevice copyWith({
    String? id,
    String? name,
    AudioOutputType? type,
    bool? isSelected,
  }) {
    return AudioOutputDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioOutputDevice &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'AudioOutputDevice(id: $id, name: $name, type: ${type.name}, isSelected: $isSelected)';
}

/// Type of audio input / microphone device.
enum AudioInputType {
  builtInMic,
  wiredHeadsetMic,
  bluetooth,
  usb,
  unknown;

  static AudioInputType fromString(String? type) {
    switch (type?.toLowerCase()) {
      case 'builtin_mic':
      case 'builtinmic':
      case 'built_in_mic':
      case 'mic':
      case 'microphone':
        return AudioInputType.builtInMic;
      case 'wired_headset_mic':
      case 'wiredheadsetmic':
      case 'headset_mic':
      case 'headsetmic':
      case 'wired_headset':
      case 'wiredheadset':
      case 'wired_headphones':
      case 'wiredheadphones':
        return AudioInputType.wiredHeadsetMic;
      case 'bluetooth':
      case 'bluetooth_sco':
      case 'bluetooth_le':
      case 'bluetooth_hfp':
      case 'ble_headset':
      case 'hearing_aid':
        return AudioInputType.bluetooth;
      case 'usb':
      case 'usb_device':
      case 'usb_headset':
      case 'usb_audio':
        return AudioInputType.usb;
      default:
        return AudioInputType.unknown;
    }
  }

  /// Whether this microphone is external (wired headset mic, bluetooth headset, USB mic).
  bool get isExternal =>
      this != AudioInputType.builtInMic && this != AudioInputType.unknown;

  String toDisplayString() {
    switch (this) {
      case AudioInputType.builtInMic:
        return 'Built-in Microphone';
      case AudioInputType.wiredHeadsetMic:
        return 'Headset Microphone';
      case AudioInputType.bluetooth:
        return 'Bluetooth Microphone';
      case AudioInputType.usb:
        return 'USB Microphone';
      case AudioInputType.unknown:
        return 'Microphone';
    }
  }
}

/// Represents an audio input / microphone device.
class AudioInputDevice {
  const AudioInputDevice({
    required this.id,
    required this.name,
    required this.type,
    this.isSelected = false,
  });

  /// Unique identifier of the input device.
  final String id;

  /// Human-readable name of the input device.
  final String name;

  /// Type category of the input device.
  final AudioInputType type;

  /// Whether this input device is currently active/selected.
  final bool isSelected;

  /// Whether this microphone is an external device.
  bool get isExternal => type.isExternal;

  factory AudioInputDevice.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) {
      return const AudioInputDevice(
        id: 'unknown',
        name: 'Unknown Microphone',
        type: AudioInputType.unknown,
      );
    }
    return AudioInputDevice(
      id: map['id']?.toString() ?? 'unknown',
      name: map['name']?.toString() ?? 'Unknown Microphone',
      type: AudioInputType.fromString(map['type']?.toString()),
      isSelected: map['isSelected'] == true || map['isCurrent'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'isSelected': isSelected,
    };
  }

  AudioInputDevice copyWith({
    String? id,
    String? name,
    AudioInputType? type,
    bool? isSelected,
  }) {
    return AudioInputDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioInputDevice &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'AudioInputDevice(id: $id, name: $name, type: ${type.name}, isSelected: $isSelected)';
}
