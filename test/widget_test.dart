import 'package:eatsoon/niche/workspace_screen.dart';
import 'legacy_app_harness.dart';
import 'package:eatsoon/models/food_item.dart';
import 'package:eatsoon/screens/home_screen.dart';
import 'package:eatsoon/screens/onboarding_screen.dart';
import 'package:eatsoon/screens/paywall_screen.dart';
import 'package:eatsoon/services/notification_service.dart';
import 'package:eatsoon/services/revenuecat_service.dart';
import 'package:eatsoon/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeNotificationService extends NotificationService {
  FakeNotificationService() : super(FlutterLocalNotificationsPlugin());

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> scheduleForItem(
    FoodItem item,
    int leadDays, {
    DateTime? now,
  }) async {}

  @override
  Future<void> cancelForItem(String itemId) async {}

  @override
  Future<void> rescheduleAll(List<FoodItem> items, int leadDays) async {}
}

Future<SharedPreferences> _mockPrefs([
  Map<String, Object> values = const {},
]) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

Widget _testApp(Widget home, SharedPreferences prefs) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      notificationServiceProvider.overrideWithValue(FakeNotificationService()),
      revenueCatServiceProvider.overrideWithValue(FakeRevenueCatService()),
    ],
    child: MaterialApp(home: home),
  );
}

String _itemsJson(List<FoodItem> items) {
  final buf = StringBuffer('[');
  for (var i = 0; i < items.length; i++) {
    if (i > 0) buf.write(',');
    final j = items[i].toJson();
    buf.write(
      '{"id":"${j['id']}","name":"${j['name']}","category":"${j['category']}","expiryDate":"${j['expiryDate']}","createdAt":"${j['createdAt']}"}',
    );
  }
  buf.write(']');
  return buf.toString();
}

FoodItem _item(String id, String name, int daysFromNow) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return FoodItem(
    id: id,
    name: name,
    category: FoodCategory.produce,
    expiryDate: today.add(Duration(days: daysFromNow)),
  );
}

void main() {
  testWidgets('first launch opens the portion workspace after onboarding', (
    tester,
  ) async {
    final prefs = await _mockPrefs();
    await tester.pumpWidget(_testApp(const StartupGate(), prefs));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.byType(StartupGate), findsNothing);
    expect(find.byType(PaywallScreen), findsNothing);
    expect(tester.takeException(), isNull);
    expect(find.byType(NicheScreen), findsOneWidget);
  });
  group('Onboarding', () {
    testWidgets('tapping through all pages calls onDone', (tester) async {
      final prefs = await _mockPrefs();
      var done = false;
      await tester.pumpWidget(
        _testApp(OnboardingScreen(onDone: () => done = true), prefs),
      );

      expect(find.text("Good food shouldn't go to waste"), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Know what remains after opening'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Never miss a date'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      expect(done, isTrue);
    });

    testWidgets('Skip jumps straight to done', (tester) async {
      final prefs = await _mockPrefs();
      var done = false;
      await tester.pumpWidget(
        _testApp(OnboardingScreen(onDone: () => done = true), prefs),
      );
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(done, isTrue);
    });
  });

  group('Paywall', () {
    testWidgets('missing Android billing returns cleanly without granting Pro', (tester) async {
      bool? unlocked;
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(body: TextButton(
        onPressed: () async { unlocked = await Navigator.push<bool>(context, MaterialPageRoute(builder: (page) => PaywallScreen(onDone: (value) => Navigator.pop(page, value)))); },
        child: const Text('Open membership'),
      )))));
      await tester.tap(find.text('Open membership'));
      await tester.pumpAndSettle();
      expect(unlocked, false);
      expect(find.text('Open membership'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Home', () {
    testWidgets('empty state offers adding the first item', (tester) async {
      final prefs = await _mockPrefs();
      await tester.pumpWidget(_testApp(const HomeScreen(), prefs));
      await tester.pumpAndSettle();

      expect(find.text('Nothing tracked yet'), findsOneWidget);
      expect(find.text('Add your first item'), findsOneWidget);
    });

    testWidgets('add item flow creates a list entry', (tester) async {
      final prefs = await _mockPrefs();
      await tester.pumpWidget(_testApp(const HomeScreen(), prefs));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add your first item'));
      await tester.pumpAndSettle();
      expect(find.text('Add item'), findsWidgets);

      await tester.enterText(find.byType(TextField), 'Milk');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add item'));
      await tester.pumpAndSettle();

      // The item shows in both the hero card and the list row.
      expect(find.text('Milk'), findsNWidgets(2));
      expect(find.text('7 days left'), findsNWidgets(2));
    });

    testWidgets('hero shows most urgent item with urgency labels', (
      tester,
    ) async {
      final items = [
        _item('a', 'Yogurt', 10),
        _item('b', 'Chicken', 1),
        _item('c', 'Spinach', 4),
      ];
      final prefs = await _mockPrefs({'eatsoon_items_v1': _itemsJson(items)});
      await tester.pumpWidget(_testApp(const HomeScreen(), prefs));
      await tester.pumpAndSettle();

      expect(find.text('Eat first'), findsOneWidget);
      // Most urgent item appears in the hero card and the list.
      expect(find.text('Chicken'), findsNWidgets(2));
      expect(find.text('1 day left'), findsWidgets);
      expect(find.text('4 days left'), findsOneWidget);
      expect(find.text('10 days left'), findsOneWidget);
    });

    testWidgets('used up removes the hero item with undo', (tester) async {
      final items = [_item('a', 'Milk', 1)];
      final prefs = await _mockPrefs({'eatsoon_items_v1': _itemsJson(items)});
      await tester.pumpWidget(_testApp(const HomeScreen(), prefs));
      await tester.pumpAndSettle();

      expect(find.text('Milk'), findsNWidgets(2));
      await tester.tap(find.text('Used up'));
      await tester.pumpAndSettle();

      expect(find.text('Nothing tracked yet'), findsOneWidget);
      expect(find.text('Marked as used up'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('Milk'), findsNWidgets(2));
    });

    testWidgets('empty name is rejected in the sheet', (tester) async {
      final prefs = await _mockPrefs();
      await tester.pumpWidget(_testApp(const HomeScreen(), prefs));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add your first item'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add item'));
      await tester.pump();

      expect(find.text('Give your item a name'), findsOneWidget);
      // Sheet stays open and nothing was added (empty state still behind it).
      expect(find.text('Edit item'), findsNothing);
      expect(find.text('Add item'), findsWidgets);
    });
  });
}
