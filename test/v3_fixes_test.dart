import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eatsoon/v3/brand.dart';
import 'package:eatsoon/v3/home.dart';
import 'package:eatsoon/v3/onboarding.dart';
import 'package:eatsoon/v3/settings.dart';
import 'package:eatsoon/v3/photo_flow.dart';
import 'package:eatsoon/v3/mascot.dart';
import 'package:eatsoon/experience/experience_preferences.dart';

import 'v3_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    await (FontLoader(
      brandFont,
    )..addFont(rootBundle.load('assets/v3/fonts/bricolage.ttf'))).load();
    SharedPreferences.setMockInitialValues({});
    ExperiencePreferences.instance = ExperiencePreferences(
      await SharedPreferences.getInstance(),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('com.boxill/vision'), (
          call,
        ) async {
          if (call.method == 'directory') return '';
          throw PlatformException(code: 'photo');
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('purchases_flutter'), (
          call,
        ) async {
          if (call.method == 'isConfigured') return false;
          throw PlatformException(code: 'offline');
        });
  });
  test(
    'seven explanations are concise, specific and free of vague add prompts',
    () {
      expect(introSteps.length, appKind == 'clothing' ? 7 : needsReminderIntro ? 4 : 3);
      for (final step in introSteps) {
        expect(
          step.body
              .split(RegExp(r'[.!?]'))
              .where((s) => s.trim().isNotEmpty)
              .length,
          lessThanOrEqualTo(3),
        );
        expect(step.body.length, lessThan(300));
      }
      expect(photoInstruction.length, greaterThan(40));
      expect(addTitle, isNot('Add something new'));
    },
  );
  for (final scale in [1.0, 1.8]) {
    testWidgets('all seven feature demos fit a small screen at scale $scale', (
      t,
    ) async {
      await t.view.setLogicalSize(const Size(320, 680));
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      var finished = false;
      await t.pumpWidget(
        MaterialApp(
          theme: v3Theme(),
          builder: (c, w) => MediaQuery(
            data: MediaQuery.of(c)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: w!,
          ),
          home: Scaffold(
            body: SafeArea(
              child: FeatureOnboarding(onDone: () => finished = true),
            ),
          ),
        ),
      );
      for (var i = 0; i < introSteps.length; i++) {
        await t.pumpAndSettle();
        expect(find.bySemanticsLabel('Step ${i + 1} of ${introSteps.length}'), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.tap(
          find.text(
            needsReminderIntro && i == introSteps.length - 1
                ? 'Skip'
                : i == 0
                ? 'Open my kitchen'
                : i == introSteps.length - 1
                ? 'Stock my fridge'
                : 'See how',
          ),
        );
      }
      expect(finished, true);
      await t.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'gear opens spaced settings, local profile persists and support is reachable',
    (t) async {
      await t.view.setLogicalSize(const Size(390, 844));
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('v3.$appId.intro', true);
      await prefs.setBool('v3.$appId.wizard', true);
      await t.pumpWidget(MaterialApp(theme: v3Theme(), home: const V3Home()));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Kitchen settings'));
      await t.pumpAndSettle();
      expect(find.byType(AppSettings), findsOneWidget);
      expect(find.text('Your profile'), findsOneWidget);
      final first = t.getRect(
        find.widgetWithText(ListTile, 'Upgrade'),
      );
      final second = t.getRect(
        find.widgetWithText(ListTile, 'Manage subscriptions'),
      );
      expect(second.top - first.bottom, greaterThanOrEqualTo(12));
      await t.tap(find.byTooltip('Edit profile'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Alex');
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(prefs.getString('v3.$appId.profile'), 'Alex');
      expect(find.text('Alex'), findsOneWidget);
      await t.scrollUntilVisible(
        find.text('Support'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Support'));
      await t.pumpAndSettle();
      await t.tap(find.text('Support'));
      await t.pumpAndSettle();
      expect(find.byType(SupportScreen), findsOneWidget);
      String? clipboard;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String?;
        }
        return null;
      });
      await t.tap(find.text('Copy support email'));
      await t.pumpAndSettle();
      expect(
        clipboard,
        'support@boxillapps.com',
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('dashboard wizard contains exactly one guide mascot', (t) async {
    SharedPreferences.setMockInitialValues({
      'v3.$appId.intro': true,
      'v3.$appId.records': jsonEncode({
        'version': 3,
        'app': appId,
        'items': [fixture(appKind)],
        'outfits': [],
      }),
    });
    await t.pumpWidget(MaterialApp(theme: v3Theme(), home: const V3Home()));
    await t.pumpAndSettle();
    expect(find.text('Your next step'), findsOneWidget);
    final guides = t
        .widgetList<Mascot>(find.byType(Mascot))
        .where((v) => v.pose == 'guide');
    expect(guides.length, 1);
    expect(t.takeException(), isNull);
  });
  test('technical native model errors cannot reach the user', () {
    final text = photoError(
      PlatformException(
        code: 'cutout',
        message: 'ANECF failed file:///System/Library/private.espresso.net',
      ),
    );
    expect(text, contains('plain surface'));
    expect(text, isNot(contains('ANECF')));
    expect(text, isNot(contains('file://')));
  });
  testWidgets('backup review owns its text controller through dismissal', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        theme: v3Theme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<String>(
                context: context,
                builder: (_) => const BackupRestoreDialog(),
              ),
              child: const Text('Review a backup'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Review a backup'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'invalid backup');
    await t.tap(find.text('Review'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
 testWidgets('analysis mascot has clear space above the bottom action',(t)async{
  await t.view.setLogicalSize(const Size(390,844));addTearDown(t.view.resetPhysicalSize);addTearDown(t.view.resetDevicePixelRatio);
  final capture=Completer<dynamic>();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('com.boxill/vision'),(call)async{if(call.method=='directory')return '';if(call.method=='capture')return capture.future;return null;});
  await t.pumpWidget(MaterialApp(theme:v3Theme(),home:const V3Home()));await t.pumpAndSettle();
  await t.tap(find.text('Open my kitchen'));await t.pumpAndSettle();for(var i=0;i<(introSteps.length - 2);i++){await t.tap(find.text('See how'));await t.pumpAndSettle();}await t.tap(find.text(needsReminderIntro ? 'Skip' : 'Stock my fridge'));await t.pumpAndSettle();
  await t.tap(find.text('Scan food'));await t.pump(const Duration(milliseconds:700));
  final mascot=find.byWidgetPredicate((w)=>w is Mascot&&w.pose=='thinking');expect(mascot,findsOneWidget);
  final action=t.getRect(find.widgetWithText(FilledButton,'Scan food'));expect(action.top-t.getRect(mascot).bottom,greaterThanOrEqualTo(32));expect(t.takeException(),isNull);
  capture.complete(null);await t.pumpAndSettle();expect(t.takeException(),isNull);
 });

}

extension FixViewSize on TestFlutterView {
  Future<void> setLogicalSize(Size value) async {
    devicePixelRatio = 1;
    physicalSize = value;
  }
}
