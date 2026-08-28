import 'package:flutter_test/flutter_test.dart';
import 'package:audio_output_picker/audio_output_picker.dart';
import 'package:audio_output_picker/audio_output_picker_platform_interface.dart';
import 'package:audio_output_picker/audio_output_picker_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockAudioOutputPickerPlatform
    with MockPlatformInterfaceMixin
    implements AudioOutputPickerPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<bool> checkBluetoothPermission() => Future.value(true);

  @override
  Future<bool> requestBluetoothPermission() => Future.value(true);

  @override
  Future<bool> checkMicrophonePermission() => Future.value(true);

  @override
  Future<bool> requestMicrophonePermission() => Future.value(true);

  @override
  Future<List<AudioOutputDevice>> getAvailableAudioOutputs() => Future.value([
        const AudioOutputDevice(
          id: 'test_speaker',
          name: 'Speaker',
          type: AudioOutputType.speaker,
          isSelected: true,
        ),
        const AudioOutputDevice(
          id: 'test_headphones',
          name: 'Headphones',
          type: AudioOutputType.wiredHeadphones,
          isSelected: false,
        ),
      ]);

  @override
  Future<bool> selectAudioOutput(String deviceId) => Future.value(true);

  @override
  Future<AudioOutputDevice?> getCurrentAudioOutput() => Future.value(
        const AudioOutputDevice(
          id: 'test_speaker',
          name: 'Speaker',
          type: AudioOutputType.speaker,
          isSelected: true,
        ),
      );

  @override
  Future<List<AudioInputDevice>> getAvailableMicrophones() => Future.value([
        const AudioInputDevice(
          id: 'test_mic',
          name: 'Built-in Mic',
          type: AudioInputType.builtInMic,
          isSelected: true,
        ),
      ]);

  @override
  Future<bool> selectMicrophone(String deviceId) => Future.value(true);

  @override
  Future<AudioInputDevice?> getCurrentMicrophone() => Future.value(
        const AudioInputDevice(
          id: 'test_mic',
          name: 'Built-in Mic',
          type: AudioInputType.builtInMic,
          isSelected: true,
        ),
      );

  @override
  Stream<Map<String, dynamic>> get audioDeviceEventStream =>
      Stream.value({'event': 'test_route_change'});
}

void main() {
  final AudioOutputPickerPlatform initialPlatform = AudioOutputPickerPlatform.instance;

  test('$MethodChannelAudioOutputPicker is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelAudioOutputPicker>());
  });

  test('getPlatformVersion', () async {
    AudioOutputPicker audioOutputPickerPlugin = AudioOutputPicker();
    MockAudioOutputPickerPlatform fakePlatform = MockAudioOutputPickerPlatform();
    AudioOutputPickerPlatform.instance = fakePlatform;

    expect(await audioOutputPickerPlugin.getPlatformVersion(), '42');
  });

  test('checkBluetoothPermission and requestBluetoothPermission', () async {
    AudioOutputPicker audioOutputPickerPlugin = AudioOutputPicker();
    MockAudioOutputPickerPlatform fakePlatform = MockAudioOutputPickerPlatform();
    AudioOutputPickerPlatform.instance = fakePlatform;

    expect(await audioOutputPickerPlugin.checkBluetoothPermission(), true);
    expect(await audioOutputPickerPlugin.requestBluetoothPermission(), true);
    expect(await audioOutputPickerPlugin.checkPermission(), true);
    expect(await audioOutputPickerPlugin.requestPermission(), true);
  });

  test('checkMicrophonePermission and requestMicrophonePermission', () async {
    AudioOutputPicker audioOutputPickerPlugin = AudioOutputPicker();
    MockAudioOutputPickerPlatform fakePlatform = MockAudioOutputPickerPlatform();
    AudioOutputPickerPlatform.instance = fakePlatform;

    expect(await audioOutputPickerPlugin.checkMicrophonePermission(), true);
    expect(await audioOutputPickerPlugin.requestMicrophonePermission(), true);
  });

  test('getAvailableOutputs, headphones filter, selectAudioOutput, getCurrentAudioOutput', () async {
    AudioOutputPicker audioOutputPickerPlugin = AudioOutputPicker();
    MockAudioOutputPickerPlatform fakePlatform = MockAudioOutputPickerPlatform();
    AudioOutputPickerPlatform.instance = fakePlatform;

    final outputs = await audioOutputPickerPlugin.getAvailableOutputs();
    expect(outputs.length, 2);
    expect(outputs.first.name, 'Speaker');
    expect(outputs.first.type, AudioOutputType.speaker);

    final headphones = await audioOutputPickerPlugin.getAvailableHeadphonesAndBluetooth();
    expect(headphones.length, 1);
    expect(headphones.first.id, 'test_headphones');

    expect(await audioOutputPickerPlugin.selectAudioOutput('test_speaker'), true);
    expect(await audioOutputPickerPlugin.selectOutput(outputs.first), true);

    final current = await audioOutputPickerPlugin.getCurrentAudioOutput();
    expect(current?.id, 'test_speaker');
  });

  test('getAvailableMicrophones, selectMicrophone, getCurrentMicrophone', () async {
    AudioOutputPicker audioOutputPickerPlugin = AudioOutputPicker();
    MockAudioOutputPickerPlatform fakePlatform = MockAudioOutputPickerPlatform();
    AudioOutputPickerPlatform.instance = fakePlatform;

    final mics = await audioOutputPickerPlugin.getAvailableMicrophones();
    expect(mics.length, 1);
    expect(mics.first.name, 'Built-in Mic');
    expect(mics.first.type, AudioInputType.builtInMic);

    expect(await audioOutputPickerPlugin.selectMicrophone('test_mic'), true);
    expect(await audioOutputPickerPlugin.selectInput(mics.first), true);

    final current = await audioOutputPickerPlugin.getCurrentMicrophone();
    expect(current?.id, 'test_mic');
  });
}
