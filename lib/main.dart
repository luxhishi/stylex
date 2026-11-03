import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/config/supabase_config.dart';
import 'app/screens/boot_screen.dart';
import 'app/widgets/app_appearance.dart';
import 'app/widgets/onboarding_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  }

  await AppAppearance.load();
  runApp(const StylexApp());
}

class StylexApp extends StatelessWidget {
  const StylexApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF0B8A84);
    final transitions = PageTransitionsTheme(
      builders: {
        for (final platform in TargetPlatform.values)
          platform: const _StylexPageTransition(),
      },
    );

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppAppearance.mode,
      builder: (context, mode, _) => MaterialApp(
        themeMode: mode,
        darkTheme: ThemeData(
          pageTransitionsTheme: transitions,
          colorScheme: ColorScheme.fromSeed(
            seedColor: seed,
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF101C1C),
        ),
        debugShowCheckedModeBanner: false,
        title: 'Stylex',
        theme: ThemeData(
          pageTransitionsTheme: transitions,
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF3F8F6),
          colorScheme: ColorScheme.fromSeed(
            seedColor: seed,
            brightness: Brightness.light,
          ),
          textTheme: ThemeData.light().textTheme.apply(
                bodyColor: const Color(0xFF2E3B3D),
                displayColor: const Color(0xFF2E3B3D),
              ),
        ),
        home: SupabaseConfig.isConfigured
            ? const BootScreen()
            : const SupabaseSetupScreen(),
      ),
    );
  }
}

class _StylexPageTransition extends PageTransitionsBuilder {
  const _StylexPageTransition();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 260);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;

    final progress = animation.drive(CurveTween(curve: Curves.easeOutCubic));
    return FadeTransition(
      opacity: progress,
      child: SlideTransition(
        position: progress.drive(
          Tween(begin: const Offset(0.035, 0), end: Offset.zero),
        ),
        child: child,
      ),
    );
  }
}

class SupabaseSetupScreen extends StatelessWidget {
  const SupabaseSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppViewport(
        child: AppPanel(
          padding: const EdgeInsets.all(24),
          borderRadius: 0,
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 12),
              Text(
                'Supabase not configured',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Open lib/app/config/supabase_config.dart and replace the placeholder URL and anon key with your Supabase project credentials.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 16),
              SelectableText(
                "url: 'YOUR_SUPABASE_URL'\nanonKey: 'YOUR_SUPABASE_ANON_KEY'",
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF0A7A76),
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
