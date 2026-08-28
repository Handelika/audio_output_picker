import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'audio_output_device.dart';
import 'audio_output_picker_method_channel.dart';

abstract class AudioOutputPickerPlatform extends PlatformInterface {
  /// Constructs a AudioOutputPickerPlatform.
  AudioOutputPickerPlatform() : super(token: _token);

  static final Object _token = Object();

  static AudioOutputPickerPlatform _instance = MethodChannelAudioOutputPicker();

  /// The default instance of [AudioOutputPickerPlatform] to use.
  ///
  /// Defaults to [MethodChannelAudioOutputPicker].
  static AudioOutputPickerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [AudioOutputPickerPlatform] when
  /// they register themselves.
  static set instance(AudioOutputPickerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  /// Checks if required bluetooth permissions (e.g. Bluetooth Connect on Android 12+) are granted.
  Future<bool> checkBluetoothPermission() {
    throw UnimplementedError(
      'checkBluetoothPermission() has not been implemented.',
    );
  }

  /// Requests required bluetooth permissions directly without 3rd party plugins.
  Future<bool> requestBluetoothPermission() {
    throw UnimplementedError(
      'requestBluetoothPermission() has not been implemented.',
    );
  }

  /// Checks if microphone recording permission is granted.
  Future<bool> checkMicrophonePermission() {
    throw UnimplementedError(
      'checkMicrophonePermission() has not been implemented.',
    );
  }

  /// Requests microphone recording permission directly.
  Future<bool> requestMicrophonePermission() {
    throw UnimplementedError(
      'requestMicrophonePermission() has not been implemented.',
    );
  }

  /// Gets the list of available audio output devices.
  Future<List<AudioOutputDevice>> getAvailableAudioOutputs() {
    throw UnimplementedError(
      'getAvailableAudioOutputs() has not been implemented.',
    );
  }

  /// Selects the audio output device with the given [deviceId].
  Future<bool> selectAudioOutput(String deviceId) {
    throw UnimplementedError('selectAudioOutput() has not been implemented.');
  }

  /// Gets the currently active audio output device, or null if none/unknown.
  Future<AudioOutputDevice?> getCurrentAudioOutput() {
    throw UnimplementedError(
      'getCurrentAudioOutput() has not been implemented.',
    );
  }

  /// Gets the list of available microphone / audio input devices.
  Future<List<AudioInputDevice>> getAvailableMicrophones() {
    throw UnimplementedError(
      'getAvailableMicrophones() has not been implemented.',
    );
  }

  /// Selects the microphone / audio input device with the given [deviceId].
  Future<bool> selectMicrophone(String deviceId) {
    throw UnimplementedError('selectMicrophone() has not been implemented.');
  }

  /// Gets the currently active microphone / audio input device, or null if none/unknown.
  Future<AudioInputDevice?> getCurrentMicrophone() {
    throw UnimplementedError(
      'getCurrentMicrophone() has not been implemented.',
    );
  }

  /// Stream of raw device / route change events from the native platform.
  Stream<Map<String, dynamic>> get audioDeviceEventStream {
    throw UnimplementedError(
      'audioDeviceEventStream has not been implemented.',
    );
  }
}
