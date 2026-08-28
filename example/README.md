# audio_output_picker_example

A complete Flutter sample application demonstrating how to use the [`audio_output_picker`](https://pub.dev/packages/audio_output_picker) package to enumerate, monitor, and switch audio output devices and microphone inputs across platforms.

---

## Example Usage

Here is a minimal, complete runnable Flutter application demonstrating how to initialize the plugin, request permissions, listen to device streams, and trigger the pre-built bottom sheet pickers:

```dart
import 'package:flutter/material.dart';
import 'package:audio_output_picker/audio_output_picker.dart';

void main() {
  runApp(const MaterialApp(
    home: AudioPickerExampleScreen(),
    debugShowCheckedModeBanner: false,
  ));
}

class AudioPickerExampleScreen extends StatefulWidget {
  const AudioPickerExampleScreen({super.key});

  @override
  State<AudioPickerExampleScreen> createState() => _AudioPickerExampleScreenState();
}

class _AudioPickerExampleScreenState extends State<AudioPickerExampleScreen> {
  final _picker = AudioOutputPicker();
  AudioOutputDevice? _currentOutput;
  AudioInputDevice? _currentMic;

  @override
  void initState() {
    super.initState();
    _initPicker();
  }

  Future<void> _initPicker() async {
    // 1. Request required Bluetooth and Microphone permissions
    await _picker.requestBluetoothPermission();
    await _picker.requestMicrophonePermission();

    // 2. Fetch initially active devices
    final output = await _picker.getCurrentAudioOutput();
    final mic = await _picker.getCurrentMicrophone();

    if (mounted) {
      setState(() {
        _currentOutput = output;
        _currentMic = mic;
      });
    }

    // 3. Subscribe to real-time device changes
    _picker.onCurrentOutputChanged.listen((output) {
      if (mounted) setState(() => _currentOutput = output);
    });

    _picker.onCurrentMicrophoneChanged.listen((mic) {
      if (mounted) setState(() => _currentMic = mic);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audio Output Picker Example')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Active Output: ${_currentOutput?.name ?? "Default"}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Active Mic: ${_currentMic?.name ?? "Default"}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.volume_up_rounded),
                label: const Text('Choose Audio Output'),
                onPressed: () => _picker.showAudioOutputPickerPopup(context: context),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.mic_rounded),
                label: const Text('Choose Microphone'),
                onPressed: () => _picker.showMicrophonePickerPopup(context: context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

## Running the Example App

1. Clone or download the repository.
2. Navigate to the `example` directory:

```bash
cd example
```

3. Fetch dependencies:

```bash
flutter pub get
```

4. Run the app on your desired target platform (Android, iOS, macOS, Windows, Linux, or Web):

```bash
flutter run
```

---

## What this Example App Demonstrates

- **Permission Management**: Requesting Bluetooth and microphone permissions at runtime.
- **Audio Output Selection**: Switching audio routes between Built-in Speaker, Earpiece/Receiver, Wired Headphones, Bluetooth Headsets, USB Audio, AirPlay, and HDMI.
- **Microphone Selection**: Enumerating and selecting active input recording sources.
- **Real-Time Reactive Streams**: Dynamic UI updates as audio devices connect, disconnect, or switch.
- **Pre-Built Modal Sheets**: Using `showAudioOutputPickerPopup` and `showMicrophonePickerPopup` for out-of-the-box native-like UI experience.
- **Live Playback Testing**: Built-in sample audio playback to test device routing in real-time.
