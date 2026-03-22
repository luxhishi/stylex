import 'dart:io';

import 'package:flutter/material.dart';

import '../widgets/app_bottom_nav.dart';
import '../widgets/onboarding_shell.dart';

class AddClosetItemScreen extends StatelessWidget {
  const AddClosetItemScreen({
    required this.imagePath,
    super.key,
  });

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: AppViewport(
        child: AppPanel(
          padding: EdgeInsets.zero,
          borderRadius: 0,
          clip: true,
          child: Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFE8F5F2),
                            foregroundColor: const Color(0xFF0A7A76),
                          ),
                          icon: const Icon(Icons.close_rounded),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'STYLEX',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF2C4B4D),
                            letterSpacing: 0.6,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'CAPTURE',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: const Color(0xFF0A7A76),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFFEDC598), Color(0xFFD2A27B)],
                            ),
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 130),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              gradient: const LinearGradient(
                                colors: [Color(0xFFD7F7F2), Color(0xFFF4FBF9)],
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x120A7A76),
                                  blurRadius: 18,
                                  offset: Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xFF0A7A76),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'AUTO-TAGGING IN PROGRESS',
                                      style: theme.textTheme.labelMedium?.copyWith(
                                        color: const Color(0xFF39676A),
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: const LinearProgressIndicator(
                                    minHeight: 6,
                                    value: 0.72,
                                    backgroundColor: Color(0xFFDCEFED),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF6AE9DE),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            height: 520,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(26),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x180A7A76),
                                  blurRadius: 28,
                                  offset: Offset(0, 16),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(26),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.file(
                                    File(imagePath),
                                    fit: BoxFit.cover,
                                  ),
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.white.withValues(alpha: 0.10),
                                          Colors.transparent,
                                          Colors.black.withValues(alpha: 0.20),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 16,
                                    right: 16,
                                    bottom: 18,
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: const [
                                        _MetaChip(label: 'Category:', value: 'Blazer'),
                                        _MetaChip(label: 'Color:', value: 'Ivory'),
                                        _MetaChip(
                                          label: 'Material:',
                                          value: 'Linen Blend',
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: IgnorePointer(
                  ignoring: true,
                  child: StylexBottomNav(
                    selectedTab: AppTab.closet,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '$label ',
                style: const TextStyle(
                  color: Color(0xFF6A7E80),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(
                text: value,
                style: const TextStyle(
                  color: Color(0xFF2A3E40),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
