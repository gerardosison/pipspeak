import 'package:app_builder_hackathon/app/session_routing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String? route({
    String location = '/startup',
    bool signedIn = true,
    bool loading = false,
    bool failed = false,
    bool profileLoading = false,
    bool profileFailed = false,
    bool profileMissing = false,
    bool complete = true,
  }) => sessionRedirect(
    location: location,
    authLoading: loading,
    authFailed: failed,
    signedIn: signedIn,
    profileLoading: profileLoading,
    profileFailed: profileFailed,
    profileMissing: profileMissing,
    onboardingComplete: complete,
  );
  test('retained complete account opens home without another login', () {
    expect(route(), '/home');
  });
  test('unfinished account resumes onboarding', () {
    expect(route(complete: false), '/splash');
  });
  test('signed-out startup/private routes require login', () {
    expect(route(signedIn: false), '/login');
    expect(route(signedIn: false, location: '/profile'), '/login');
    expect(route(signedIn: false, location: '/register'), isNull);
  });
  test('loading/error never reveals private routes', () {
    expect(route(loading: true, location: '/home'), '/startup');
    expect(route(failed: true, location: '/home'), '/startup');
    expect(route(loading: true), isNull);
    expect(route(profileLoading: true), isNull);
    expect(route(profileFailed: true), isNull);
  });
  test('a missing cached profile waits for cloud recovery, not onboarding', () {
    expect(route(profileMissing: true, complete: false), isNull);
    expect(route(location: '/home', profileMissing: true), '/startup');
    expect(route(location: '/splash', profileMissing: true), '/startup');
  });
  test('registration can finish after Firebase creates its account', () {
    expect(route(location: '/register', complete: false), isNull);
    expect(
      route(location: '/register', complete: false, profileMissing: true),
      isNull,
    );
  });
}
