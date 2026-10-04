import 'package:eatsoon/models/food_item.dart';
import 'package:eatsoon/services/notification_service.dart';
import 'package:eatsoon/services/revenuecat_service.dart';
import 'package:eatsoon/state/providers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeNotificationService extends NotificationService {
  FakeNotificationService() : super(FlutterLocalNotificationsPlugin());

  @override
  Future<void> scheduleForItem(FoodItem item, int leadDays,
      {DateTime? now}) async {}

  @override
  Future<void> cancelForItem(String itemId) async {}

  @override
  Future<void> rescheduleAll(List<FoodItem> items, int leadDays) async {}
}

FoodItem _item(String id) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return FoodItem(
    id: id,
    name: 'Item $id',
    category: FoodCategory.other,
    expiryDate: today.add(const Duration(days: 7)),
  );
}

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      notificationServiceProvider
          .overrideWithValue(FakeNotificationService()),
      revenueCatServiceProvider.overrideWithValue(FakeRevenueCatService()),
    ],
  );
  // Wait for the notifier's initial load.
  for (var i = 0; i < 100; i++) {
    if (container.read(itemsProvider).hasValue) break;
    await Future.delayed(const Duration(milliseconds: 20));
  }
  return container;
}

void main() {
  group('ItemsNotifier', () {
    test('free tier caps at 5 items', () async {
      final c = await _container();
      final notifier = c.read(itemsProvider.notifier);

      for (var i = 0; i < 5; i++) {
        expect(await notifier.addItem(_item('free-$i')), isTrue);
      }
      expect(c.read(itemsProvider).value!.length, 5);
      expect(await notifier.addItem(_item('free-6')), isFalse);
      expect(c.read(canAddMoreProvider), isFalse);
      c.dispose();
    });

    test('pro users have no item cap', () async {
      final c = await _container();
      c.read(isProProvider.notifier).state = true;
      final notifier = c.read(itemsProvider.notifier);

      for (var i = 0; i < 8; i++) {
        expect(await notifier.addItem(_item('pro-$i')), isTrue);
      }
      expect(c.read(itemsProvider).value!.length, 8);
      expect(c.read(canAddMoreProvider), isTrue);
      c.dispose();
    });

    test('remove + undo restores the item', () async {
      final c = await _container();
      final notifier = c.read(itemsProvider.notifier);

      await notifier.addItem(_item('u1'));
      await notifier.addItem(_item('u2'));
      await notifier.removeItem('u1');
      expect(
        c.read(itemsProvider).value!.map((i) => i.id),
        ['u2'],
      );
      expect(await notifier.undoRemove(), isTrue);
      expect(
        c.read(itemsProvider).value!.map((i) => i.id).toSet(),
        {'u1', 'u2'},
      );
      // Second undo is a no-op.
      expect(await notifier.undoRemove(), isFalse);
      c.dispose();
    });

    test('updateItem persists changes', () async {
      final c = await _container();
      final notifier = c.read(itemsProvider.notifier);

      await notifier.addItem(_item('e1'));
      final updated = _item('e1').copyWith(name: 'Renamed');
      await notifier.updateItem(updated);
      expect(
        c.read(itemsProvider).value!.first.name,
        'Renamed',
      );
      c.dispose();
    });

    test('setLeadDays persists and updates the provider', () async {
      final c = await _container();
      final notifier = c.read(itemsProvider.notifier);

      await notifier.setLeadDays(3);
      expect(c.read(leadDaysProvider), 3);
      c.dispose();
    });
  });
}
