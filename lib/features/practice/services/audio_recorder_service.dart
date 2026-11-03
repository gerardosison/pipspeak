import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Records mono 16 kHz PCM WAV audio for the bundled offline Whisper model.
class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  int _secondsElapsed = 0;
  Timer? _timer;
  StreamSubscription<Uint8List>? _streamSubscription;
  String? _recordingPath;
  Future<String?>? _stopFuture;
  InputDevice? _selectedDevice;
  bool _monitoringOnly = false;

  bool get isRecording => _isRecording;
  int get secondsElapsed => _secondsElapsed;
  bool get isPaused => _isPaused;
  bool _isPaused = false;

  Future<List<InputDevice>> listInputDevices() =>
      _recorder.listInputDevices();

  Future<bool> requestPermission() {
    // record supports runtime permission checks on mobile, web, and macOS.
    // Windows and Linux use OS/device-level access and don't implement this
    // method; asking there can produce MissingPluginException.
    final permissionCheckSupported = kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.windows &&
            defaultTargetPlatform != TargetPlatform.linux);
    return permissionCheckSupported
        ? _recorder.hasPermission()
        : Future<bool>.value(true);
  }

  Future<double> currentAmplitudeLevel() async {
    if (!_isRecording || _isPaused) return 0;
    try {
      return _normalizeAmplitude((await _recorder.getAmplitude()).current);
    } catch (_) {
      return 0;
    }
  }

  Stream<double> amplitudeLevelStream({
    Duration interval = const Duration(milliseconds: 100),
  }) =>
      _recorder
          .onAmplitudeChanged(interval)
          .map((amplitude) => _normalizeAmplitude(amplitude.current));

  double _normalizeAmplitude(double decibels) {
    if (!decibels.isFinite) return 0;
    return ((decibels + 60) / 60).clamp(0.0, 1.0);
  }

  void selectInputDevice(InputDevice? device) => _selectedDevice = device;

  /// Opens the microphone as a PCM stream for live preview meters without
  /// creating a recording file. This is also supported by the browser backend.
  Future<void> startLevelMonitoring({InputDevice? device}) async {
    if (!await requestPermission()) {
      throw StateError('Microphone permission was not granted.');
    }
    if (_isRecording) await cancelRecording();
    _selectedDevice = device ?? _selectedDevice;
    final audioStream = await _recorder.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        device: device ?? _selectedDevice,
      ),
    );
    // Drain the stream; amplitude events are sampled separately by the UI.
    _streamSubscription = audioStream.listen((_) {});
    _recordingPath = null;
    _secondsElapsed = 0;
    _isRecording = true;
    _isPaused = false;
    _monitoringOnly = true;
  }

  Future<void> startRecording({InputDevice? device}) async {
    if (!await requestPermission()) {
      throw StateError('Microphone permission was not granted.');
    }
    final dir = await getApplicationDocumentsDirectory();
    _recordingPath = p.join(
      dir.path,
      'practice_${DateTime.now().millisecondsSinceEpoch}.wav',
    );
    await _recorder.start(
      RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
        device: device ?? _selectedDevice,
      ),
      path: _recordingPath!,
    );
    _isRecording = true;
    _isPaused = false;
    _monitoringOnly = false;
    _secondsElapsed = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _secondsElapsed++;
    });
  }

  Future<String?> stopAndGetPath() async {
    final activeStop = _stopFuture;
    if (activeStop != null) return activeStop;
    final stop = _stopRecording();
    _stopFuture = stop;
    try {
      return await stop;
    } finally {
      if (identical(_stopFuture, stop)) _stopFuture = null;
    }
  }

  Future<String?> _stopRecording() async {
    _timer?.cancel();
    _timer = null;
    if (!_isRecording) return _recordingPath;
    _isRecording = false;
    _isPaused = false;
    _monitoringOnly = false;
    try {
      final path = await _recorder.stop();
      return path ?? _recordingPath;
    } finally {
      await _streamSubscription?.cancel();
      _streamSubscription = null;
    }
  }

  Future<void> pauseRecording() async {
    if (!_isRecording || _isPaused) return;
    await _recorder.pause();
    _timer?.cancel();
    _timer = null;
    _isPaused = true;
  }

  Future<void> resumeRecording() async {
    if (!_isRecording || !_isPaused) return;
    await _recorder.resume();
    _isPaused = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _secondsElapsed++;
    });
  }

  Future<void> cancelRecording() async {
    _timer?.cancel();
    _timer = null;
    final shouldCancelRecorder = _isRecording;
    _isRecording = false;
    if (shouldCancelRecorder) await _recorder.cancel();
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    _isPaused = false;
    _monitoringOnly = false;
    _recordingPath = null;
    _secondsElapsed = 0;
  }

  Future<void> discardRecording({String? path}) async {
    var pathToDelete = path ?? (_monitoringOnly ? null : _recordingPath);
    final activeStop = _stopFuture;
    if (activeStop != null) {
      pathToDelete ??= await activeStop;
    }
    await cancelRecording();
    if (kIsWeb || pathToDelete == null) return;
    try {
      final recording = File(pathToDelete);
      if (await recording.exists()) await recording.delete();
    } on FileSystemException {
      // A failed cleanup must not turn a user-requested discard into an error.
    }
  }

  Future<int> stopRecording() async {
    final duration = _secondsElapsed;
    await stopAndGetPath();
    _secondsElapsed = 0;
    return duration;
  }

  Future<void> dispose() async {
    _timer?.cancel();
    if (_isRecording) await _recorder.cancel();
    await _streamSubscription?.cancel();
    _isRecording = false;
    _isPaused = false;
    await _recorder.dispose();
  }
}
