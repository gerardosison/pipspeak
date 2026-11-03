import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/app_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/pip_misc.dart';

class PersonalizationScreen extends ConsumerStatefulWidget {
  const PersonalizationScreen({super.key, this.initialStep = 0});

  final int initialStep;

  @override
  ConsumerState<PersonalizationScreen> createState() =>
      _PersonalizationScreenState();
}

class _PersonalizationScreenState extends ConsumerState<PersonalizationScreen> {
  late int _page;

  @override
  void initState() {
    super.initState();
    _page = widget.initialStep.clamp(0, 1).toInt();
  }

  // Page 1: Language selection (with Flag Icon & Flag Name)
  String _selectedLanguage = '🇺🇸 English (US)';

  final List<_LanguageOption> _languages = const [
    _LanguageOption(flag: '🇺🇸', name: 'English (US)', code: 'en-US'),
    _LanguageOption(flag: '🇬🇧', name: 'English (UK)', code: 'en-GB'),
    _LanguageOption(flag: '🇵🇭', name: 'Filipino (Tagalog)', code: 'fil-PH'),
    _LanguageOption(flag: '🇪🇸', name: 'Spanish (Español)', code: 'es-ES'),
    _LanguageOption(flag: '🇫🇷', name: 'French (Français)', code: 'fr-FR'),
    _LanguageOption(flag: '🇩🇪', name: 'German (Deutsch)', code: 'de-DE'),
    _LanguageOption(flag: '🇯🇵', name: 'Japanese (日本語)', code: 'ja-JP'),
  ];

  // Page 2: What are you practicing for (select all that apply)
  final Set<String> _selectedPractices = {'Public Speaking'};

  final List<String> _practiceOptions = const [
    'Public Speaking',
    'Recitation',
    'Presentation',
    'Debate',
    'Others',
  ];

  void _next() {
    if (_page == 0) {
      setState(() => _page = 1);
    } else {
      if (_selectedPractices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please select at least one practice goal to continue.',
            ),
            backgroundColor: AppColors.coral,
          ),
        );
        return;
      }
      _finish();
    }
  }

  /// Saves preferences locally (synced later) and opens Home.
  Future<void> _finish() async {
    final uid = ref.read(currentUidProvider);
    if (uid != null) {
      final repo = ref.read(profileRepositoryProvider);
      final profile = await repo.get(uid);
      final language = _languages.firstWhere(
        (l) => '${l.flag} ${l.name}' == _selectedLanguage,
        orElse: () => _languages.first,
      );
      ref.read(selectedLanguageProvider.notifier).state = language.code;
      await repo.save(
        userId: uid,
        fullName: profile?.fullName ?? 'Speaker',
        nickname: profile?.nickname ?? '',
        language: language.name,
        practicePurpose: _practiceOptions
            .where(_selectedPractices.contains)
            .join(', '),
        onboardingComplete: true,
      );
    }
    if (mounted) context.go(AppRoutes.home);
  }

  void _previous() {
    if (_page > 0) {
      setState(() => _page = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLanguagePage = _page == 0;

    return Scaffold(
      appBar: pipAppBar(
        context,
        title: 'Preference ${_page + 1} of 2',
        showBack: _page > 0,
        onBack: _previous,
        actions: [TextButton(onPressed: _finish, child: const Text('Skip'))],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Progress Bar
              Row(
                children: List.generate(
                  2,
                  (index) => Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: 6,
                      margin: EdgeInsets.only(right: index == 1 ? 0 : 8),
                      decoration: BoxDecoration(
                        color: index <= _page ? AppColors.blue : AppColors.line,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Page Title & Subtitle
                      Text(
                        isLanguagePage
                            ? 'What language would you like to use?'
                            : 'What are you practicing for? (Select all that apply)',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(letterSpacing: -0.5, height: 1.25),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isLanguagePage
                            ? 'Select your preferred language with flag icon & flag name.'
                            : 'Choose all speaking formats relevant to your goals from the dropdown.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.secondaryText(context),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // PAGE 1: Select Language (with Flag Icon & Flag Name) - Dropdown
                      if (isLanguagePage) ...[
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedLanguage,
                          decoration: const InputDecoration(
                            labelText: 'Language',
                            prefixIcon: Icon(Icons.language_rounded),
                          ),
                          items: _languages.map((lang) {
                            final display = '${lang.flag} ${lang.name}';
                            return DropdownMenuItem<String>(
                              value: display,
                              child: Row(
                                children: [
                                  Text(
                                    lang.flag,
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    lang.name,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedLanguage = val);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.sky,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                color: AppColors.navy,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'You can modify this anytime in Settings.',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.navy,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 36),
                      ]
                      // PAGE 2: What are you practicing for (select all that apply) - Dropdown
                      else ...[
                        const SizedBox(height: 8),
                        ..._practiceOptions.map((option) {
                          final isSelected = _selectedPractices.contains(
                            option,
                          );
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: isSelected
                                    ? AppColors.blue
                                    : AppColors.line,
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            color: isSelected ? AppColors.sky : Colors.white,
                            child: CheckboxListTile(
                              value: isSelected,
                              onChanged: (selected) {
                                setState(() {
                                  if (selected == true) {
                                    _selectedPractices.add(option);
                                  } else {
                                    _selectedPractices.remove(option);
                                  }
                                });
                              },
                              title: Text(
                                option,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? AppColors.navy
                                      : AppColors.primaryText(context),
                                ),
                              ),
                              activeColor: AppColors.blue,
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                          );
                        }),
                        const SizedBox(height: 20),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Bottom-anchored action for the active preference page.
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _next,
                  child: Text(
                    isLanguagePage ? 'Continue' : 'Build my personalized plan',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
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
}

class _LanguageOption {
  const _LanguageOption({
    required this.flag,
    required this.name,
    required this.code,
  });

  final String flag;
  final String name;
  final String code;
}
