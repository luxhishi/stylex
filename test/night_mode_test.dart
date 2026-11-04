import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stylex/app/screens/auth_screen.dart';
import 'package:stylex/app/screens/closet_screen.dart';
import 'package:stylex/app/screens/home_screen.dart';
import 'package:stylex/app/screens/outfits_screen.dart';
import 'package:stylex/app/screens/settings_screen.dart';
import 'package:stylex/app/screens/style_preference_screen.dart';
import 'package:stylex/app/widgets/app_appearance.dart';
import 'package:stylex/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-key',
    );
  });

  tearDownAll(() async => Supabase.instance.dispose());

  testWidgets('night colors reduce glare and leave light colors unchanged', (
    tester,
  ) async {
    late BuildContext captured;
    Widget harness(Brightness brightness) => MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Builder(
        builder: (context) {
          captured = context;
          return const NightImage(child: SizedBox(width: 30, height: 30));
        },
      ),
    );
    await tester.pumpWidget(harness(Brightness.light));
    expect(captured.nightSurface(Colors.white), Colors.white);
    expect(captured.nightInk(Colors.black), Colors.black);
    expect(find.byType(ColorFiltered), findsNothing);

    await tester.pumpWidget(harness(Brightness.dark));
    await tester.pumpAndSettle();
    for (final color in [
      Colors.white,
      const Color(0xFFF3F8F7),
      const Color(0xFF6CF4ED),
      const Color(0xFFCAEDFF),
    ]) {
      expect(captured.nightSurface(color).computeLuminance(), lessThan(0.1));
    }
    expect(
      captured.nightInk(Colors.black).computeLuminance(),
      greaterThan(0.5),
    );
    expect(captured.nightInk(Colors.white), isNot(Colors.white));
    expect(captured.nightSurface(Colors.transparent), Colors.transparent);
    expect(find.byType(ColorFiltered), findsNothing);
  });

  for (final entry in <String, Widget>{
    'authentication': const AuthScreen(),
    'home': const HomeScreen(),
    'closet': const ClosetScreen(),
    'outfits': const OutfitsScreen(),
    'settings': const SettingsScreen(),
    'style preferences': const StylePreferenceScreen(),
  }.entries) {
    testWidgets('${entry.key} has no bright card surfaces at night', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      AppAppearance.mode.value = ThemeMode.dark;
      await tester.pumpWidget(const StylexApp());
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(theme: app.darkTheme, home: entry.value),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        final color = text.style?.color;
        if (color == null || color.a < 0.9) continue;
        expect(
          color.computeLuminance(),
          greaterThan(0.12),
          reason: 'Low-contrast text on ${entry.key}: ${text.data}',
        );
      }
      for (final box in tester.widgetList<DecoratedBox>(
        find.byType(DecoratedBox),
      )) {
        final decoration = box.decoration;
        if (decoration is! BoxDecoration) continue;
        final colors = [
          if (decoration.color != null) decoration.color!,
          ...?decoration.gradient?.colors,
        ];
        for (final color in colors.where((c) => c.a > 0.9)) {
          expect(
            color.computeLuminance(),
            lessThan(0.15),
            reason: 'Bright surface on ${entry.key}: $color',
          );
        }
      }
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await render.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '${Directory.systemTemp.path}/stylex-night-${entry.key}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox.shrink());
      AppAppearance.mode.value = ThemeMode.system;
    });
  }
}
