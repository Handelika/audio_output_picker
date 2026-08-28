import 'dart:async';
import 'dart:js_interop';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'audio_output_device.dart';
import 'audio_output_picker_platform_interface.dart';

/// A web implementation of the AudioOutputPickerPlatform of the AudioOutputPicker plugin.
class AudioOutputPickerWeb extends AudioOutputPickerPlatform {
  /// Constructs a AudioOutputPickerWeb
  AudioOutputPickerWeb() {
    _initDeviceChangeListener();
  }

  static void registerWith(Registrar registrar) {
    AudioOutputPickerPlatform.instance = AudioOutputPickerWeb();
  }

  final StreamController<Map<String, dynamic>> _eventController =
      StreamController<Map<String, dynamic>>.broadcast();

  void _initDeviceChangeListener() {
    try {
      final mediaDevices = web.window.navigator.mediaDevices;
      mediaDevices.ondevicechange = ((web.Event event) {
        _eventController.add({'event': 'device_change'});
      }).toJS;
    } catch (_) {}
  }

  /// Returns a [String] containing the version of the platform.
  @override
  Future<String?> getPlatformVersion() async {
    final version = web.window.navigator.userAgent;
    return version;
  }

  @override
  Future<bool> checkBluetoothPermission() async => true;

  @override
  Future<bool> requestBluetoothPermission() async => true;

  @override
  Future<bool> checkMicrophonePermission() async => true;

  @override
  Future<bool> requestMicrophonePermission() async => true;

  @override
  Future<List<AudioOutputDevice>> getAvailableAudioOutputs() async {
    final List<AudioOutputDevice> devices = [];
    try {
      final mediaDevices = web.window.navigator.mediaDevices;
      final jsDevices = await mediaDevices.enumerateDevices().toDart;
      final count = jsDevices.length;
      for (var i = 0; i < count; i++) {
        final device = jsDevices[i];
        if (device.kind == 'audiooutput') {
          final id = device.deviceId;
          final label = device.label.isNotEmpty ? device.label : 'Audio Output ${devices.length + 1}';
          devices.add(
            AudioOutputDevice(
              id: id,
              name: label,
              type: AudioOutputType.speaker,
              isSelected: devices.isEmpty,
            ),
          );
        }
      }
    } catch (_) {}

    if (devices.isEmpty) {
      devices.add(
        const AudioOutputDevice(
          id: 'default',
          name: 'Default Audio Output',
          type: AudioOutputType.speaker,
          isSelected: true,
        ),
      );
    }

    return devices;
  }

  @override
  Future<bool> selectAudioOutput(String deviceId) async {
    return true;
  }

  @override
  Future<AudioOutputDevice?> getCurrentAudioOutput() async {
    final outputs = await getAvailableAudioOutputs();
    return outputs.firstWhere(
      (d) => d.isSelected,
      orElse: () => outputs.isNotEmpty ? outputs.first : const AudioOutputDevice(id: 'default', name: 'Default Audio Output', type: AudioOutputType.speaker, isSelected: true),
    );
  }

  @override
  Future<List<AudioInputDevice>> getAvailableMicrophones() async {
    final List<AudioInputDevice> devices = [];
    try {
      final mediaDevices = web.window.navigator.mediaDevices;
      final jsDevices = await mediaDevices.enumerateDevices().toDart;
      final count = jsDevices.length;
      for (var i = 0; i < count; i++) {
        final device = jsDevices[i];
        if (device.kind == 'audioinput') {
          final id = device.deviceId;
          final label = device.label.isNotEmpty ? device.label : 'Microphone ${devices.length + 1}';
          devices.add(
            AudioInputDevice(
              id: id,
              name: label,
              type: AudioInputType.builtInMic,
              isSelected: devices.isEmpty,
            ),
          );
        }
      }
    } catch (_) {}

    if (devices.isEmpty) {
      devices.add(
        const AudioInputDevice(
          id: 'default',
          name: 'Default Microphone',
          type: AudioInputType.builtInMic,
          isSelected: true,
        ),
      );
    }

    return devices;
  }

  @override
  Future<bool> selectMicrophone(String deviceId) async {
    return true;
  }

  @override
  Future<AudioInputDevice?> getCurrentMicrophone() async {
    final mics = await getAvailableMicrophones();
    return mics.firstWhere(
      (d) => d.isSelected,
      orElse: () => mics.isNotEmpty ? mics.first : const AudioInputDevice(id: 'default', name: 'Default Microphone', type: AudioInputType.builtInMic, isSelected: true),
    );
  }

  @override
  Stream<Map<String, dynamic>> get audioDeviceEventStream => _eventController.stream;
}
