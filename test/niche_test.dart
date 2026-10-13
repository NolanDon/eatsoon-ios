import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eatsoon/niche/journal.dart';
import 'package:eatsoon/niche/workspace_screen.dart';
import 'package:eatsoon/niche/portion_ledger.dart';
import 'package:eatsoon/theme.dart';

void validate(Record r) => validatePack(r);
Record sample() => newRecord('Example · portion ledger', {
  'portions': 4,
  'opened': '2026-10-12',
  'labelDate': '2026-10-15',
  'instructions': 'Best before; refrigerate after opening',
  'location': 'Fridge',
  'events': <Record>[],
  'replace': false,
});
const app = 'eatsoon';

Future<void> fill(WidgetTester tester, String key, String value) async {
  await tester.drag(
    find.byKey(const ValueKey('entry-scroll')),
    const Offset(0, 2000),
  );
  await tester.pumpAndSettle();
  final field = find.byKey(ValueKey('field-$key'));
  if (field.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      field,
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('entry-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, value);
}

Future<void> saveEditor(WidgetTester tester) async {
  final button = find.widgetWithText(FilledButton, 'Save');
  if (button.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      button,
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('entry-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Widget harness({double scale = 1, GlobalKey? boundary}) => ProviderScope(
  child: MaterialApp(
    theme: eatSoonTheme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: RepaintBoundary(key: boundary, child: const NicheScreen()),
  ),
);

Future<void> tapAction(WidgetTester tester, String label) async {
  await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
  await tester.pumpAndSettle();
  final item = find.text(label);
  if (item.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      item,
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(item);
  await tester.pumpAndSettle();
  await tester.tap(item);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('used and wasted portions conserve the opened pack', () {
    final r = {
      ...sample(),
      'events': [
        {'action': 'Used', 'count': 2, 'date': '2026-10-12', 'note': ''},
        {'action': 'Wasted', 'count': 1, 'date': '2026-10-12', 'note': ''},
      ],
    };
    validate(r);
    expect(portionsLeft(r), 1);
    expect(portionTotal(r, 'Used'), 2);
    expect(portionTotal(r, 'Wasted'), 1);
  });
  test('overconsumption and unknown actions are rejected', () {
    expect(
      () => validate({
        ...sample(),
        'events': [
          {'action': 'Used', 'count': 5, 'date': '2026-10-12', 'note': ''},
        ],
      }),
      throwsFormatException,
    );
    expect(
      () => validate({
        ...sample(),
        'events': [
          {'action': 'Invented', 'count': 1, 'date': '2026-10-12', 'note': ''},
        ],
      }),
      throwsFormatException,
    );
  });
  test('undo restores remaining portions', () {
    final events = <Record>[
      {'action': 'Used', 'count': 4, 'date': '2026-10-12', 'note': ''},
    ];
    expect(portionsLeft({...sample(), 'events': events}), 0);
    events.removeLast();
    expect(portionsLeft({...sample(), 'events': events}), 4);
  });

  test(
    'persistence round trip preserves old data and domain records',
    () async {
      SharedPreferences.setMockInitialValues({
        'legacy-user-data': 'preserve me',
      });
      final prefs = await SharedPreferences.getInstance(),
          store = JournalStore(app, validate, prefs),
          r = sample();
      await store.change((all) => all.add(r));
      expect(JournalStore(app, validate, prefs).read(), [r]);
      expect(prefs.getString('legacy-user-data'), 'preserve me');
    },
  );
  test(
    'concurrent writes both survive and invalid writes preserve prior data',
    () async {
      final prefs = await SharedPreferences.getInstance(),
          store = JournalStore(app, validate, prefs);
      await Future.wait([
        store.change((all) => all.add(sample())),
        store.change((all) => all.add(sample())),
      ]);
      expect(store.read().length, 2);
      final before = prefs.getString(store.key);
      await expectLater(
        store.change((all) => all.add({...sample(), 'name': ''})),
        throwsFormatException,
      );
      expect(prefs.getString(store.key), before);
    },
  );
  test(
    'wrong-app backups and duplicate identifiers cannot replace records',
    () async {
      final prefs = await SharedPreferences.getInstance(),
          store = JournalStore(app, validate, prefs),
          r = sample();
      await store.change((all) => all.add(r));
      final before = prefs.getString(store.key);
      expect(() => store.decode(store.encode([r, r])), throwsFormatException);
      expect(
        () => store.decode(
          store.encode([r]).replaceFirst('"app":"$app"', '"app":"other"'),
        ),
        throwsFormatException,
      );
      await expectLater(
        store.restore(store.encode([r])),
        throwsFormatException,
      );
      expect(prefs.getString(store.key), before);
    },
  );
  test(
    'unreadable data is preserved until a valid recovery is selected',
    () async {
      final prefs = await SharedPreferences.getInstance(),
          store = JournalStore(app, validate, prefs);
      await prefs.setString(store.key, 'unreadable');
      expect(store.read, throwsFormatException);
      expect(prefs.getString(store.key), 'unreadable');
      expect(
        () => store.replaceUnreadable('invalid backup'),
        throwsFormatException,
      );
      expect(prefs.getString(store.key), 'unreadable');
      await store.replaceUnreadable(store.encode([sample()]));
      expect(store.read().length, 1);
    },
  );
  testWidgets('new primary workflow creates and persists a record', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton).first);
    await tester.pumpAndSettle();
    await saveEditor(tester);
    expect(
      JournalStore(app, validate, await SharedPreferences.getInstance()).read(),
      isEmpty,
    );
    for (final entry in {
      'name': 'Opened yogurt',
      'instructions': 'Use the printed after-opening directions',
    }.entries) {
      await fill(tester, entry.key, entry.value);
    }
    await saveEditor(tester);

    expect(tester.takeException(), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(JournalStore(app, validate, prefs).read().length, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    expect(
      find.text(
        {
          'name': 'Opened yogurt',
          'instructions': 'Use the printed after-opening directions',
        }['name']!,
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('unreadable data shows recovery state without a write', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'niche.$app.v1': 'broken'});
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    expect(find.textContaining('Saved data could not be read'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(
      (await SharedPreferences.getInstance()).getString('niche.$app.v1'),
      'broken',
    );
  });
  testWidgets('domain actions preserve their invariants and survive updates', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final store = JournalStore(app, validate, prefs);
    await store.change((all) => all.add(sample()));
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    await tapAction(tester, 'Use portions');
    await saveEditor(tester);
    expect(portionsLeft(store.read().single), 3);
    await tapAction(tester, 'Record wasted portions');
    await saveEditor(tester);
    expect(portionsLeft(store.read().single), 2);
    await tapAction(tester, 'Undo last portion entry');
    expect(portionsLeft(store.read().single), 3);
    expect(tester.takeException(), isNull);
  });
  testWidgets('populated workflow renders at normal and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final prefs = await SharedPreferences.getInstance();
    final store = JournalStore(app, validate, prefs);
    await store.change((all) => all.add(sample()));
    await (FontLoader(
      'DM Sans',
    )..addFont(rootBundle.load('assets/fonts/DMSans[opsz,wght].ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    for (final scale in [1.0, 1.8]) {
      final boundary = GlobalKey();
      await tester.pumpWidget(harness(scale: scale, boundary: boundary));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File(
          '../niche-upgrade/screenshots/eatsoon-${scale == 1 ? 'normal' : 'large'}.png',
        );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.drag(find.byType(ListView).first, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}
