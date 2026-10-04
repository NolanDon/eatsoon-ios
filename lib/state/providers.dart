import 'package:eatsoon/data/food_repository.dart';
import 'package:eatsoon/logic/expiry_logic.dart';
import 'package:eatsoon/models/food_item.dart';
import 'package:eatsoon/services/notification_service.dart';
import 'package:eatsoon/services/revenuecat_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in main() with real instances, in tests with fakes.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('override me'),
);

final foodRepositoryProvider = Provider<FoodRepository>((ref) {
  return FoodRepository(ref.watch(sharedPreferencesProvider));
});

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => throw UnimplementedError('override me'),
);

final revenueCatServiceProvider = Provider<RevenueCatService>(
  (ref) => throw UnimplementedError('override me'),
);

/// Whether the "pro" entitlement is active.
final isProProvider = StateProvider<bool>((ref) => false);

/// Reminder lead time in days. Free users are locked to the default.
final leadDaysProvider = StateProvider<int>((ref) => 2);

/// The food list, sorted by urgency.
final itemsProvider =
    AsyncNotifierProvider<ItemsNotifier, List<FoodItem>>(
  ItemsNotifier.new,
);

/// True when the user may add another item under their tier.
final canAddMoreProvider = Provider<bool>((ref) {
  final items = ref.watch(itemsProvider).value ?? [];
  final isPro = ref.watch(isProProvider);
  if (isPro) return true;
  return items.length < 5;
});

class ItemsNotifier extends AsyncNotifier<List<FoodItem>> {
  FoodItem? _lastRemoved;
  int? _lastRemovedIndex;

  FoodRepository get _repo => ref.read(foodRepositoryProvider);
  NotificationService get _notifications =>
      ref.read(notificationServiceProvider);

  @override
  Future<List<FoodItem>> build() async {
    final items = await _repo.loadItems();
    items.sort((a, b) => compareByUrgency(a, b));
    final leadDays = await _repo.loadLeadDays();
    ref.read(leadDaysProvider.notifier).state = leadDays;
    await _notifications.rescheduleAll(items, leadDays);
    return items;
  }

  Future<bool> addItem(FoodItem item) async {
    final List<FoodItem> items = [...state.value ?? []];
    final isPro = ref.read(isProProvider);
    if (!isPro && items.length >= 5) return false;
    items.add(item);
    items.sort((a, b) => compareByUrgency(a, b));
    await _repo.saveItems(items);
    state = AsyncValue.data(items);
    await _notifications.scheduleForItem(
      item,
      ref.read(leadDaysProvider),
    );
    return true;
  }

  Future<void> updateItem(FoodItem item) async {
    final List<FoodItem> items = [...state.value ?? []];
    final i = items.indexWhere((e) => e.id == item.id);
    if (i == -1) return;
    items[i] = item;
    items.sort((a, b) => compareByUrgency(a, b));
    await _repo.saveItems(items);
    state = AsyncValue.data(items);
    await _notifications.scheduleForItem(
      item,
      ref.read(leadDaysProvider),
    );
  }

  /// Removes the item; keep it for undo.
  Future<void> removeItem(String id) async {
    final List<FoodItem> items = [...state.value ?? []];
    final i = items.indexWhere((e) => e.id == id);
    if (i == -1) return;
    _lastRemoved = items[i];
    _lastRemovedIndex = i;
    items.removeAt(i);
    await _repo.saveItems(items);
    state = AsyncValue.data(items);
    await _notifications.cancelForItem(id);
  }

  Future<bool> undoRemove() async {
    final removed = _lastRemoved;
    if (removed == null) return false;
    final List<FoodItem> items = [...state.value ?? []];
    final index = (_lastRemovedIndex ?? items.length).clamp(0, items.length);
    items.insert(index, removed);
    items.sort((a, b) => compareByUrgency(a, b));
    await _repo.saveItems(items);
    state = AsyncValue.data(items);
    await _notifications.scheduleForItem(
      removed,
      ref.read(leadDaysProvider),
    );
    _lastRemoved = null;
    _lastRemovedIndex = null;
    return true;
  }

  Future<void> setLeadDays(int days) async {
    await _repo.saveLeadDays(days);
    ref.read(leadDaysProvider.notifier).state = days;
    await _notifications.rescheduleAll(state.value ?? [], days);
  }
}
