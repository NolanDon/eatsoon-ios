import 'package:eatsoon/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eatsoon/experience/feedback_form.dart';
import 'package:eatsoon/experience/feedback_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'validates, submits once, and thanks only after Mail queues email',
    (tester) async {
      int calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: eatSoonTheme(),
          home: Scaffold(
            body: ListView(
              children: [
                FeedbackForm(
                  send: ({required category, required message}) async {
                    calls++;
                    expect(category, 'General feedback');
                    expect(message, 'A helpful feature suggestion.');
                    return FeedbackOutcome.sent;
                  },
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send feedback').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text('Please write at least 10 characters.'), findsOneWidget);
      expect(calls, 0);
      await tester.enterText(
        find.byType(TextFormField),
        'A helpful feature suggestion.',
      );
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.textContaining('Thank you'), findsOneWidget);
      expect(find.textContaining('queued for sending'), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getString('feedback.draft'),
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final outcome in [
    FeedbackOutcome.cancelled,
    FeedbackOutcome.failed,
    FeedbackOutcome.unavailable,
    FeedbackOutcome.saved,
  ]) {
    testWidgets('$outcome preserves the draft without claiming success', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: eatSoonTheme(),
          home: Scaffold(
            body: ListView(
              children: [
                FeedbackForm(
                  send: ({required category, required message}) async =>
                      outcome,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send feedback').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        'Please fix this issue.',
      );
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.textContaining('Thank you'), findsNothing);
      expect(
        (await SharedPreferences.getInstance()).getString('feedback.draft'),
        'Please fix this issue.',
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'small screen and large text can expand, type, and scroll to send',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: eatSoonTheme(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 568),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: ListView(
                children: [
                  FeedbackForm(
                    send: ({required category, required message}) async =>
                        FeedbackOutcome.sent,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send feedback').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        'Please add this feature.',
      );
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  test('native channel maps completion outcomes and passes only chosen text and topic', () async {
    const channel = MethodChannel('com.boxill/feedback');
    for (final outcome in FeedbackOutcome.values) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'sendFeedback');
            expect(call.arguments, {
              'category': 'Question',
              'message': 'How do I use this feature?',
            });
            return outcome.name;
          });
      expect(
        await sendFeedback(
          category: 'Question',
          message: 'How do I use this feature?',
        ),
        outcome,
      );
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  test('composer state resets after a native failure', () async {
    const channel = MethodChannel('com.boxill/feedback');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(feedbackComposerActive, isTrue);
          throw PlatformException(code: 'mail_failed');
        });
    await expectLater(
      sendFeedback(category: 'Question', message: 'Please help with this.'),
      throwsA(isA<PlatformException>()),
    );
    expect(feedbackComposerActive, isFalse);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
}
