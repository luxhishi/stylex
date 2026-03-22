import 'dart:async';

import 'package:flutter/material.dart';

import 'home_screen.dart';
import '../view_models/auth_view_model.dart';
import 'auth_screen.dart';
import 'style_preference_screen.dart';
import '../widgets/onboarding_shell.dart';

class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  Timer? _timer;
  late final AuthViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = AuthViewModel();
    _timer = Timer(const Duration(seconds: 2), _navigateFromBoot);
  }

  Future<void> _navigateFromBoot() async {
    final destination = await _viewModel.resolveDestination();
    if (!mounted) return;

    final Widget page = switch (destination) {
      AuthDestination.auth => const AuthScreen(),
      AuthDestination.stylePreference => const StylePreferenceScreen(),
      AuthDestination.home => const HomeScreen(),
    };

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: AppViewport(
        child: AppPanel(
          borderRadius: 0,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Stylex',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w300,
                    letterSpacing: -1.2,
                    color: Color(0xFF9EEDE8),
                  ),
                ),
                SizedBox(height: 16),
                SizedBox(
                  width: 110,
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    backgroundColor: Color(0xFFE5F3F1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF56DDD5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
