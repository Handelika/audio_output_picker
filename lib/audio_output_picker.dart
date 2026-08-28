import 'dart:async';
import 'package:flutter/material.dart';

import 'audio_output_device.dart';
import 'audio_output_picker_platform_interface.dart';

export 'audio_output_device.dart';

class AudioOutputPicker {
  /// Gets platform version string.
  Future<String?> getPlatformVersion() {
    return AudioOutputPickerPlatform.instance.getPlatformVersion();
  }

  // ==========================================
  // Permissions
  // ==========================================

  /// Checks if required bluetooth permissions (e.g. Bluetooth Connect on Android 12+) are granted.
  Future<bool> checkBluetoothPermission() {
    return AudioOutputPickerPlatform.instance.checkBluetoothPermission();
  }

  /// Requests required bluetooth permissions directly without external packages.
  Future<bool> requestBluetoothPermission() {
    return AudioOutputPickerPlatform.instance.requestBluetoothPermission();
  }

  /// Alias for [checkBluetoothPermission].
  Future<bool> checkPermission() => checkBluetoothPermission();

  /// Alias for [requestBluetoothPermission].
  Future<bool> requestPermission() => requestBluetoothPermission();

  /// Checks if microphone recording permission is granted.
  Future<bool> checkMicrophonePermission() {
    return AudioOutputPickerPlatform.instance.checkMicrophonePermission();
  }

  /// Requests microphone recording permission directly without external packages.
  Future<bool> requestMicrophonePermission() {
    return AudioOutputPickerPlatform.instance.requestMicrophonePermission();
  }

  /// Alias for [checkMicrophonePermission].
  Future<bool> checkMicPermission() => checkMicrophonePermission();

  /// Alias for [requestMicrophonePermission].
  Future<bool> requestMicPermission() => requestMicrophonePermission();

  // ==========================================
  // Audio Outputs (Speakers, Headphones, BT)
  // ==========================================

  /// Gets list of all available audio output devices.
  Future<List<AudioOutputDevice>> getAvailableOutputs() {
    return AudioOutputPickerPlatform.instance.getAvailableAudioOutputs();
  }

  /// Gets list of available headphones, earphones, bluetooth headsets, and external output devices only.
  Future<List<AudioOutputDevice>> getAvailableHeadphonesAndBluetooth() async {
    final outputs = await getAvailableOutputs();
    return outputs.where((device) => device.isHeadphonesOrBluetooth).toList();
  }

  /// Selects the audio output device with the specified [deviceId].
  Future<bool> selectAudioOutput(String deviceId) {
    return AudioOutputPickerPlatform.instance.selectAudioOutput(deviceId);
  }

  /// Selects the given [device].
  Future<bool> selectOutput(AudioOutputDevice device) {
    return selectAudioOutput(device.id);
  }

  /// Gets the currently active audio output device.
  Future<AudioOutputDevice?> getCurrentAudioOutput() {
    return AudioOutputPickerPlatform.instance.getCurrentAudioOutput();
  }

  // ==========================================
  // Audio Inputs / Microphones
  // ==========================================

  /// Gets list of available microphone / input devices.
  Future<List<AudioInputDevice>> getAvailableMicrophones() {
    return AudioOutputPickerPlatform.instance.getAvailableMicrophones();
  }

  /// Selects the microphone / input device with the specified [deviceId].
  Future<bool> selectMicrophone(String deviceId) {
    return AudioOutputPickerPlatform.instance.selectMicrophone(deviceId);
  }

  /// Selects the given [device].
  Future<bool> selectInput(AudioInputDevice device) {
    return selectMicrophone(device.id);
  }

  /// Gets the currently active microphone / input device.
  Future<AudioInputDevice?> getCurrentMicrophone() {
    return AudioOutputPickerPlatform.instance.getCurrentMicrophone();
  }

  // ==========================================
  // Reactive Streams & Listeners
  // ==========================================

  /// Raw event stream from the native platform.
  Stream<Map<String, dynamic>> get deviceEvents =>
      AudioOutputPickerPlatform.instance.audioDeviceEventStream;

  /// Stream that emits whenever available audio output devices change.
  Stream<List<AudioOutputDevice>> get onOutputsChanged async* {
    try {
      yield await getAvailableOutputs();
    } catch (_) {
      yield const [
        AudioOutputDevice(
          id: 'builtin_speaker',
          name: 'Speaker',
          type: AudioOutputType.speaker,
          isSelected: true,
        ),
      ];
    }
    yield* deviceEvents.asyncMap((_) async {
      try {
        return await getAvailableOutputs();
      } catch (_) {
        return const [
          AudioOutputDevice(
            id: 'builtin_speaker',
            name: 'Speaker',
            type: AudioOutputType.speaker,
            isSelected: true,
          ),
        ];
      }
    });
  }

  /// Dedicated stream that emits and listens ONLY to connected headphones, earphones,
  /// bluetooth headsets, and external output devices.
  Stream<List<AudioOutputDevice>> get onHeadphonesAndBluetoothChanged async* {
    try {
      yield await getAvailableHeadphonesAndBluetooth();
    } catch (_) {
      yield const [];
    }
    yield* deviceEvents.asyncMap((_) async {
      try {
        return await getAvailableHeadphonesAndBluetooth();
      } catch (_) {
        return const [];
      }
    });
  }

  /// Stream that emits whenever the currently active output device changes.
  Stream<AudioOutputDevice?> get onCurrentOutputChanged async* {
    try {
      yield await getCurrentAudioOutput();
    } catch (_) {
      yield null;
    }
    yield* deviceEvents.asyncMap((_) async {
      try {
        return await getCurrentAudioOutput();
      } catch (_) {
        return null;
      }
    });
  }

  /// Stream that emits whenever available microphone / audio input devices change.
  Stream<List<AudioInputDevice>> get onMicrophonesChanged async* {
    try {
      yield await getAvailableMicrophones();
    } catch (_) {
      yield const [
        AudioInputDevice(
          id: 'builtin_mic',
          name: 'Built-in Microphone',
          type: AudioInputType.builtInMic,
          isSelected: true,
        ),
      ];
    }
    yield* deviceEvents.asyncMap((_) async {
      try {
        return await getAvailableMicrophones();
      } catch (_) {
        return const [
          AudioInputDevice(
            id: 'builtin_mic',
            name: 'Built-in Microphone',
            type: AudioInputType.builtInMic,
            isSelected: true,
          ),
        ];
      }
    });
  }

  /// Stream that emits whenever the active microphone / audio input device changes.
  Stream<AudioInputDevice?> get onCurrentMicrophoneChanged async* {
    try {
      yield await getCurrentMicrophone();
    } catch (_) {
      yield null;
    }
    yield* deviceEvents.asyncMap((_) async {
      try {
        return await getCurrentMicrophone();
      } catch (_) {
        return null;
      }
    });
  }

  // ==========================================
  // UI Pickers / Sheets
  // ==========================================

  /// Displays a modal popup (bottom sheet) to choose an audio output from available devices.
  ///
  /// Set [onlyHeadphonesAndBluetooth] to true to restrict list to headphones, earphones & bluetooth only.
  Future<AudioOutputDevice?> showAudioOutputPickerPopup({
    required BuildContext context,
    String title = 'Audio Output',
    String? subtitle,
    bool onlyHeadphonesAndBluetooth = false,
    bool autoSelectOnTap = true,
  }) async {
    List<AudioOutputDevice> outputs;
    try {
      outputs = onlyHeadphonesAndBluetooth
          ? await getAvailableHeadphonesAndBluetooth()
          : await getAvailableOutputs();
    } catch (e) {
      debugPrint(
        'AudioPicker: showAudioOutputPickerPopup error fetching devices: $e',
      );
      outputs = const [
        AudioOutputDevice(
          id: 'builtin_speaker',
          name: 'Speaker',
          type: AudioOutputType.speaker,
          isSelected: true,
        ),
      ];
    }
    if (!context.mounted) return null;

    try {
      return await showModalBottomSheet<AudioOutputDevice>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (ctx) {
          return _AudioOutputPickerSheet(
            outputs: outputs,
            title: title,
            subtitle:
                subtitle ??
                (onlyHeadphonesAndBluetooth
                    ? 'Select headphones or bluetooth output'
                    : 'Select audio playback destination'),
            onSelect: (device) async {
              if (autoSelectOnTap) {
                try {
                  await selectOutput(device);
                } catch (e) {
                  debugPrint('AudioPicker: autoSelectOnTap error: $e');
                }
              }
              if (ctx.mounted) {
                Navigator.of(ctx).pop(device);
              }
            },
          );
        },
      );
    } catch (e) {
      debugPrint('AudioPicker: showAudioOutputPickerPopup sheet error: $e');
      return null;
    }
  }

  /// Displays a modal popup (bottom sheet) to choose a microphone / input device.
  Future<AudioInputDevice?> showMicrophonePickerPopup({
    required BuildContext context,
    String title = 'Microphone Input',
    String? subtitle,
    bool autoSelectOnTap = true,
  }) async {
    List<AudioInputDevice> microphones;
    try {
      microphones = await getAvailableMicrophones();
    } catch (e) {
      debugPrint(
        'AudioPicker: showMicrophonePickerPopup error fetching devices: $e',
      );
      microphones = const [
        AudioInputDevice(
          id: 'builtin_mic',
          name: 'Built-in Microphone',
          type: AudioInputType.builtInMic,
          isSelected: true,
        ),
      ];
    }
    if (!context.mounted) return null;

    try {
      return await showModalBottomSheet<AudioInputDevice>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (ctx) {
          return _MicrophonePickerSheet(
            microphones: microphones,
            title: title,
            subtitle: subtitle ?? 'Select audio input / recording source',
            onSelect: (device) async {
              if (autoSelectOnTap) {
                try {
                  await selectInput(device);
                } catch (e) {
                  debugPrint('AudioPicker: autoSelectOnTap error: $e');
                }
              }
              if (ctx.mounted) {
                Navigator.of(ctx).pop(device);
              }
            },
          );
        },
      );
    } catch (e) {
      debugPrint('AudioPicker: showMicrophonePickerPopup sheet error: $e');
      return null;
    }
  }
}

class _AudioOutputPickerSheet extends StatefulWidget {
  const _AudioOutputPickerSheet({
    required this.outputs,
    required this.title,
    this.subtitle,
    required this.onSelect,
  });

  final List<AudioOutputDevice> outputs;
  final String title;
  final String? subtitle;
  final ValueChanged<AudioOutputDevice> onSelect;

  @override
  State<_AudioOutputPickerSheet> createState() =>
      _AudioOutputPickerSheetState();
}

class _AudioOutputPickerSheetState extends State<_AudioOutputPickerSheet> {
  late List<AudioOutputDevice> _devices;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _devices = List.from(widget.outputs);
    final selected = _devices.where((d) => d.isSelected);
    _selectedId = selected.isNotEmpty
        ? selected.first.id
        : (_devices.isNotEmpty ? _devices.first.id : null);
  }

  IconData _getDeviceIcon(AudioOutputType type) {
    switch (type) {
      case AudioOutputType.speaker:
        return Icons.volume_up_rounded;
      case AudioOutputType.receiver:
        return Icons.phone_in_talk_rounded;
      case AudioOutputType.wiredHeadphones:
        return Icons.headphones_rounded;
      case AudioOutputType.bluetooth:
        return Icons.bluetooth_audio_rounded;
      case AudioOutputType.usb:
        return Icons.usb_rounded;
      case AudioOutputType.airPlay:
        return Icons.airplay_rounded;
      case AudioOutputType.hdmi:
        return Icons.tv_rounded;
      case AudioOutputType.unknown:
        return Icons.speaker_group_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Material(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          elevation: 6,
          shadowColor: Colors.black.withAlpha(50),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withAlpha(80),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.surround_sound_rounded,
                        color: colorScheme.onPrimaryContainer,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle ??
                                'Select audio playback destination',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (_devices.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.speaker_notes_off_rounded,
                        size: 40,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No audio outputs found',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _devices.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 64),
                    itemBuilder: (ctx, index) {
                      final device = _devices[index];
                      final isCurrent = device.id == _selectedId;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        leading: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? colorScheme.primary
                                : colorScheme.surfaceContainerHighest,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getDeviceIcon(device.type),
                            color: isCurrent
                                ? colorScheme.onPrimary
                                : colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          device.name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: isCurrent
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isCurrent
                                ? colorScheme.primary
                                : colorScheme.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          device.type.toDisplayString(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: isCurrent
                            ? Icon(
                                Icons.check_circle_rounded,
                                color: colorScheme.primary,
                                size: 22,
                              )
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedId = device.id;
                          });
                          widget.onSelect(device);
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _MicrophonePickerSheet extends StatefulWidget {
  const _MicrophonePickerSheet({
    required this.microphones,
    required this.title,
    this.subtitle,
    required this.onSelect,
  });

  final List<AudioInputDevice> microphones;
  final String title;
  final String? subtitle;
  final ValueChanged<AudioInputDevice> onSelect;

  @override
  State<_MicrophonePickerSheet> createState() => _MicrophonePickerSheetState();
}

class _MicrophonePickerSheetState extends State<_MicrophonePickerSheet> {
  late List<AudioInputDevice> _devices;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _devices = List.from(widget.microphones);
    final selected = _devices.where((d) => d.isSelected);
    _selectedId = selected.isNotEmpty
        ? selected.first.id
        : (_devices.isNotEmpty ? _devices.first.id : null);
  }

  IconData _getInputIcon(AudioInputType type) {
    switch (type) {
      case AudioInputType.builtInMic:
        return Icons.mic_rounded;
      case AudioInputType.wiredHeadsetMic:
        return Icons.headset_mic_rounded;
      case AudioInputType.bluetooth:
        return Icons.bluetooth_audio_rounded;
      case AudioInputType.usb:
        return Icons.usb_rounded;
      case AudioInputType.unknown:
        return Icons.mic_none_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Material(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          elevation: 6,
          shadowColor: Colors.black.withAlpha(50),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withAlpha(80),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.mic_external_on_rounded,
                        color: colorScheme.onSecondaryContainer,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle ??
                                'Select audio input / recording source',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (_devices.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.mic_off_rounded,
                        size: 40,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No microphones found',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _devices.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 64),
                    itemBuilder: (ctx, index) {
                      final device = _devices[index];
                      final isCurrent = device.id == _selectedId;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        leading: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? colorScheme.secondary
                                : colorScheme.surfaceContainerHighest,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getInputIcon(device.type),
                            color: isCurrent
                                ? colorScheme.onSecondary
                                : colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          device.name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: isCurrent
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isCurrent
                                ? colorScheme.secondary
                                : colorScheme.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          device.type.toDisplayString(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: isCurrent
                            ? Icon(
                                Icons.check_circle_rounded,
                                color: colorScheme.secondary,
                                size: 22,
                              )
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedId = device.id;
                          });
                          widget.onSelect(device);
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
