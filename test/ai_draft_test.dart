import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eatsoon/niche/ai_client.dart';
import 'package:eatsoon/niche/draft.dart';
import 'package:eatsoon/niche/journal.dart';
import 'package:eatsoon/niche/workbench.dart';

const app = 'eatsoon';
const workflow = 'opened-pack';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('Android uses a platform-bound Play Integrity token', () async {
    const path = '/api/mobile/vision';
    final keyId = base64.encode(List.filled(32, 0));
    String? requestBody;
    String? requestData;
    Map<String, dynamic>? challengeRequest;
    Map<String, String>? requestHeaders;
    final nativeMethods = <String>[];
    final client = AiClient(
      app,
      isAndroid: true,
      native: (method, arguments) async {
        nativeMethods.add(method);
        if (method == 'assert') requestData = arguments['data'] as String?;
        return method == 'attestKey' ? keyId : 'integrity-token';
      },
      transport: (requestPath, body, headers) async {
        if (requestPath == '/api/mobile/challenge') {
          challengeRequest = jsonDecode(body) as Map<String, dynamic>;
          return {
            'schemaVersion': 1,
            'nonce': 'nonce',
            'challengeId': 'challenge',
          };
        }
        requestBody = body;
        requestHeaders = headers;
        return {'schemaVersion': 1};
      },
    );

    await client.request(path, {'photo': 'encoded'});
    expect(nativeMethods, ['attestKey', 'assert']);
    expect(challengeRequest?['platform'], 'android');
    expect(challengeRequest?['purpose'], path);
    expect(requestData, 'nonce\n$path\n$requestBody');
    expect(requestHeaders?['X-Boxill-App'], app);
    expect(requestHeaders?['X-Boxill-Platform'], 'android');
    expect(requestHeaders?['X-Boxill-Integrity-Token'], 'integrity-token');
    expect(requestHeaders?.containsKey('X-Boxill-Assertion'), isFalse);
  });
  testWidgets('cancelling consent sends neither notes nor device proof', (
    tester,
  ) async {
    var calls = 0;
    var finished = false;
    final client = AiClient(
      app,
      transport: (path, body, headers) async {
        calls++;
        return {};
      },
      native: (method, arguments) async {
        calls++;
        return 'key';
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                final result = await DraftContext(
                  app,
                  workflow,
                  client: client,
                ).extract(context, 'User source only');
                expect(result, isNull);
                finished = true;
              },
              child: const Text('Extract'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Extract'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Google Gemini'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(finished, isTrue);
  });
  testWidgets(
    'approved notes use the signed route without transmitting records',
    (tester) async {
      Map<String, dynamic>? sent;
      Record? result;
      final client = AiClient(
        app,
        native: (method, _) async =>
            method == 'attestKey' ? 'controlled-key' : 'controlled-proof',
        transport: (path, body, headers) async {
          if (path == '/api/mobile/challenge') {
            return {
              'schemaVersion': 1,
              'nonce': 'nonce',
              'challengeId': 'challenge',
            };
          }
          if (path == '/api/mobile/attest') {
            return {'schemaVersion': 1, 'registered': true};
          }
          expect(path, '/api/mobile/workspace-draft');
          expect(headers['X-Boxill-App'], app);
          sent = Map<String, dynamic>.from(jsonDecode(body) as Map);
          return {
            'schemaVersion': 1,
            'values': {'name': 'Extracted draft'},
            'missing': [],
          };
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async {
                  result = await DraftContext(
                    app,
                    workflow,
                    client: client,
                  ).extract(context, 'User source only');
                },
                child: const Text('Extract'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Extract'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agree & send'));
      await tester.pumpAndSettle();
      expect(sent, {
        'schemaVersion': 1,
        'app': app,
        'workflow': workflow,
        'notes': 'User source only',
      });
      expect(result, {'name': 'Extracted draft'});
    },
  );
  testWidgets('draft review cannot save omitted required numbers', (
    tester,
  ) async {
    Record? saved;
    final client = AiClient(
      app,
      native: (method, _) async =>
          method == 'attestKey' ? 'controlled-key' : 'controlled-proof',
      transport: (path, body, headers) async {
        if (path == '/api/mobile/challenge') {
          return {
            'schemaVersion': 1,
            'nonce': 'nonce',
            'challengeId': 'challenge',
          };
        }
        if (path == '/api/mobile/attest') {
          return {'schemaVersion': 1, 'registered': true};
        }
        return {
          'schemaVersion': 1,
          'values': {'name': 'Draft name'},
          'missing': ['count'],
        };
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                saved = await editEntry(context, 'Review draft', const [
                  EntryField('name', 'Name'),
                  EntryField(
                    'count',
                    'Count',
                    initial: '4',
                    min: 1,
                    max: 10,
                    whole: true,
                  ),
                ], draft: DraftContext(app, workflow, client: client));
              },
              child: const Text('Open editor'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Draft from my notes'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('field-notes')),
      'Provided source',
    );
    await tester.tap(find.text('Save').last);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Agree & send'));
    await tester.pumpAndSettle();
    expect(find.text('Draft name'), findsOneWidget);
    final count = tester.widget<TextFormField>(
      find.byKey(const ValueKey('field-count')),
    );
    expect(count.controller!.text, isEmpty);
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();
    expect(saved, isNull);
    await tester.enterText(find.byKey(const ValueKey('field-count')), '3');
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();
    expect(saved, {'name': 'Draft name', 'count': 3});
  });
}
