import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eatsoon/v3/model.dart';
import 'package:eatsoon/v3/legacy.dart';

import 'v3_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const kinds = [
    'clothing',
    'fridge',
    'plant',
    'meal',
    'knitting',
    'furniture',
    'drawing',
    'ticket',
    'maintenance',
    'goal',
  ];
  for (final kind in kinds) {
    test(
      '$kind persisted draft round trips and rejects invalid changes',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final store = V3Store('test', kind, prefs);
        await store.addAll([fixture(kind)]);
        final restored = V3Store('test', kind, prefs);
        expect(restored.items.single['name'], fixture(kind)['name']);
        final snapshot = store.export();
        await expectLater(
          store.update({...store.items.single, 'name': ''}),
          throwsFormatException,
        );
        expect(store.export(), snapshot);
        final detached = store.items.single;
        detached['name'] = 'Changed outside store';
        expect(store.items.single['name'], fixture(kind)['name']);
        await expectLater(
          store.restore(
            jsonEncode({
              'version': 3,
              'app': 'other',
              'items': [],
              'outfits': [],
            }),
          ),
          throwsFormatException,
        );
        expect(store.export(), snapshot);
        store.dispose();
        restored.dispose();
      },
    );
  }
  test('simultaneous saves serialize without dropping records', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = V3Store('test', 'fridge', prefs);
    await Future.wait(
      List.generate(
        12,
        (i) => store.addAll([
          {...fixture('fridge'), 'name': 'Food $i'},
        ]),
      ),
    );
    expect(store.items.length, 12);
    expect(store.items.map((v) => v['id']).toSet().length, 12);
    expect(V3Store('test', 'fridge', prefs).items.length, 12);
    store.dispose();
  });
  test(
    'corrupt data is not overwritten; recovery preserves original',
    () async {
      SharedPreferences.setMockInitialValues({
        'v3.test.records': 'broken JSON',
      });
      final prefs = await SharedPreferences.getInstance();
      final store = V3Store('test', 'fridge', prefs);
      expect(store.recovery, isNotNull);
      await expectLater(
        store.addAll([fixture('fridge')]),
        throwsFormatException,
      );
      expect(prefs.getString(store.key), 'broken JSON');
      await store.recover(
        jsonEncode({
          'version': 3,
          'app': 'test',
          'items': [fixture('fridge')],
          'outfits': [],
        }),
      );
      expect(store.items.length, 1);
      expect(prefs.getString('v3.test.recovery-original'), 'broken JSON');
      store.dispose();
    },
  );
  test('real calendar, finite amounts, precision and fractional counts are validated', () {
    expect(() => dateOrNull('2026-02-30'), throwsFormatException);
    expect(day(dateOrNull('2028-02-29')!), '2028-02-29');
    expect(() => finite(double.nan), throwsFormatException);
    expect(() => moneyValue(1.001), throwsFormatException);
    expect(cents(.29), 29);
    expect(
      () => validateItem('plant', {...fixture('plant'), 'checkDays': 2.5}),
      throwsFormatException,
    );
    expect(
      () => validateItem('maintenance', {
        ...fixture('maintenance'),
        'mileageUnit': 'metres',
      }),
      throwsFormatException,
    );
    expect(
      () => validateItem('meal', {...fixture('meal'), 'servings': 0}),
      throwsFormatException,
    );
    expect(
      () => validateItem('clothing', {
        ...fixture('clothing'),
        'photo': '../secret.jpg',
      }),
      throwsFormatException,
    );
  });
  test(
    'outfits require a top and bottoms and preserve original photos',
    () async {
      final top = fixture('clothing', id: 'top'),
          bottom = {
            ...fixture('clothing', id: 'bottom'),
            'category': 'bottom',
            'color': 'brown',
          };
      expect(() => chooseOutfit([top]), throwsFormatException);
      final outfit = chooseOutfit([top, bottom]);
      expect(outfit.map((v) => v['id']), ['bottom', 'top']);
      SharedPreferences.setMockInitialValues({});
      final store = V3Store(
        'test',
        'clothing',
        await SharedPreferences.getInstance(),
      );
      await store.addAll([top, bottom]);
      await store.saveOutfit(store.items);
      expect(store.outfits.length, 1);
      await store.remove(store.items.first['id'] as String);
      expect(store.outfits, isEmpty);
      store.dispose();
    },
  );
  test(
    'outfit retries explore available combinations and occasion scoring',
    () {
      final top = fixture('clothing', id: 'top');
      final formal = {...top, 'id': 'formal', 'style': 'formal'};
      final bottom = {
        ...top,
        'id': 'bottom',
        'category': 'bottom',
        'style': 'formal',
      };
      final first = chooseOutfit([top, formal, bottom], occasion: 'smart');
      expect(first.any((v) => v['id'] == 'formal'), isTrue);
      expect(
        chooseOutfit([
          top,
          formal,
          bottom,
        ], variant: 1).map((v) => v['id']).toSet(),
        isNot(first.map((v) => v['id']).toSet()),
      );
    },
  );
  test('clearance checks alternate furniture faces and rotation', () {
    expect(fitBox(fixture('furniture')).fits, isTrue);
    expect(
      fitBox({
        ...fixture('furniture'),
        'width': 110,
        'height': 110,
        'depth': 110,
        'doorWidth': 82,
      }).fits,
      isFalse,
    );
    expect(
      fitBox({
        ...fixture('furniture'),
        'width': 100,
        'height': 100,
        'depth': 40,
        'doorWidth': 45,
        'doorHeight': 110,
      }).fits,
      isTrue,
    );
    expect(
      () => fitBox({...fixture('furniture'), 'width': null}),
      throwsFormatException,
    );
  });
  test('recipe scaling preserves units and original amounts', () {
    final recipe = fixture('meal');
    final scaled = scaledIngredients(recipe, 3);
    expect(scaled.first['amount'], 300);
    expect(scaled.first['unit'], 'g');
    expect(children(recipe, 'ingredients').first['amount'], 200);
    expect(() => scaledIngredients(recipe, 0), throwsFormatException);
  });
  test('integer payday allocation cannot exceed available money', () {
    final goals = [
      {...fixture('goal', id: 'a'), 'target': .3, 'saved': .1},
      {...fixture('goal', id: 'b'), 'target': .5, 'saved': .1},
    ];
    final plan = allocatePayday(goals, 29);
    expect(plan.map((e) => e.allocation), [20, 9]);
    expect(plan.fold<int>(0, (sum, e) => sum + e.allocation), 29);
  });
  test('dated payday plans persist, reject mixed currency and duplicate reservations', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = V3Store('test', 'goal', prefs);
    await store.addAll([
      fixture('goal'),
      {...fixture('goal'), 'name': 'USD goal', 'currency': 'USD'},
    ]);
    final id = store.items.first['id'];
    await store.savePayday('2026-10-30', 'CAD', 20000, [
      {'id': id, 'amount': 20000},
    ]);
    expect(V3Store('test', 'goal', prefs).plans.single['date'], '2026-10-30');
    expect(store.items.first['saved'], 50);
    await expectLater(
      store.savePayday('2026-10-30', 'CAD', 100, [
        {'id': id, 'amount': 100},
      ]),
      throwsFormatException,
    );
    await expectLater(
      store.savePayday('2026-11-01', 'CAD', 30000, [
        {'id': id, 'amount': 30000},
      ]),
      throwsFormatException,
    );
    await expectLater(
      store.savePayday('2026-11-01', 'USD', 100, [
        {'id': id, 'amount': 100},
      ]),
      throwsFormatException,
    );
    await store.removePlan(store.plans.single['id'] as String);
    expect(store.plans, isEmpty);
    store.dispose();
  });
  test('migration preserves odometer miles and knitting row counts', () {
    final vehicle = legacyDraft('maintenance', {
      'nickname': 'My car',
      'odometerMiles': 12500,
      'createdAt': '2025-01-01T12:00:00Z',
    });
    expect(vehicle!['mileageUnit'], 'miles');
    expect(vehicle['mileage'], 12500);
    final knit = legacyDraft('knitting', {'name': 'Scarf', 'rowCount': 78});
    expect(knit!['row'], 78);
    expect(children(knit, 'rows').single['symbol'], 'unknown');
    expect(legacyDraft('clothing', {'name': 'Old breathing session'}), isNull);
  });
}
