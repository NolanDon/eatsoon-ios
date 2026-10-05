import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eatsoon/experience/experience_content.dart';
import 'package:eatsoon/experience/experience_preferences.dart';
import 'package:eatsoon/experience/experience_widgets.dart';
import 'package:eatsoon/experience/review_service.dart';
import 'package:eatsoon/theme.dart';
void main() {
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ExperiencePreferences.initialize();
    prefs = ExperiencePreferences.instance.store!;
    await ExperiencePreferences.instance.setFlag('haptics', false);
  });
  test('review eligibility requires time, actual use, cooldown, and consent', () {
    final now = DateTime(2026, 10, 5);
    bool eligible({int actions = 5, int age = 7, int? lastDays, bool enabled = true}) =>
      ReviewPolicy.eligible(now: now, firstUse: now.subtract(Duration(days: age)),
        lastRequest: lastDays == null ? null : now.subtract(Duration(days: lastDays)),
        actions: actions, enabled: enabled);
    expect(eligible(), isTrue);
    expect(eligible(age: 6), isFalse);
    expect(eligible(actions: 4), isFalse);
    expect(eligible(lastDays: 119), isFalse);
    expect(eligible(lastDays: 120), isTrue);
    expect(eligible(enabled: false), isFalse);
  });
  testWidgets('setup selection persists and works with large text on a small screen', (tester) async {
    tester.view.physicalSize = const Size(390, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope( child: MaterialApp(theme: eatSoonTheme(),
      home: const MediaQuery(data: MediaQueryData(size: Size(390,740), textScaler: TextScaler.linear(2)),
        child: Scaffold(body: SafeArea(child: ExperienceOnboardingPage(setup: true)))))));
    await tester.pumpAndSettle();
    final choice = preferenceOptions.entries.firstWhere((e) => e.key != preferenceDefault);
    await tester.ensureVisible(find.text(choice.value));
    await tester.tap(find.text(choice.value));
    await tester.pumpAndSettle();
    expect(prefs.getInt('experience.$preferenceKey'), choice.key);
    final restored = ExperiencePreferences(prefs);
    expect(restored.integer(preferenceKey, preferenceDefault), choice.key);
    expect(tester.takeException(), isNull);
  });
  testWidgets('capture actual setup and settings with bundled typeface', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final loader = FontLoader("DM Sans");
    loader.addFont(rootBundle.load("assets/fonts/DMSans[opsz,wght].ttf"));
    await loader.load();
    final icons = FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final boundary = GlobalKey();
    for (final screen in ['setup','settings']) {
      await tester.pumpWidget(ProviderScope( child: MaterialApp(theme: eatSoonTheme(),
        home: RepaintBoundary(key: boundary, child: screen == 'setup'
          ? const Scaffold(body: SafeArea(child: ExperienceOnboardingPage(setup: true)))
          : const ExperienceSettingsScreen()))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (screen == 'setup') {
        await tester.runAsync(() => precacheImage(const AssetImage('assets/onboarding_extended/slide_5.png'), boundary.currentContext!));
        await tester.pumpAndSettle();
      }
      final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
      final image = await render.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('../product-upgrade/screenshots/eatsoon-ios-$screen.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
      });
    }
  });
}
