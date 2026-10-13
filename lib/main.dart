import 'v3/brand.dart';
import 'v3/home.dart';
import 'experience/review_service.dart';
import 'experience/font_license.dart';
import 'experience/experience_preferences.dart';
import 'experience/brand_motion.dart';

import 'package:eatsoon/services/notification_service.dart';
import 'package:eatsoon/services/revenuecat_service.dart';
import 'package:eatsoon/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerBrandFontLicense();
  await ExperiencePreferences.initialize();
  tzdata.initializeTimeZones();

  final prefs = await SharedPreferences.getInstance();
  final notifications = await NotificationService.create();
  final revenueCat = LiveRevenueCatService();
  try {
    await revenueCat.init();
  } catch (_) {
    // RevenueCat init must never block launch (e.g. no network).
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        notificationServiceProvider.overrideWithValue(notifications),
        revenueCatServiceProvider.overrideWithValue(revenueCat),
      ],
      child: const EatSoonApp(),
    ),
  );
}

class EatSoonApp extends StatelessWidget {
  const EatSoonApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorObservers: [reviewNavigationObserver],
    builder: experienceAppBuilder,
    title: appName,
    theme: v3Theme(),
    debugShowCheckedModeBanner: false,
    home: const V3Home(),
  );
}

class StartupGate extends V3Home {
  const StartupGate({super.key});
}
