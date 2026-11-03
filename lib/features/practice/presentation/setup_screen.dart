import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:record/record.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/pip_misc.dart';
import '../services/audio_recorder_service.dart';
import '../services/camera_platform_support.dart';
import 'practice_screen.dart';
import 'widgets/camera_preview.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({
    super.key,
    this.speechTopic = 'Tell a story in 60 seconds',
    this.showBack = false,
  });

  final String speechTopic;
  final bool showBack;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  bool _isCameraOn = true;
  bool _isMicOn = true;
  bool _cameraWorking = false;
  bool _micWorking = false;
  bool _isRefreshingDevices = false;
  double _micLevel = 0;
  StreamSubscription<double>? _micLevelSubscription;
  List<CameraDescription> _cameras = const [];
  List<InputDevice> _microphones = const [];
  String? _selectedCamera;
  String? _selectedMicrophone;
  CameraController? _cameraController;
  final AudioRecorderService _audioMonitor = AudioRecorderService();

  @override
  void initState() {
    super.initState();
    unawaited(_initializeCamera());
    unawaited(_initializeMicrophone());
  }

  @override
  void dispose() {
    unawaited(_micLevelSubscription?.cancel());
    unawaited(_disposeAudioMonitor());
    unawaited(_cameraController?.dispose());
    super.dispose();
  }

  Future<void> _disposeAudioMonitor() async {
    await _audioMonitor.cancelRecording();
    await _audioMonitor.dispose();
  }

  Future<void> _initializeCamera() async {
    if (!cameraPluginSupportedOnCurrentPlatform) {
      if (!mounted) return;
      setState(() {
        _cameras = const [];
        _selectedCamera = null;
        _isCameraOn = false;
        _cameraWorking = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(cameraPluginUnavailableMessage)),
      );
      return;
    }
    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) {
        setState(() {
          _cameras = cameras;
          _isCameraOn = false;
          _cameraWorking = false;
        });
        return;
      }
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      setState(() {
        _cameras = cameras;
        _selectedCamera = camera.name;
      });
      await _openCamera(camera);
    } on CameraException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _cameraWorking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Camera unavailable: ${error.description ?? error.code}',
          ),
        ),
      );
    } on MissingPluginException {
      if (!mounted) return;
      setState(() {
        _cameras = const [];
        _selectedCamera = null;
        _isCameraOn = false;
        _cameraWorking = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(cameraPluginUnavailableMessage)),
      );
    }
  }

  Future<void> _openCamera(CameraDescription camera) async {
    final previous = _cameraController;
    _cameraController = null;
    if (mounted) setState(() => _cameraWorking = false);
    await previous?.dispose();
    if (!_isCameraOn) return;

    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _cameraWorking = controller.value.isInitialized;
      });
    } on CameraException {
      await controller.dispose();
      rethrow;
    }
  }

  Future<void> _initializeMicrophone() async {
    try {
      final permitted = await _audioMonitor.requestPermission();
      final devices = await _audioMonitor.listInputDevices();
      if (!mounted) return;
      setState(() {
        _microphones = devices;
        _selectedMicrophone = devices.isEmpty ? null : devices.first.id;
        _isMicOn = permitted;
      });
      if (permitted) await _startMicrophonePreview();
    } catch (error) {
      if (mounted) {
        setState(() {
          _isMicOn = false;
          _micWorking = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Microphone unavailable: $error')),
        );
      }
    }
  }

  Future<void> _startMicrophonePreview() async {
    final matching = _microphones.where(
      (item) => item.id == _selectedMicrophone,
    );
    final device = matching.isEmpty ? null : matching.first;
    _audioMonitor.selectInputDevice(device);
    if (!_audioMonitor.isRecording) {
      if (kIsWeb) {
        await _audioMonitor.startLevelMonitoring(device: device);
      } else {
        await _audioMonitor.startRecording(device: device);
      }
    }
    if (mounted) {
      setState(() => _micWorking = _audioMonitor.isRecording);
      await _micLevelSubscription?.cancel();
      _micLevelSubscription = _audioMonitor
          .amplitudeLevelStream()
          .listen((level) {
            if (mounted && _isMicOn) setState(() => _micLevel = level);
          });
    }
  }

  Future<void> _toggleMicrophone(bool enabled) async {
    if (!enabled) {
      await _micLevelSubscription?.cancel();
      _micLevelSubscription = null;
      await _audioMonitor.cancelRecording();
      if (mounted) {
        setState(() {
          _isMicOn = false;
          _micWorking = false;
          _micLevel = 0;
        });
      }
      return;
    }
    try {
      await _audioMonitor.requestPermission();
      await _startMicrophonePreview();
      if (mounted) setState(() => _isMicOn = _micWorking);
    } catch (error) {
      if (mounted) {
        setState(() {
          _isMicOn = false;
          _micWorking = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start microphone: $error')),
        );
      }
    }
  }

  Future<void> _toggleCamera(bool enabled) async {
    if (!mounted) return;
    setState(() => _isCameraOn = enabled);
    final matching = _cameras.where(
      (item) => item.name == _selectedCamera,
    );
    final camera = matching.isEmpty ? null : matching.first;
    if (!enabled || camera == null) {
      final controller = _cameraController;
      _cameraController = null;
      setState(() => _cameraWorking = false);
      await controller?.dispose();
      return;
    }
    try {
      await _openCamera(camera);
    } catch (error) {
      if (mounted) {
        setState(() {
          _isCameraOn = false;
          _cameraWorking = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start camera: $error')),
        );
      }
    }
  }

  Future<void> _selectCamera(String? name) async {
    if (name == null) return;
    final camera = _cameras.firstWhere((item) => item.name == name);
    setState(() => _selectedCamera = name);
    if (!_isCameraOn) return;
    try {
      await _openCamera(camera);
    } catch (error) {
      if (mounted) {
        setState(() {
          _isCameraOn = false;
          _cameraWorking = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not switch camera: $error')),
        );
      }
    }
  }

  Future<void> _selectMicrophone(String? id) async {
    if (id == null) return;
    await _micLevelSubscription?.cancel();
    _micLevelSubscription = null;
    await _audioMonitor.cancelRecording();
    if (!mounted) return;
    setState(() {
      _selectedMicrophone = id;
      _micWorking = false;
    });
    if (_isMicOn) {
      try {
        await _startMicrophonePreview();
      } catch (error) {
        if (mounted) {
          setState(() {
            _isMicOn = false;
            _micWorking = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not switch microphone: $error')),
          );
        }
      }
    }
  }

  Future<void> _refreshConnectedDevices() async {
    if (_isRefreshingDevices) return;
    setState(() => _isRefreshingDevices = true);
    final previousCamera = _selectedCamera;
    final previousMicrophone = _selectedMicrophone;
    try {
      final cameras = cameraPluginSupportedOnCurrentPlatform
          ? await availableCameras()
          : const <CameraDescription>[];
      final microphones = await _audioMonitor.listInputDevices();
      if (!mounted) return;

      final camera = _firstOrNull(
            cameras.where((item) => item.name == previousCamera),
          ) ??
          _firstOrNull(
            cameras.where(
              (item) => item.lensDirection == CameraLensDirection.front,
            ),
          ) ??
          _firstOrNull(cameras);
      final matchingMicrophones =
          microphones.where((item) => item.id == previousMicrophone);
      final microphone = matchingMicrophones.isNotEmpty
          ? matchingMicrophones.first
          : (microphones.isEmpty ? null : microphones.first);
      setState(() {
        _cameras = cameras;
        _microphones = microphones;
        _selectedCamera = camera?.name;
        _selectedMicrophone = microphone?.id;
      });

      if (_isCameraOn) {
        if (camera == null) {
          final controller = _cameraController;
          _cameraController = null;
          setState(() {
            _isCameraOn = false;
            _cameraWorking = false;
          });
          await controller?.dispose();
        } else if (camera.name != previousCamera ||
            _cameraController?.value.isInitialized != true) {
          await _openCamera(camera);
        }
      }

      if (_isMicOn) {
        if (microphone == null) {
          await _micLevelSubscription?.cancel();
          _micLevelSubscription = null;
          await _audioMonitor.cancelRecording();
          setState(() {
            _isMicOn = false;
            _micWorking = false;
            _micLevel = 0;
          });
        } else if (microphone.id != previousMicrophone ||
            !_audioMonitor.isRecording) {
          await _micLevelSubscription?.cancel();
          _micLevelSubscription = null;
          await _audioMonitor.cancelRecording();
          await _startMicrophonePreview();
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is MissingPluginException
                ? cameraPluginUnavailableMessage
                : 'Could not refresh connected devices: $error',
          ),
        ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshingDevices = false);
    }
  }

  Future<void> _proceedToCountdown() async {
    await _micLevelSubscription?.cancel();
    _micLevelSubscription = null;
    await _audioMonitor.cancelRecording();
    await _cameraController?.dispose();
    _cameraController = null;
    if (!mounted) return;
    setState(() => _cameraWorking = false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PracticeScreen(
          speechTopic: widget.speechTopic,
          isCameraInitiallyOn: _isCameraOn,
          isMicInitiallyOn: _isMicOn,
          cameraName: _selectedCamera,
          microphoneDeviceId: _selectedMicrophone,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pipAppBar(
        context,
        title: 'Practice Setup',
        showBack: widget.showBack,
        onBack: widget.showBack ? () => context.pop() : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Step 1: Video & Mic Setup',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.blue,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Check your framing and audio before going live',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),
                  PipResponsiveGrid(
                    minItemWidth: 440,
                    maxColumns: 2,
                    spacing: 18,
                    runSpacing: 18,
                    children: [
                      CameraPreviewWidget(
                        isCameraOn: _isCameraOn,
                        isMicOn: _isMicOn,
                        cameraWorking: _cameraWorking,
                        micWorking: _micWorking,
                        micLevel: _micLevel,
                        controller: _cameraController,
                        onToggleCamera: (val) => unawaited(_toggleCamera(val)),
                        onToggleMic: (val) => unawaited(_toggleMicrophone(val)),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Connected devices',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip:
                                          'Refresh connected audio and video devices',
                                      onPressed: _isRefreshingDevices
                                          ? null
                                          : _refreshConnectedDevices,
                                      icon: _isRefreshingDevices
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.refresh_rounded),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.camera_alt_outlined,
                                      color: AppColors.blue,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _selectedCamera,
                                          isExpanded: true,
                                          hint: Text(
                                            cameraPluginSupportedOnCurrentPlatform
                                                ? 'No connected camera found'
                                                : 'Camera unavailable on this platform',
                                          ),
                                          items: _cameras
                                              .map((camera) =>
                                                  DropdownMenuItem<String>(
                                                    value: camera.name,
                                                    child: Text(
                                                      _cameraLabel(camera),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ))
                                              .toList(),
                                          onChanged: _selectCamera,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(
                                  height: 20,
                                  color: AppColors.line,
                                ),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.mic_none_rounded,
                                      color: AppColors.blue,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _selectedMicrophone,
                                          isExpanded: true,
                                          hint: const Text('No microphone found'),
                                          items: _microphones
                                              .map((device) =>
                                                  DropdownMenuItem<String>(
                                                    value: device.id,
                                                    child: Text(
                                                      device.label,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ))
                                              .toList(),
                                          onChanged: _selectMicrophone,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.paper,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PRE-SPEECH CHECKLIST',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.secondaryText(context),
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const _ChecklistItem(
                                  text:
                                      'Keep your device at eye level for confident contact',
                                ),
                                const SizedBox(height: 6),
                                const _ChecklistItem(
                                  text:
                                      'Speak in a quiet space with minimal background echo',
                                ),
                                const SizedBox(height: 6),
                                const _ChecklistItem(
                                  text:
                                      '10-second countdown gives you time to breathe and focus',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: !kIsWeb &&
                                  ((_isCameraOn && _cameraWorking) ||
                                      (_isMicOn && _micWorking))
                              ? _proceedToCountdown
                              : null,
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const Text(
                            'Proceed to Countdown',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (kIsWeb ||
                      !((_isCameraOn && _cameraWorking) ||
                          (_isMicOn && _micWorking)))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        kIsWeb
                            ? 'Camera and microphone previews work in this browser. Offline speech analysis currently requires the Android app.'
                            : 'Turn on an available camera or microphone to continue.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.secondaryText(context),
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  String _cameraLabel(CameraDescription camera) {
    final direction = switch (camera.lensDirection) {
      CameraLensDirection.front => 'Front camera',
      CameraLensDirection.back => 'Back camera',
      CameraLensDirection.external => 'External camera',
    };
    return '$direction · ${camera.name}';
  }
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_rounded, size: 16, color: Colors.green),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.primaryText(context),
            ),
          ),
        ),
      ],
    );
  }
}

T? _firstOrNull<T>(Iterable<T> items) =>
    items.isEmpty ? null : items.first;
