import 'dart:convert';

import 'package:eatsoon/config.dart';
import 'package:eatsoon/models/food_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists food items and settings as JSON in SharedPreferences.
/// The dataset is tiny (a handful of items), so this is plenty.
class FoodRepository {
  FoodRepository(this._prefs);

  final SharedPreferences _prefs;

  static const String itemsKey = 'eatsoon_items_v1';
  static const String leadDaysKey = 'eatsoon_lead_days';
  static const String onboardingSeenKey = 'eatsoon_onboarding_seen';

  Future<List<FoodItem>> loadItems() async {
    final raw = _prefs.getString(itemsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return list.map(FoodItem.fromJson).toList();
    } catch (_) {
      // Corrupt data should never brick the app; start fresh.
      return [];
    }
  }

  Future<void> saveItems(List<FoodItem> items) async {
    final raw = jsonEncode(items.map((i) => i.toJson()).toList());
    await _prefs.setString(itemsKey, raw);
  }

  Future<int> loadLeadDays() async =>
      _prefs.getInt(leadDaysKey) ?? AppConfig.defaultLeadDays;

  Future<void> saveLeadDays(int days) async =>
      _prefs.setInt(leadDaysKey, days);

  Future<bool> onboardingSeen() async =>
      _prefs.getBool(onboardingSeenKey) ?? false;

  Future<void> setOnboardingSeen() async =>
      _prefs.setBool(onboardingSeenKey, true);
}
