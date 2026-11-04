import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'permission_service.dart';

/// The camera plugin requests actual OS/browser camera and microphone consent.
class PlatformPermissionService implements PermissionService {
  @override
  Future<bool> requestCameraAndMic() async {
    if (!kIsWeb &&
        defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return false;
    }
    CameraController? camera;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return false;
      camera = CameraController(
        cameras.first,
        ResolutionPreset.low,
        enableAudio: true,
      );
      await camera.initialize();
      return camera.value.isInitialized;
    } on CameraException {
      return false;
    } finally {
      await camera?.dispose();
    }
  }

  @override
  Future<bool> openSettings() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    return await const MethodChannel('pipspeak/settings')
            .invokeMethod<bool>('openAppSettings') ??
        false;
  }
}
