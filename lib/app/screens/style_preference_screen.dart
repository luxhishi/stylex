import 'package:flutter/material.dart';

import 'home_screen.dart';
import '../view_models/style_preference_view_model.dart';
import '../widgets/onboarding_shell.dart';

class StylePreferenceScreen extends StatefulWidget {
  const StylePreferenceScreen({super.key});

  @override
  State<StylePreferenceScreen> createState() => _StylePreferenceScreenState();
}

class _StylePreferenceScreenState extends State<StylePreferenceScreen> {
  String _selectedStyle = 'Minimalist';
  late final StylePreferenceViewModel _viewModel;

  final List<StyleCardData> _styles = const [
    StyleCardData('Minimalist', 'CLEAN & TIMELESS'),
    StyleCardData('Streetwear', 'URBAN & BOLD'),
    StyleCardData('Formal', 'SHARP & ELEGANT'),
    StyleCardData('Bohemian', 'FREE & ARTISTIC'),
    StyleCardData('Classic Vintage', 'RETRO & HERITAGE', wide: true),
  ];

  @override
  void initState() {
    super.initState();
    _viewModel = StylePreferenceViewModel();
  }

  Future<void> _savePreference() async {
    final result = await _viewModel.savePreference(_selectedStyle);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );

    if (!result.success) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const HomeScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
        return Scaffold(
          body: AppViewport(
            child: AppPanel(
              padding: EdgeInsets.zero,
              borderRadius: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Stylex',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0A7A76),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                width: 18,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0A7A76),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          Text(
                            "What's your style\npreference?",
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontSize: 34,
                              fontWeight: FontWeight.w700,
                              height: 1.08,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tell us what moves you. We will curate your digital atelier based on your unique aesthetic.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF6D7A7B),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: _styles.map((style) {
                              return PreferenceTile(
                                data: style,
                                selected: _selectedStyle == style.title,
                                onTap: () {
                                  setState(() {
                                    _selectedStyle = style.title;
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE3EFEC)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed:
                                _viewModel.isSaving ? null : _savePreference,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0A7A76),
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            child: _viewModel.isSaving
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('Next'),
                                      SizedBox(width: 8),
                                      Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: TextButton(
                            onPressed: _viewModel.isSaving ? null : () {},
                            child: const Text(
                              'SKIP FOR NOW',
                              style: TextStyle(
                                letterSpacing: 1.4,
                                color: Color(0xFF7A8788),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
