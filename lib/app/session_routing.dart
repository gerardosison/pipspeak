/// Startup routing depends on retained identity and local profile, not internet.
String? sessionRedirect({
  required String location,
  required bool authLoading,
  required bool authFailed,
  required bool signedIn,
  required bool profileLoading,
  required bool profileFailed,
  required bool onboardingComplete,
  bool profileMissing = false,
}) {
  const startup = '/startup';
  const public = {'/login', '/register', '/forgot-password'};
  if (authLoading || authFailed) return location == startup ? null : startup;
  if (!signedIn) return public.contains(location) ? null : '/login';
  // Registration must finish saving its new profile. All other signed-in flows
  // wait for a confirmed profile instead of treating a failed download as new.
  if (profileMissing && location != '/register') {
    return location == startup ? null : startup;
  }
  if (location != startup) return null;
  if (profileLoading || profileFailed) return null;
  return onboardingComplete ? '/home' : '/splash';
}
