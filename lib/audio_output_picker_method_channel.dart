import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'audio_output_device.dart';
import 'audio_output_picker_platform_interface.dart';

/// An implementation of [AudioOutputPickerPlatform] that uses method channels
/// with built-in timeout guards and exception control.
class MethodChannelAudioOutputPicker extends AudioOutputPickerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('audio_output_picker');

  /// The event channel used to receive audio device and route changes.
  @visibleForTesting
  final eventChannel = const EventChannel('audio_output_picker/events');

  /// Timeout duration applied to platform method invocations to prevent UI hanging / ANRs.
  static const Duration methodTimeout = Duration(seconds: 5);

  Stream<Map<String, dynamic>>? _eventStream;

  @override
  Future<String?> getPlatformVersion() async {
    try {
      final version = await methodChannel
          .invokeMethod<String>('getPlatformVersion')
          .timeout(methodTimeout);
      return version;
    } catch (e, stack) {
      debugPrint('AudioPicker: getPlatformVersion error: $e\n$stack');
      return null;
    }
  }

  @override
  Future<bool> checkBluetoothPermission() async {
    try {
      final hasPermission = await methodChannel
          .invokeMethod<bool>('checkBluetoothPermission')
          .timeout(methodTimeout);
      return hasPermission ?? false;
    } catch (e, stack) {
      debugPrint('AudioPicker: checkBluetoothPermission error: $e\n$stack');
      return false;
    }
  }

  @override
  Future<bool> requestBluetoothPermission() async {
    try {
      final isGranted = await methodChannel
          .invokeMethod<bool>('requestBluetoothPermission')
          .timeout(const Duration(seconds: 30)); // allow time for user prompt
      return isGranted ?? false;
    } catch (e, stack) {
      debugPrint('AudioPicker: requestBluetoothPermission error: $e\n$stack');
      return false;
    }
  }

  @override
  Future<bool> checkMicrophonePermission() async {
    try {
      final hasPermission = await methodChannel
          .invokeMethod<bool>('checkMicrophonePermission')
          .timeout(methodTimeout);
      return hasPermission ?? false;
    } catch (e, stack) {
      debugPrint('AudioPicker: checkMicrophonePermission error: $e\n$stack');
      return false;
    }
  }

  @override
  Future<bool> requestMicrophonePermission() async {
    try {
      final isGranted = await methodChannel
          .invokeMethod<bool>('requestMicrophonePermission')
          .timeout(const Duration(seconds: 30)); // allow time for user prompt
      return isGranted ?? false;
    } catch (e, stack) {
      debugPrint('AudioPicker: requestMicrophonePermission error: $e\n$stack');
      return false;
    }
  }

  @override
  Future<List<AudioOutputDevice>> getAvailableAudioOutputs() async {
    try {
      final list = await methodChannel
          .invokeListMethod<dynamic>('getAvailableAudioOutputs')
          .timeout(methodTimeout);
      if (list == null) return [];
      return list
          .whereType<Map<dynamic, dynamic>>()
          .map((map) => AudioOutputDevice.fromMap(map))
          .toList();
    } catch (e, stack) {
      debugPrint('AudioPicker: getAvailableAudioOutputs error: $e\n$stack');
      return const [
        AudioOutputDevice(
          id: 'builtin_speaker',
          name: 'Speaker',
          type: AudioOutputType.speaker,
          isSelected: true,
        ),
      ];
    }
  }

  @override
  Future<bool> selectAudioOutput(String deviceId) async {
    try {
      final success = await methodChannel
          .invokeMethod<bool>('selectAudioOutput', {'deviceId': deviceId})
          .timeout(methodTimeout);
      return success ?? false;
    } catch (e, stack) {
      debugPrint('AudioPicker: selectAudioOutput error: $e\n$stack');
      return false;
    }
  }

  @override
  Future<AudioOutputDevice?> getCurrentAudioOutput() async {
    try {
      final map = await methodChannel
          .invokeMapMethod<dynamic, dynamic>('getCurrentAudioOutput')
          .timeout(methodTimeout);
      if (map == null) return null;
      return AudioOutputDevice.fromMap(map);
    } catch (e, stack) {
      debugPrint('AudioPicker: getCurrentAudioOutput error: $e\n$stack');
      return null;
    }
  }

  @override
  Future<List<AudioInputDevice>> getAvailableMicrophones() async {
    try {
      final list = await methodChannel
          .invokeListMethod<dynamic>('getAvailableMicrophones')
          .timeout(methodTimeout);
      if (list == null) return [];
      return list
          .whereType<Map<dynamic, dynamic>>()
          .map((map) => AudioInputDevice.fromMap(map))
          .toList();
    } catch (e, stack) {
      debugPrint('AudioPicker: getAvailableMicrophones error: $e\n$stack');
      return const [
        AudioInputDevice(
          id: 'builtin_mic',
          name: 'Built-in Microphone',
          type: AudioInputType.builtInMic,
          isSelected: true,
        ),
      ];
    }
  }

  @override
  Future<bool> selectMicrophone(String deviceId) async {
    try {
      final success = await methodChannel
          .invokeMethod<bool>('selectMicrophone', {'deviceId': deviceId})
          .timeout(methodTimeout);
      return success ?? false;
    } catch (e, stack) {
      debugPrint('AudioPicker: selectMicrophone error: $e\n$stack');
      return false;
    }
  }

  @override
  Future<AudioInputDevice?> getCurrentMicrophone() async {
    try {
      final map = await methodChannel
          .invokeMapMethod<dynamic, dynamic>('getCurrentMicrophone')
          .timeout(methodTimeout);
      if (map == null) return null;
      return AudioInputDevice.fromMap(map);
    } catch (e, stack) {
      debugPrint('AudioPicker: getCurrentMicrophone error: $e\n$stack');
      return null;
    }
  }

  @override
  Stream<Map<String, dynamic>> get audioDeviceEventStream {
    _eventStream ??= eventChannel
        .receiveBroadcastStream()
        .handleError((error, stackTrace) {
          debugPrint('AudioPicker: event stream error: $error\n$stackTrace');
        })
        .where((event) => event is Map)
        .map((event) => Map<String, dynamic>.from(event as Map));
    return _eventStream!;
  }
}
