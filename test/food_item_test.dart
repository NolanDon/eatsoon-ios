import 'package:eatsoon/models/food_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FoodItem serialization', () {
    test('round-trips through JSON', () {
      final item = FoodItem(
        id: 'id-1',
        name: 'Whole Milk',
        category: FoodCategory.dairy,
        expiryDate: DateTime(2026, 10, 11),
        createdAt: DateTime(2026, 10, 4, 9, 30),
      );
      final restored = FoodItem.fromJson(item.toJson());
      expect(restored.id, 'id-1');
      expect(restored.name, 'Whole Milk');
      expect(restored.category, FoodCategory.dairy);
      expect(restored.expiryDate, DateTime(2026, 10, 11));
      expect(restored.createdAt, DateTime(2026, 10, 4, 9, 30));
    });

    test('unknown category falls back to other', () {
      final item = FoodItem.fromJson({
        'id': 'x',
        'name': 'Mystery',
        'category': 'not-a-category',
        'expiryDate': DateTime(2026, 10, 11).toIso8601String(),
        'createdAt': DateTime(2026, 10, 4).toIso8601String(),
      });
      expect(item.category, FoodCategory.other);
    });

    test('missing createdAt defaults to now', () {
      final before = DateTime.now();
      final item = FoodItem.fromJson({
        'id': 'x',
        'name': 'Mystery',
        'category': 'dairy',
        'expiryDate': DateTime(2026, 10, 11).toIso8601String(),
      });
      expect(
        item.createdAt.isAfter(before.subtract(const Duration(seconds: 5))),
        isTrue,
      );
    });

    test('copyWith keeps id and createdAt', () {
      final item = FoodItem(
        id: 'id-9',
        name: 'Eggs',
        category: FoodCategory.dairy,
        expiryDate: DateTime(2026, 10, 11),
      );
      final copy = item.copyWith(name: 'Free-range eggs');
      expect(copy.id, 'id-9');
      expect(copy.name, 'Free-range eggs');
      expect(copy.category, FoodCategory.dairy);
      expect(copy.createdAt, item.createdAt);
    });
  });

  group('validateName', () {
    test('rejects empty and blank names', () {
      expect(FoodItem.validateName(''), isNotNull);
      expect(FoodItem.validateName('   '), isNotNull);
    });

    test('rejects overly long names', () {
      expect(FoodItem.validateName('a' * 61), isNotNull);
      expect(FoodItem.validateName('a' * 60), isNull);
    });

    test('accepts normal names', () {
      expect(FoodItem.validateName('Milk'), isNull);
      expect(FoodItem.validateName('  Chicken thighs  '), isNull);
    });
  });

  group('FoodCategory UI', () {
    test('every category has a label and icon', () {
      for (final c in FoodCategory.values) {
        expect(c.label, isNotEmpty);
        // ignore: unnecessary_statements — just ensuring the getter runs.
        expect(c.icon, isNotNull);
      }
    });
  });
}
