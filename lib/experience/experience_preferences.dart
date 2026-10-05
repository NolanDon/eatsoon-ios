import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Initialized before runApp; changes notify every live preference control.
class ExperiencePreferences extends ChangeNotifier {
  ExperiencePreferences([this.store]);
  final SharedPreferences? store;
  final Map<String, Object> _memory = {};
  static ExperiencePreferences instance = ExperiencePreferences();
  static Future<void> initialize() async {
    instance = ExperiencePreferences(await SharedPreferences.getInstance());
    final store = instance.store!;
    if (!store.containsKey('experience.firstUse')) {
      await store.setString(
        'experience.firstUse',
        DateTime.now().toIso8601String(),
      );
    }
  }

  int integer(String key, int fallback) =>
      store?.getInt('experience.$key') ?? _memory[key] as int? ?? fallback;
  bool flag(String key, {bool fallback = true}) =>
      store?.getBool('experience.$key') ?? _memory[key] as bool? ?? fallback;
  Future<void> setInteger(String key, int value) async {
    _memory[key] = value;
    if (store != null && !await store!.setInt('experience.$key', value)) {
      throw StateError('Preference could not be saved');
    }
    notifyListeners();
  }

  Future<void> setFlag(String key, bool value) async {
    _memory[key] = value;
    if (store != null && !await store!.setBool('experience.$key', value)) {
      throw StateError('Preference could not be saved');
    }
    notifyListeners();
  }

  Future<void> haptic() async {
    if (flag('haptics')) await HapticFeedback.selectionClick();
  }

  String exportPreferences() => const JsonEncoder.withIndent('  ').convert({
    for (final key in (store?.getKeys() ?? <String>{}).where(
      (k) => k.startsWith('experience.'),
    ))
      key: store?.get(key),
  });
}

final experienceChangesProvider = StreamProvider<int>((ref) {
  final changes = StreamController<int>();
  var revision = 0;
  void changed() => changes.add(++revision);
  ExperiencePreferences.instance.addListener(changed);
  changes.add(revision);
  ref.onDispose(() {
    ExperiencePreferences.instance.removeListener(changed);
    changes.close();
  });
  return changes.stream;
});
