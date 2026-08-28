import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audio_output_picker/audio_output_picker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audio & Mic Stream Picker',
      debugShowCheckedModeBanner: kDebugMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const AudioPickerHomeScreen(),
    );
  }
}

class AudioPickerHomeScreen extends StatefulWidget {
  const AudioPickerHomeScreen({super.key});

  @override
  State<AudioPickerHomeScreen> createState() => _AudioPickerHomeScreenState();
}

class _AudioPickerHomeScreenState extends State<AudioPickerHomeScreen> {
  final _picker = AudioOutputPicker();
  final _audioPlayer = AudioPlayer();

  String _platformVersion = 'Unknown';
  bool _hasBtPermission = false;
  bool _hasMicPermission = false;

  // Active devices
  AudioOutputDevice? _currentOutput;
  AudioInputDevice? _currentMic;

  // Real-time stream subscriptions
  StreamSubscription<AudioOutputDevice?>? _currentOutputSub;
  StreamSubscription<AudioInputDevice?>? _currentMicSub;

  // Audio player state
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  late final StreamSubscription<PlayerState> _stateSub;
  late final StreamSubscription<Duration> _durationSub;
  late final StreamSubscription<Duration> _positionSub;

  @override
  void initState() {
    super.initState();
    _initPlatformAndPermissions();
    _initAudioPlayer();
    _initDeviceStreams();
  }

  void _initAudioPlayer() {
    _stateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });

    _durationSub = _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) setState(() => _duration = duration);
    });

    _positionSub = _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) setState(() => _position = position);
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playerState = PlayerState.stopped;
          _position = Duration.zero;
        });
      }
    });

    _audioPlayer.setSource(AssetSource('sound/zense.mp3')).catchError((e) {
      debugPrint('Error loading asset audio: $e');
    });
  }

  Future<void> _initPlatformAndPermissions() async {
    String platformVersion;
    try {
      platformVersion =
          await _picker.getPlatformVersion() ?? 'Unknown platform';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    final hasBt = await _picker.checkBluetoothPermission();
    final hasMic = await _picker.checkMicrophonePermission();

    if (!mounted) return;
    setState(() {
      _platformVersion = platformVersion;
      _hasBtPermission = hasBt;
      _hasMicPermission = hasMic;
    });
  }

  void _initDeviceStreams() {
    _currentOutputSub = _picker.onCurrentOutputChanged.listen((device) {
      if (mounted) setState(() => _currentOutput = device);
    });

    _currentMicSub = _picker.onCurrentMicrophoneChanged.listen((mic) {
      if (mounted) setState(() => _currentMic = mic);
    });
  }

  Future<void> _togglePlayPause() async {
    if (_playerState == PlayerState.playing) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(AssetSource('sound/zense.mp3'));
    }
  }

  Future<void> _stopAudio() async {
    await _audioPlayer.stop();
    setState(() => _position = Duration.zero);
  }

  Future<void> _requestBtPermission() async {
    final granted = await _picker.requestBluetoothPermission();
    if (!mounted) return;
    setState(() => _hasBtPermission = granted);
  }

  Future<void> _requestMicPermission() async {
    final granted = await _picker.requestMicrophonePermission();
    if (!mounted) return;
    setState(() => _hasMicPermission = granted);
  }

  Future<void> _openOutputPicker() async {
    final selected = await _picker.showAudioOutputPickerPopup(
      context: context,
      title: 'Audio Output',
      subtitle: 'Choose speaker, headphones, or Bluetooth output',
    );

    if (selected != null && mounted) {
      setState(() => _currentOutput = selected);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switched output to: ${selected.name}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _openMicrophonePicker() async {
    final selected = await _picker.showMicrophonePickerPopup(
      context: context,
      title: 'Microphone Input',
      subtitle: 'Choose recording / input source',
    );

    if (selected != null && mounted) {
      setState(() => _currentMic = selected);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switched microphone to: ${selected.name}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  IconData _getOutputIcon(AudioOutputType type) {
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

  IconData _getMicIcon(AudioInputType type) {
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

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _stateSub.cancel();
    _durationSub.cancel();
    _positionSub.cancel();
    _currentOutputSub?.cancel();
    _currentMicSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isPlaying = _playerState == PlayerState.playing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio & Microphone Streams'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Platform & Permissions
            _buildSystemBanner(theme, colorScheme),
            const SizedBox(height: 20),

            // 1. Audio Output Section (Headphones, Speaker, Bluetooth)
            _buildOutputSectionHeader(theme, colorScheme),
            const SizedBox(height: 12),
            _buildActiveOutputCard(theme, colorScheme),
            const SizedBox(height: 12),
            _buildOutputStreamView(theme, colorScheme),
            const SizedBox(height: 24),

            // 2. Microphone Section (Listenable Microphones)
            _buildMicrophoneSectionHeader(theme, colorScheme),
            const SizedBox(height: 12),
            _buildActiveMicrophoneCard(theme, colorScheme),
            const SizedBox(height: 12),
            _buildMicrophoneStreamView(theme, colorScheme),
            const SizedBox(height: 24),

            // 3. Audio Player Test
            _buildPlayerCard(theme, colorScheme, isPlaying),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemBanner(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(120),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.device_hub_rounded,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _platformVersion,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                _hasBtPermission
                    ? Icons.bluetooth_connected_rounded
                    : Icons.bluetooth_disabled_rounded,
                size: 16,
                color: _hasBtPermission ? Colors.green : colorScheme.error,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _hasBtPermission
                      ? 'Bluetooth OK'
                      : 'Bluetooth Permission Needed',
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!_hasBtPermission)
                TextButton(
                  onPressed: _requestBtPermission,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('Grant BT'),
                ),
            ],
          ),
          Row(
            children: [
              Icon(
                _hasMicPermission ? Icons.mic_rounded : Icons.mic_off_rounded,
                size: 16,
                color: _hasMicPermission ? Colors.green : colorScheme.error,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _hasMicPermission ? 'Microphone OK' : 'Mic Permission Needed',
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!_hasMicPermission)
                TextButton(
                  onPressed: _requestMicPermission,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('Grant Mic'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // Audio Outputs (Speaker, Headphones, Bluetooth)
  // ==========================================

  Widget _buildOutputSectionHeader(ThemeData theme, ColorScheme colorScheme) {
    return Row(
      children: [
        Icon(Icons.headphones_rounded, size: 20, color: colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'AUDIO OUTPUT STREAM',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: colorScheme.primary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: colorScheme.primary.withAlpha(25),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                'Always Live',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveOutputCard(ThemeData theme, ColorScheme colorScheme) {
    final current = _currentOutput;
    final deviceType = current?.type ?? AudioOutputType.speaker;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.primaryContainer.withAlpha(160),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getOutputIcon(deviceType),
                  color: colorScheme.onPrimary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACTIVE OUTPUT',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onPrimaryContainer.withAlpha(180),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      current?.name ?? 'Detecting Output...',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      deviceType.toDisplayString(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onPrimaryContainer.withAlpha(200),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _openOutputPicker,
            icon: const Icon(Icons.swap_horiz_rounded, size: 20),
            label: const Text(
              'Change Audio Output',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              minimumSize: const Size.fromHeight(44),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutputStreamView(ThemeData theme, ColorScheme colorScheme) {
    return StreamBuilder<List<AudioOutputDevice>>(
      stream: _picker.onOutputsChanged,
      builder: (context, snapshot) {
        final devices = snapshot.data ?? [];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colorScheme.outlineVariant.withAlpha(90)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.sensors_rounded,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Available Outputs Stream (${devices.length})',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (devices.isEmpty)
                Text(
                  'No output devices detected.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: devices.map((d) {
                    final isSelected = _currentOutput != null
                        ? d.id == _currentOutput?.id
                        : d.isSelected;
                    return InkWell(
                      onTap: () async {
                        await _picker.selectOutput(d);
                        setState(() => _currentOutput = d);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colorScheme.primaryContainer
                              : colorScheme.surfaceContainerHighest.withAlpha(
                                  120,
                                ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.outlineVariant.withAlpha(80),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getOutputIcon(d.type),
                              size: 16,
                              color: isSelected
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                d.name,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? colorScheme.onPrimaryContainer
                                      : colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: colorScheme.primary,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // Audio Inputs / Microphones
  // ==========================================

  Widget _buildMicrophoneSectionHeader(
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Row(
      children: [
        Icon(Icons.mic_rounded, size: 20, color: colorScheme.secondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'MICROPHONE & INPUT STREAM',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: colorScheme.secondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: colorScheme.secondary.withAlpha(25),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                'Always Live',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.secondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveMicrophoneCard(ThemeData theme, ColorScheme colorScheme) {
    final current = _currentMic;
    final micType = current?.type ?? AudioInputType.builtInMic;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.secondaryContainer,
            colorScheme.secondaryContainer.withAlpha(160),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.secondary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getMicIcon(micType),
                  color: colorScheme.onSecondary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACTIVE MICROPHONE',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSecondaryContainer.withAlpha(180),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      current?.name ?? 'Detecting Microphone...',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      micType.toDisplayString(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSecondaryContainer.withAlpha(200),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _openMicrophonePicker,
            icon: const Icon(Icons.mic_external_on_rounded, size: 20),
            label: const Text(
              'Change Microphone Input',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.secondary,
              foregroundColor: colorScheme.onSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              minimumSize: const Size.fromHeight(44),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicrophoneStreamView(ThemeData theme, ColorScheme colorScheme) {
    return StreamBuilder<List<AudioInputDevice>>(
      stream: _picker.onMicrophonesChanged,
      builder: (context, snapshot) {
        final mics = snapshot.data ?? [];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colorScheme.outlineVariant.withAlpha(90)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.hearing_rounded,
                    size: 16,
                    color: colorScheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Listenable Microphones Stream (${mics.length})',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (mics.isEmpty)
                Text(
                  'No microphones detected.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: mics.map((m) {
                    final isSelected = _currentMic != null
                        ? m.id == _currentMic?.id
                        : m.isSelected;
                    return InkWell(
                      onTap: () async {
                        await _picker.selectInput(m);
                        setState(() => _currentMic = m);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colorScheme.secondaryContainer
                              : colorScheme.surfaceContainerHighest.withAlpha(
                                  120,
                                ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? colorScheme.secondary
                                : colorScheme.outlineVariant.withAlpha(80),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getMicIcon(m.type),
                              size: 16,
                              color: isSelected
                                  ? colorScheme.secondary
                                  : colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                m.name,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? colorScheme.onSecondaryContainer
                                      : colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: colorScheme.secondary,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // Audio Player Test
  // ==========================================

  Widget _buildPlayerCard(
    ThemeData theme,
    ColorScheme colorScheme,
    bool isPlaying,
  ) {
    final maxDuration = _duration.inMilliseconds.toDouble();
    final currentPos = _position.inMilliseconds.toDouble().clamp(
      0.0,
      maxDuration > 0 ? maxDuration : 1.0,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(100)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.music_note_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'zense.mp3',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'assets/sound/',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSecondaryContainer,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isPlaying)
                          Row(
                            children: [
                              Icon(
                                Icons.graphic_eq_rounded,
                                size: 16,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Playing',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: currentPos,
              max: maxDuration > 0 ? maxDuration : 1.0,
              onChanged: (value) {
                _audioPlayer.seek(Duration(milliseconds: value.toInt()));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(_position),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  _formatDuration(_duration),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.outlined(
                tooltip: 'Replay',
                icon: const Icon(Icons.replay_rounded),
                onPressed: () async {
                  await _audioPlayer.seek(Duration.zero);
                  await _audioPlayer.play(AssetSource('sound/zense.mp3'));
                },
              ),
              const SizedBox(width: 16),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.primary,
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withAlpha(70),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: IconButton(
                  iconSize: 36,
                  tooltip: isPlaying ? 'Pause' : 'Play',
                  color: colorScheme.onPrimary,
                  icon: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                  onPressed: _togglePlayPause,
                ),
              ),
              const SizedBox(width: 16),
              IconButton.outlined(
                tooltip: 'Stop',
                icon: const Icon(Icons.stop_rounded),
                onPressed: _stopAudio,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
