import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:audio_output_picker/audio_output_picker_method_channel.dart';
import 'package:audio_output_picker/audio_output_device.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelAudioOutputPicker platform = MethodChannelAudioOutputPicker();
  const MethodChannel channel = MethodChannel('audio_output_picker');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          if (methodCall.method == 'getPlatformVersion') {
            return '42';
          }
          if (methodCall.method == 'checkBluetoothPermission' ||
              methodCall.method == 'requestBluetoothPermission' ||
              methodCall.method == 'checkMicrophonePermission' ||
              methodCall.method == 'requestMicrophonePermission') {
            return true;
          }
          if (methodCall.method == 'getAvailableAudioOutputs') {
            return [
              {
                'id': 'device_1',
                'name': 'Built-in Speaker',
                'type': 'speaker',
                'isSelected': true,
              },
            ];
          }
          if (methodCall.method == 'selectAudioOutput') {
            return true;
          }
          if (methodCall.method == 'getCurrentAudioOutput') {
            return {
              'id': 'device_1',
              'name': 'Built-in Speaker',
              'type': 'speaker',
              'isSelected': true,
            };
          }
          if (methodCall.method == 'getAvailableMicrophones') {
            return [
              {
                'id': 'mic_1',
                'name': 'Built-in Microphone',
                'type': 'builtInMic',
                'isSelected': true,
              },
            ];
          }
          if (methodCall.method == 'selectMicrophone') {
            return true;
          }
          if (methodCall.method == 'getCurrentMicrophone') {
            return {
              'id': 'mic_1',
              'name': 'Built-in Microphone',
              'type': 'builtInMic',
              'isSelected': true,
            };
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });

  test('checkBluetoothPermission and requestBluetoothPermission', () async {
    expect(await platform.checkBluetoothPermission(), true);
    expect(await platform.requestBluetoothPermission(), true);
  });

  test('checkMicrophonePermission and requestMicrophonePermission', () async {
    expect(await platform.checkMicrophonePermission(), true);
    expect(await platform.requestMicrophonePermission(), true);
  });

  test(
    'getAvailableAudioOutputs, selectAudioOutput, getCurrentAudioOutput',
    () async {
      final outputs = await platform.getAvailableAudioOutputs();
      expect(outputs.length, 1);
      expect(outputs.first.name, 'Built-in Speaker');

      final selectResult = await platform.selectAudioOutput('device_1');
      expect(selectResult, true);

      final current = await platform.getCurrentAudioOutput();
      expect(current?.id, 'device_1');
    },
  );

  test(
    'getAvailableMicrophones, selectMicrophone, getCurrentMicrophone',
    () async {
      final mics = await platform.getAvailableMicrophones();
      expect(mics.length, 1);
      expect(mics.first.name, 'Built-in Microphone');

      final selectResult = await platform.selectMicrophone('mic_1');
      expect(selectResult, true);

      final current = await platform.getCurrentMicrophone();
      expect(current?.id, 'mic_1');
    },
  );

  test(
    'handles native PlatformException gracefully with safe fallbacks',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            throw PlatformException(
              code: 'ERROR',
              message: 'Simulated native crash',
            );
          });

      expect(await platform.getPlatformVersion(), isNull);
      expect(await platform.checkBluetoothPermission(), false);
      expect(await platform.requestBluetoothPermission(), false);
      expect(await platform.checkMicrophonePermission(), false);
      expect(await platform.requestMicrophonePermission(), false);

      final outputs = await platform.getAvailableAudioOutputs();
      expect(outputs.isNotEmpty, true);
      expect(outputs.first.type, AudioOutputType.speaker);

      expect(await platform.selectAudioOutput('any_id'), false);
      expect(await platform.getCurrentAudioOutput(), isNull);

      final mics = await platform.getAvailableMicrophones();
      expect(mics.isNotEmpty, true);
      expect(mics.first.type, AudioInputType.builtInMic);

      expect(await platform.selectMicrophone('any_id'), false);
      expect(await platform.getCurrentMicrophone(), isNull);
    },
  );

  test(
    'AudioOutputDevice and AudioInputDevice fromMap handle null and malformed data safely',
    () {
      final nullOutput = AudioOutputDevice.fromMap(null);
      expect(nullOutput.id, 'unknown');
      expect(nullOutput.type, AudioOutputType.unknown);

      final malformedOutput = AudioOutputDevice.fromMap({
        'id': 123,
        'name': null,
        'type': 'unsupported_type_xyz',
        'isSelected': 'not_a_bool',
      });
      expect(malformedOutput.id, '123');
      expect(malformedOutput.name, 'Unknown Device');
      expect(malformedOutput.type, AudioOutputType.unknown);
      expect(malformedOutput.isSelected, false);

      final nullInput = AudioInputDevice.fromMap(null);
      expect(nullInput.id, 'unknown');
      expect(nullInput.type, AudioInputType.unknown);

      final malformedInput = AudioInputDevice.fromMap({
        'id': 456,
        'name': null,
        'type': 'unsupported_input_type',
        'isSelected': null,
      });
      expect(malformedInput.id, '456');
      expect(malformedInput.name, 'Unknown Microphone');
      expect(malformedInput.type, AudioInputType.unknown);
      expect(malformedInput.isSelected, false);
    },
  );
}
