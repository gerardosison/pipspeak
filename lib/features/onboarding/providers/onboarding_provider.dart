import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/account_providers.dart';

String languageCode(String language) {
  final value = language.toLowerCase().trim();
  if (value.startsWith('fil') || value.startsWith('tl')) return 'fil-PH';
  if (value.startsWith('spanish') || value.startsWith('es')) return 'es-ES';
  if (value.startsWith('french') || value.startsWith('fr')) return 'fr-FR';
  if (value.startsWith('german') || value.startsWith('de')) return 'de-DE';
  if (value.startsWith('japanese') || value.startsWith('ja')) return 'ja-JP';
  if (value.contains('uk') || value == 'en-gb') return 'en-GB';
  return 'en-US';
}

/// Practice preferences belong to the retained account, not a global demo user.
final StateProvider<String> selectedLanguageProvider = StateProvider<String>((
  ref,
) {
  final uid = ref.watch(currentUidProvider);
  final profile = ref.read(localProfileProvider).valueOrNull;
  ref.listen(localProfileProvider, (previous, next) {
    final value = next.valueOrNull;
    if (value?.userId == uid &&
        value?.language != previous?.valueOrNull?.language) {
      ref.read(selectedLanguageProvider.notifier).state = languageCode(
        value!.language,
      );
    }
  });
  return profile?.userId == uid && profile != null
      ? languageCode(profile.language)
      : 'en-US';
});

final StateProvider<String> selectedGoalProvider = StateProvider<String>((ref) {
  final uid = ref.watch(currentUidProvider);
  final profile = ref.read(localProfileProvider).valueOrNull;
  ref.listen(localProfileProvider, (previous, next) {
    final value = next.valueOrNull;
    if (value?.userId == uid &&
        value?.practicePurpose != previous?.valueOrNull?.practicePurpose) {
      ref.read(selectedGoalProvider.notifier).state = value!.practicePurpose;
    }
  });
  return profile?.userId == uid && profile != null
      ? profile.practicePurpose
      : 'Class Presentation';
});
