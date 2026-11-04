import '../../permissions/permission_service.dart';

/// TODO(backend): replace with a real permissions plugin
/// (permission_handler). Always grants today — flip `granted` to false
/// to demo the denied state.
class MockPermissionService implements PermissionService {
  bool granted = false;
  @override
  Future<bool> openSettings() async => false;

  @override
  Future<bool> requestCameraAndMic() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    granted = true;
    return granted;
  }
}
