import 'package:eatsoon/config.dart';
import 'package:eatsoon/screens/home_screen.dart';
import 'package:eatsoon/screens/onboarding_screen.dart';
import 'package:eatsoon/screens/paywall_screen.dart';
import 'package:eatsoon/services/notification_service.dart';
import 'package:eatsoon/services/revenuecat_service.dart';
import 'package:eatsoon/state/providers.dart';
import 'package:eatsoon/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

class EatSoonApp extends ConsumerWidget {
  const EatSoonApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: AppConfig.appName,
      theme: eatSoonTheme(),
      debugShowCheckedModeBanner: false,
      home: const StartupGate(),
    );
  }
}

/// Routes: onboarding (once) -> paywall -> home. Later launches go
/// straight home.
class StartupGate extends ConsumerStatefulWidget {
  const StartupGate({super.key});

  @override
  ConsumerState<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends ConsumerState<StartupGate> {
  bool _loading = true;
  bool _seenOnboarding = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final repo = ref.read(foodRepositoryProvider);
    final seen = await repo.onboardingSeen();
    // Refresh Pro status quietly in the background.
    ref.read(revenueCatServiceProvider).isPro().then((pro) {
      if (mounted) ref.read(isProProvider.notifier).state = pro;
    });
    if (mounted) {
      setState(() {
        _seenOnboarding = seen;
        _loading = false;
      });
    }
  }

  Future<void> _finishOnboarding() async {
    await ref.read(foodRepositoryProvider).setOnboardingSeen();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PaywallScreen(
          onDone: (_) => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: EatSoonColors.paper,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_seenOnboarding) {
      return OnboardingScreen(onDone: _finishOnboarding);
    }
    return const HomeScreen();
  }
}
