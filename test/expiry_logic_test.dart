import 'package:eatsoon/logic/expiry_logic.dart';
import 'package:eatsoon/models/food_item.dart';
import 'package:flutter_test/flutter_test.dart';

FoodItem _item(String name, DateTime expiry) => FoodItem(
      id: name,
      name: name,
      category: FoodCategory.produce,
      expiryDate: expiry,
    );

void main() {
  group('daysUntilExpiry', () {
    final now = DateTime(2026, 10, 4, 15, 30);

    test('compares calendar dates, ignoring time of day', () {
      expect(
        daysUntilExpiry(DateTime(2026, 10, 4, 23, 59), now),
        0,
      );
      expect(
        daysUntilExpiry(DateTime(2026, 10, 5, 0, 1), now),
        1,
      );
    });

    test('past dates are negative', () {
      expect(daysUntilExpiry(DateTime(2026, 10, 3), now), -1);
      expect(daysUntilExpiry(DateTime(2026, 9, 24), now), -10);
    });

    test('future dates are positive', () {
      expect(daysUntilExpiry(DateTime(2026, 10, 11), now), 7);
    });
  });

  group('urgencyForDays', () {
    test('expired and <= 2 days are urgent (red)', () {
      expect(urgencyForDays(-10), Urgency.expired);
      expect(urgencyForDays(-1), Urgency.expired);
      expect(urgencyForDays(0), Urgency.urgent);
      expect(urgencyForDays(1), Urgency.urgent);
      expect(urgencyForDays(2), Urgency.urgent);
    });

    test('3-5 days is warning (amber)', () {
      expect(urgencyForDays(3), Urgency.warning);
      expect(urgencyForDays(4), Urgency.warning);
      expect(urgencyForDays(5), Urgency.warning);
    });

    test('6+ days is fresh (green)', () {
      expect(urgencyForDays(6), Urgency.fresh);
      expect(urgencyForDays(7), Urgency.fresh);
      expect(urgencyForDays(365), Urgency.fresh);
    });
  });

  group('daysLeftLabel', () {
    test('expired labels', () {
      expect(daysLeftLabel(-1), 'Expired 1 day ago');
      expect(daysLeftLabel(-3), 'Expired 3 days ago');
    });

    test('today and future labels', () {
      expect(daysLeftLabel(0), 'Expires today');
      expect(daysLeftLabel(1), '1 day left');
      expect(daysLeftLabel(2), '2 days left');
      expect(daysLeftLabel(30), '30 days left');
    });
  });

  group('compareByUrgency', () {
    final now = DateTime(2026, 10, 4, 12);

    test('most urgent first', () {
      final items = [
        _item('fresh', DateTime(2026, 10, 20)),
        _item('expired', DateTime(2026, 10, 1)),
        _item('warning', DateTime(2026, 10, 8)),
        _item('urgent', DateTime(2026, 10, 5)),
      ];
      items.sort((a, b) => compareByUrgency(a, b, now: now));
      expect(
        items.map((i) => i.name).toList(),
        ['expired', 'urgent', 'warning', 'fresh'],
      );
    });

    test('ties break alphabetically (case-insensitive)', () {
      final items = [
        _item('Zucchini', DateTime(2026, 10, 6)),
        _item('apple', DateTime(2026, 10, 6)),
      ];
      items.sort((a, b) => compareByUrgency(a, b, now: now));
      expect(items.map((i) => i.name).toList(), ['apple', 'Zucchini']);
    });
  });

  group('reminderDateFor', () {
    test('schedules 9am leadDays before expiry', () {
      final when = reminderDateFor(
        expiry: DateTime(2026, 10, 10),
        leadDays: 2,
        now: DateTime(2026, 10, 1, 8),
      );
      expect(when, DateTime(2026, 10, 8, 9, 0));
    });

    test('supports 1 and 3 day lead times', () {
      expect(
        reminderDateFor(
          expiry: DateTime(2026, 10, 10),
          leadDays: 1,
          now: DateTime(2026, 10, 1),
        ),
        DateTime(2026, 10, 9, 9, 0),
      );
      expect(
        reminderDateFor(
          expiry: DateTime(2026, 10, 10),
          leadDays: 3,
          now: DateTime(2026, 10, 1),
        ),
        DateTime(2026, 10, 7, 9, 0),
      );
    });

    test('never schedules in the past', () {
      // Reminder moment already passed today.
      expect(
        reminderDateFor(
          expiry: DateTime(2026, 10, 10),
          leadDays: 2,
          now: DateTime(2026, 10, 8, 10, 0),
        ),
        isNull,
      );
      // Expiry itself in the past.
      expect(
        reminderDateFor(
          expiry: DateTime(2026, 9, 1),
          leadDays: 2,
          now: DateTime(2026, 10, 4),
        ),
        isNull,
      );
    });

    test('exactly now is not scheduled (strictly future only)', () {
      expect(
        reminderDateFor(
          expiry: DateTime(2026, 10, 10),
          leadDays: 2,
          now: DateTime(2026, 10, 8, 9, 0),
        ),
        isNull,
      );
    });

    test('same-day expiry with 0 lead days schedules 9am if still future', () {
      expect(
        reminderDateFor(
          expiry: DateTime(2026, 10, 8),
          leadDays: 0,
          now: DateTime(2026, 10, 8, 8, 0),
        ),
        DateTime(2026, 10, 8, 9, 0),
      );
      expect(
        reminderDateFor(
          expiry: DateTime(2026, 10, 8),
          leadDays: 0,
          now: DateTime(2026, 10, 8, 9, 30),
        ),
        isNull,
      );
    });

    test('month boundaries roll back correctly', () {
      expect(
        reminderDateFor(
          expiry: DateTime(2026, 11, 1),
          leadDays: 2,
          now: DateTime(2026, 10, 1),
        ),
        DateTime(2026, 10, 30, 9, 0),
      );
    });
  });

  group('notificationIdFor', () {
    test('is stable and positive', () {
      final a = notificationIdFor('abc-123');
      expect(a, notificationIdFor('abc-123'));
      expect(a, greaterThanOrEqualTo(0));
      expect(a, lessThan(0x80000000));
    });

    test('different ids map to different notifications', () {
      expect(
        notificationIdFor('item-1') == notificationIdFor('item-2'),
        isFalse,
      );
    });
  });
}
