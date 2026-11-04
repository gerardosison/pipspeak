/// Camera + microphone gate before entering the practice room.
/// Implemented with real OS/browser permission requests.
abstract class PermissionService {
  Future<bool> requestCameraAndMic();
  Future<bool> openSettings();
}
