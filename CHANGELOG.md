## 0.0.1

* Initial release of `audio_output_picker`.
* Support for listing and switching audio output devices (Speaker, Earpiece/Receiver, Headphones, Bluetooth, USB, AirPlay, HDMI).
* Support for listing and switching microphone / audio input devices.
* Real-time reactive streams for device changes and active device updates (`onOutputsChanged`, `onCurrentOutputChanged`, `onMicrophonesChanged`, `onCurrentMicrophoneChanged`, `onHeadphonesAndBluetoothChanged`).
* Built-in customizable modal bottom sheet pickers (`showAudioOutputPickerPopup` and `showMicrophonePickerPopup`).
* Built-in permission handling for Bluetooth and Microphone on supported platforms.
* Cross-platform support: Android, iOS, macOS, Windows, Linux, and Web.

