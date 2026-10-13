import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eatsoon/v3/brand.dart';
import 'package:eatsoon/v3/home.dart';
import 'package:eatsoon/v3/model.dart';
import 'package:eatsoon/v3/dashboard.dart';
import 'package:eatsoon/v3/actions.dart';
import 'package:eatsoon/v3/editor.dart';

import 'v3_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    await (FontLoader(brandFont)
          ..addFont(rootBundle.load('assets/v3/fonts/brand.ttf'))
          ..addFont(rootBundle.load('assets/v3/fonts/bold.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('com.boxill/vision'), (
          call,
        ) async {
          if (call.method == 'directory') return '';
          throw PlatformException(
            code: 'unavailable',
            message: 'Camera unavailable. Choose a photo or enter manually.',
          );
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('purchases_flutter'), (
          call,
        ) async {
          if (call.method == 'isConfigured') return false;
          throw PlatformException(
            code: 'offline',
            message: 'Store unavailable.',
          );
        });
  });
  for (final scale in [1.0, 1.8]) {
    testWidgets(
      'distinct dashboard with data has no overflow at text scale $scale',
      (tester) async {
        await tester.view.setLogicalSize(const Size(390, 844));
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final store = V3Store(appId, appKind, prefs);
        await store.addAll([
          fixture(appKind),
          if (appKind == 'clothing')
            {
              ...fixture(appKind),
              'category': 'bottom',
              'name': 'Brown trousers',
              'color': 'brown',
            },
        ]);
        await tester.pumpWidget(
          MaterialApp(
            theme: v3Theme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: SafeArea(
                child: Column(
                  children: [
                    Text(appName, style: v3Theme().textTheme.headlineLarge),
                    Expanded(
                      child: Dashboard(
                        actions: DashboardActions(
                          store: store,
                          directory: '',
                          add: () async {},
                          edit: (_) async {},
                          remove: (_) async {},
                          update: store.update,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(appName), findsOneWidget);
        if (scale == 1.0) {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              '../../v3/evidence/screenshots/$appId-dashboard.png',
            ),
          );
        }
        await tester.pumpWidget(const SizedBox());
        store.dispose();
      },
    );
  }
  testWidgets('camera failure retains onboarding and manual fallback', (
    tester,
  ) async {
    await tester.view.setLogicalSize(const Size(390, 844));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(theme: v3Theme(), home: const V3Home()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Get started'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take a photo'));
    await tester.pumpAndSettle();
    expect(find.text('Enter manually'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enter manually'));
    await tester.pumpAndSettle();
    expect(find.byType(ItemEditor), findsOneWidget);
    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Take a photo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'real saved value appears before paywall, closing leads to dashboard wizard',
    (tester) async {
      await tester.view.setLogicalSize(const Size(390, 844));
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        'v3.$appId.records': jsonEncode({
          'version': 3,
          'app': appId,
          'items': [fixture(appKind)],
          'outfits': [],
        }),
      });
      await tester.pumpWidget(
        MaterialApp(theme: v3Theme(), home: const V3Home()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Continue'), findsOneWidget);
      expect(find.byType(Dashboard), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Continue free'), findsOneWidget);
      await tester.tap(find.text('Continue free'));
      await tester.pumpAndSettle();
      expect(find.text('Your next step'), findsOneWidget);
      expect(find.byType(Dashboard), findsOneWidget);
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(find.text('Continue'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'manual setup saves a useful record before the paywall and survives restart',
    (tester) async {
      await tester.view.setLogicalSize(const Size(390, 844));
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(theme: v3Theme(), home: const V3Home()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enter manually'));
      await tester.pumpAndSettle();
      Future<void> fill(String label, String value) async {
        final field = find.widgetWithText(TextFormField, label);
        await tester.ensureVisible(field);
        await tester.enterText(field, value);
      }

      await fill('Name', fixture(appKind)['name'] as String);
      if (appKind == 'meal') {
        await fill('Ingredients', '200 g pasta\n150 g tomatoes');
        await fill('Steps, one per line', 'Cook pasta.\nAdd sauce and serve.');
      }
      if (appKind == 'goal') await fill('Goal amount', '500');
      if (appKind == 'furniture') {
        for (final entry in {
          'Item width in cm': '70',
          'Item depth in cm': '60',
          'Item height in cm': '90',
          'Clear opening width in cm': '82',
          'Clear opening height in cm': '200',
        }.entries) {
          await fill(entry.key, entry.value);
        }
      }
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.byType(Dashboard), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(
        V3Store(appId, appKind, prefs).items.single['name'],
        fixture(appKind)['name'],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: v3Theme(),
          home: V3Home(key: UniqueKey()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Dashboard), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

extension _Size on TestFlutterView {
  Future<void> setLogicalSize(Size size) async {
    devicePixelRatio = 1;
    physicalSize = size;
  }
}
