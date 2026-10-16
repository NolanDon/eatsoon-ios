import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef Item = Map<String, dynamic>;
String day(DateTime at) =>
    '${at.year}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}';
String uniqueId() => DateTime.now().microsecondsSinceEpoch.toString();
void need(bool condition, String message) {
  if (!condition) throw FormatException(message);
}

double finite(Object? value, {double min = 0, double max = 1000000}) {
  need(
    value is num && value.isFinite && value >= min && value <= max,
    'Check the amount.',
  );
  return (value as num).toDouble();
}

DateTime? dateOrNull(Object? value) {
  if (value == null || value == '') return null;
  need(
    value is String && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value),
    'Check the date.',
  );
  final at = DateTime.tryParse(value as String);
  need(at != null && day(at) == value, 'Check the date.');
  return at;
}

int cents(Object? value) => (finite(value) * 100).round();
double moneyValue(Object? value, {double min = 0}) {
  final n = finite(value, min: min);
  need(
    (n * 100 - (n * 100).round()).abs() < .00001,
    'Use up to two decimal places.',
  );
  return n;
}

List<Item> children(Item item, String key) {
  final value = item[key] ?? [];
  need(value is List && value.length <= 500, 'Check $key.');
  return (value as List).map((v) {
    need(v is Map, 'Check $key.');
    return Map<String, dynamic>.from(v as Map);
  }).toList();
}

int whole(Object? value, {int min = 0, int max = 1000000}) {
  final n = finite(value, min: min.toDouble(), max: max.toDouble());
  need(n == n.round(), 'Use a whole number.');
  return n.toInt();
}

void validateItem(String kind, Item item) {
  if (item['sharedReminders'] != null)
    need(item['sharedReminders'] is bool, 'Invalid reminder setting.');
  need(
    item['id'] is String && (item['id'] as String).isNotEmpty,
    'Missing identifier.',
  );
  need(
    item['name'] is String &&
        (item['name'] as String).trim().isNotEmpty &&
        (item['name'] as String).length <= 120,
    'Enter a name.',
  );
  for (final key in ['photo', 'cutout']) {
    if (item[key] != null) {
      need(
        item[key] is String &&
            RegExp(r'^[A-Za-z0-9-]+\.(png|jpg)$').hasMatch(item[key] as String),
        'Invalid photo reference.',
      );
    }
  }
  switch (kind) {
    case 'clothing':
      need(
        [
          'top',
          'bottom',
          'shoes',
          'hat',
          'bag',
          'gloves',
          'accessory',
          'dress',
          'outerwear',
        ].contains(item['category']),
        'Choose a clothing type.',
      );
      need(
        [
          'black',
          'white',
          'gray',
          'cream',
          'brown',
          'blue',
          'green',
          'red',
          'pink',
          'purple',
          'yellow',
          'orange',
        ].contains(item['color']),
        'Choose a color.',
      );
      need(
        ['casual', 'formal', 'sport', 'any'].contains(item['style']),
        'Choose a style.',
      );
    case 'meal':
      final servings = finite(item['servings'], min: 1, max: 48);
      need(servings == servings.round(), 'Use whole servings.');
      need(
        children(item, 'ingredients').isNotEmpty &&
            children(item, 'ingredients').length <= 30,
        'Use 1 to 30 ingredients.',
      );
      for (final ingredient in children(item, 'ingredients')) {
        finite(ingredient['amount'], min: 0.001, max: 100000);
        need(
          ingredient['name'] is String &&
              (ingredient['name'] as String).trim().isNotEmpty,
          'Name the ingredient.',
        );
        need(
          [
            'g',
            'ml',
            'tsp',
            'tbsp',
            'cup',
            'piece',
          ].contains(ingredient['unit']),
          'Choose an ingredient unit.',
        );
      }
      need(
        item['steps'] is List &&
            (item['steps'] as List).isNotEmpty &&
            (item['steps'] as List).length <= 8,
        'Use 1 to 8 short steps.',
      );
      need(
        (item['steps'] as List).every(
          (v) => v is String && v.trim().isNotEmpty && v.length <= 200,
        ),
        'Keep each step under 200 characters.',
      );
    case 'fridge':
      whole(item['checkDays'], min: 1, max: 90);
      dateOrNull(item['labelDate']);
      dateOrNull(item['nextDate']);
      need(
        ['fridge', 'freezer', 'pantry'].contains(item['location']),
        'Choose a storage place.',
      );
    case 'plant':
      whole(item['checkDays'], min: 1, max: 365);
      dateOrNull(item['nextDate']);
      need(
        [
          'bright indirect',
          'direct light',
          'low light',
          'unknown',
        ].contains(item['light']),
        'Choose a light setting.',
      );
    case 'furniture':
      for (final key in [
        'width',
        'depth',
        'height',
        'doorWidth',
        'doorHeight',
      ]) {
        if (item[key] != null) finite(item[key], min: 0.1, max: 10000);
      }
    case 'ticket':
      need(
        item['memory'] == null ||
            (item['memory'] is String &&
                (item['memory'] as String).length <= 160),
        'Keep the memory under 160 characters.',
      );
      dateOrNull(item['date']);
      need(
        [
          'concert',
          'festival',
          'theatre',
          'sport',
          'other',
        ].contains(item['category']),
        'Choose an event type.',
      );
    case 'knitting':
      if (item['castOn'] != null) whole(item['castOn'], min: 1, max: 1000);
      need(
        children(item, 'rows').isNotEmpty &&
            children(item, 'rows').length <= 12,
        'Use 1 to 12 guide rows.',
      );
      for (final row in children(item, 'rows')) {
        need(
          ['K', 'P', 'YO', 'K2TOG', 'unknown'].contains(row['symbol']),
          'Check the stitch.',
        );
        if (row['count'] != null) whole(row['count'], min: 1, max: 1000);
        need(
          row['instruction'] is String &&
              (row['instruction'] as String).trim().isNotEmpty &&
              (row['instruction'] as String).length <= 160,
          'Keep each row short.',
        );
      }
      whole(item['row'] ?? 0, max: 1000000);
    case 'goal':
      if (item['target'] != null) moneyValue(item['target'], min: 0.01);
      moneyValue(item['saved'] ?? 0);
      dateOrNull(item['deadline']);
      if (item['target'] != null) {
        need(
          cents(item['saved'] ?? 0) <= cents(item['target']),
          'Saved amount exceeds the goal.',
        );
      }
      need(
        item['currency'] is String && (item['currency'] as String).length <= 8,
        'Check the currency.',
      );
    case 'maintenance':
      need(
        ['km', 'miles', 'unknown'].contains(item['mileageUnit'] ?? 'unknown'),
        'Check the distance unit.',
      );
      if (item['mileage'] != null) whole(item['mileage'], max: 5000000);
      dateOrNull(item['date']);
      dateOrNull(item['nextServiceDate']);
      need(
        item['tasks'] is List &&
            (item['tasks'] as List).isNotEmpty &&
            (item['tasks'] as List).length <= 12,
        'Use 1 to 12 tasks.',
      );
    case 'drawing':
      need(
        children(item, 'panels').length >= 3 &&
            children(item, 'panels').length <= 6,
        'Use three to six panels.',
      );
      for (final panel in children(item, 'panels')) {
        need(
          panel['caption'] is String &&
              (panel['caption'] as String).trim().isNotEmpty &&
              (panel['caption'] as String).length <= 140,
          'Keep each caption short.',
        );
        need(
          ['plain', 'sky', 'forest', 'city', 'space'].contains(panel['scene']),
          'Check the scene.',
        );
        need(
          ['left', 'center', 'right'].contains(panel['position']),
          'Check the panel.',
        );
      }
  }
}

class V3Store extends ChangeNotifier {
  final String app, kind;
  final SharedPreferences prefs;
  List<Item> _items = [];
  List<Item> _outfits = [];
  List<Item> _plans = [];
  String? recovery;
  bool _alive = true;
  Future<void> _tail = Future.value();
  V3Store(this.app, this.kind, this.prefs) {
    try {
      final raw = prefs.getString(key);
      if (raw != null) {
        final value = decode(raw);
        _items = value.$1;
        _outfits = value.$2;
        _plans = value.$3;
      }
    } catch (_) {
      recovery = 'Saved data needs recovery.';
    }
  }
  String get key => 'v3.$app.records';
  List<Item> get items => List.unmodifiable(
    (jsonDecode(jsonEncode(_items)) as List).map(
      (v) => Map<String, dynamic>.from(v as Map),
    ),
  );
  List<Item> get outfits => List.unmodifiable(
    (jsonDecode(jsonEncode(_outfits)) as List).map(
      (v) => Map<String, dynamic>.from(v as Map),
    ),
  );
  List<Item> get plans => List.unmodifiable(
    (jsonDecode(jsonEncode(_plans)) as List).map(
      (v) => Map<String, dynamic>.from(v as Map),
    ),
  );
  (List<Item>, List<Item>, List<Item>) decode(String raw) {
    need(raw.length <= 4000000, 'Backup too large.');
    final value = jsonDecode(raw);
    need(
      value is Map &&
          value['version'] == 3 &&
          value['app'] == app &&
          value['items'] is List &&
          value['outfits'] is List,
      'Wrong backup.',
    );
    final items = (value['items'] as List)
        .map((v) => Map<String, dynamic>.from(v as Map))
        .toList();
    final outfits = (value['outfits'] as List)
        .map((v) => Map<String, dynamic>.from(v as Map))
        .toList();
    final plans = (value['plans'] as List? ?? [])
        .map((v) => Map<String, dynamic>.from(v as Map))
        .toList();
    need(plans.length <= 500, 'Too many payday plans.');
    need(items.length <= 500 && outfits.length <= 500, 'Collection is full.');
    final ids = <String>{};
    for (final item in items) {
      validateItem(kind, item);
      need(ids.add(item['id'] as String), 'Duplicate identifier.');
    }
    for (final outfit in outfits) {
      need(outfit['id'] is String && outfit['ids'] is List, 'Invalid outfit.');
      need(
        (outfit['ids'] as List).every((id) => ids.contains(id)),
        'Missing outfit item.',
      );
    }
    for (final plan in plans) {
      need(
        kind == 'goal' && plan['id'] is String && plan['currency'] is String,
        'Invalid payday plan.',
      );
      dateOrNull(plan['date']);
      need(plan['date'] != null, 'Choose a payday.');
      final available = whole(plan['available'], max: 100000000);
      var total = 0;
      for (final entry in children(plan, 'allocations')) {
        need(ids.contains(entry['id']), 'Missing planned goal.');
        final goal = items.firstWhere((v) => v['id'] == entry['id']);
        need(
          goal['currency'] == plan['currency'],
          'Use one currency per plan.',
        );
        total += whole(entry['amount'], max: 100000000);
      }
      need(total <= available, 'Plan exceeds available funds.');
    }
    return (items, outfits, plans);
  }

  String export() => jsonEncode({
    'version': 3,
    'app': app,
    'items': _items,
    'outfits': _outfits,
    'plans': _plans,
  });
  Future<void> _change(void Function(List<Item>, List<Item>, List<Item>) edit) {
    final result = _tail.then((_) async {
      need(recovery == null, 'Recover saved data before changing it.');
      final copy = jsonDecode(export()) as Map;
      final items = (copy['items'] as List)
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
      final outfits = (copy['outfits'] as List)
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
      final plans = (copy['plans'] as List)
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
      edit(items, outfits, plans);
      final raw = jsonEncode({
        'version': 3,
        'app': app,
        'items': items,
        'outfits': outfits,
        'plans': plans,
      });
      final checked = decode(raw);
      need(await prefs.setString(key, raw), 'Could not save.');
      _items = checked.$1;
      _outfits = checked.$2;
      _plans = checked.$3;
      if (_alive) notifyListeners();
    });
    _tail = result.catchError((Object _) {});
    return result;
  }

  Future<void> mergeShared(
    List<Item> incoming,
    List<Item> sharedOutfits,
    String receiptId,
  ) => _change((items, outfits, plans) {
    if (items.any((v) => v['sourceTransferId'] == receiptId)) return;
    final mapping = <String, String>{};
    final prefix = uniqueId();
    for (var i = 0; i < incoming.length; i++) {
      final source = incoming[i];
      final old = source['id'] as String;
      need(!mapping.containsKey(old), 'Duplicate shared record.');
      final id = '$prefix-$i';
      mapping[old] = id;
      items.add({...source, 'id': id, 'sourceTransferId': receiptId});
    }
    for (var i = 0; i < sharedOutfits.length; i++) {
      final source = sharedOutfits[i];
      final ids = (source['ids'] as List).map((id) {
        need(mapping.containsKey(id), 'Missing outfit piece.');
        return mapping[id]!;
      }).toList();
      outfits.add({...source, 'id': '$prefix-outfit-$i', 'ids': ids});
    }
  });

  Future<void> addAll(List<Item> values) => _change((items, outfits, plans) {
    for (final value in values) {
      if (kind == 'fridge' &&
          items.any((existing) => sameFood(existing, value)))
        continue;
      items.add({...value, 'id': '${uniqueId()}-${items.length}'});
    }
  });
  Future<void> update(Item value) => _change((items, outfits, plans) {
    final index = items.indexWhere((v) => v['id'] == value['id']);
    need(index >= 0, 'Item no longer exists.');
    items[index] = Map.from(value);
  });
  Future<void> remove(String id) => _change((items, outfits, plans) {
    items.removeWhere((v) => v['id'] == id);
    outfits.removeWhere((v) => (v['ids'] as List).contains(id));
    for (final plan in plans) {
      (plan['allocations'] as List).removeWhere((entry) => entry['id'] == id);
    }
  });
  Future<void> saveOutfit(List<Item> pieces) =>
      _change((items, outfits, plans) {
        need(
          pieces.any((v) => v['category'] == 'top') &&
              pieces.any((v) => v['category'] == 'bottom'),
          'Add a top and bottoms first.',
        );
        outfits.add({
          'id': uniqueId(),
          'ids': pieces.map((v) => v['id']).toList(),
          'date': day(DateTime.now()),
        });
      });
  Future<void> restore(String raw) => _change((items, outfits, plans) {
    final restored = decode(raw);
    items
      ..clear()
      ..addAll(restored.$1);
    outfits
      ..clear()
      ..addAll(restored.$2);
    plans
      ..clear()
      ..addAll(restored.$3);
  });
  Future<void> savePayday(
    String date,
    String currency,
    int available,
    List<Item> allocations,
  ) => _change((items, outfits, plans) {
    need(kind == 'goal', 'Payday plans belong in Weekstash.');
    need(
      !plans.any((v) => v['date'] == date && v['currency'] == currency),
      'A plan for this payday already exists.',
    );
    final reserved = <String, int>{};
    for (final plan in plans) {
      for (final entry in children(plan, 'allocations')) {
        reserved.update(
          entry['id'] as String,
          (v) => v + whole(entry['amount'], max: 100000000),
          ifAbsent: () => whole(entry['amount'], max: 100000000),
        );
      }
    }
    for (final entry in allocations) {
      final goal = items.firstWhere((v) => v['id'] == entry['id']);
      need(goal['currency'] == currency, 'Use one currency per plan.');
      need(
        whole(entry['amount'], max: 100000000) <=
            cents(goal['target']) -
                cents(goal['saved'] ?? 0) -
                (reserved[goal['id']] ?? 0),
        'Some funds are already planned.',
      );
    }
    plans.add({
      'id': uniqueId(),
      'date': date,
      'currency': currency,
      'available': available,
      'allocations': allocations,
    });
  });
  Future<void> removePlan(String id) => _change((items, outfits, plans) {
    plans.removeWhere((v) => v['id'] == id);
  });
  Future<void> recover(String raw) async {
    final checked = decode(raw);
    final original = prefs.getString(key);
    if (original != null) {
      need(
        await prefs.setString('v3.$app.recovery-original', original),
        'Could not preserve the original.',
      );
    }
    need(await prefs.setString(key, raw), 'Could not restore.');
    _items = checked.$1;
    _outfits = checked.$2;
    _plans = checked.$3;
    recovery = null;
    if (_alive) notifyListeners();
  }

  @override
  void dispose() {
    _alive = false;
    super.dispose();
  }
}

const neutralColors = {'black', 'white', 'gray', 'cream', 'brown'};
const harmoniousPairs = {
  'purple:cream',
  'green:red',
  'orange:pink',
  'yellow:brown',
  'blue:green',
  'red:cream',
  'green:brown',
  'purple:gray',
  'blue:red',
  'blue:orange',
  'green:pink',
  'purple:yellow',
  'blue:cream',
  'green:cream',
  'red:black',
  'pink:brown',
  'blue:brown',
  'gray:pink',
  'black:white',
};

/// Curated color and occasion rules, version 2026-10. No remote closet data is required.
List<Item> chooseOutfit(
  List<Item> items, {
  int variant = 0,
  String occasion = 'everyday',
}) {
  final tops = items.where((v) => v['category'] == 'top').toList();
  final bottoms = items.where((v) => v['category'] == 'bottom').toList();
  need(
    tops.isNotEmpty && bottoms.isNotEmpty,
    'Add one top and one pair of bottoms.',
  );
  final combinations = <({Item top, Item bottom, int score})>[];
  for (final top in tops) {
    for (final bottom in bottoms) {
      final a = top['color'] as String? ?? 'cream',
          b = bottom['color'] as String? ?? 'black';
      var score = neutralColors.contains(a) || neutralColors.contains(b)
          ? 3
          : 0;
      if (harmoniousPairs.contains('$a:$b') ||
          harmoniousPairs.contains('$b:$a')) {
        score += 4;
      }
      if (a == b) score += 2;
      if (top['style'] == bottom['style']) score += 2;
      if (occasion == 'smart' &&
          (top['style'] == 'formal' || bottom['style'] == 'formal')) {
        score += 3;
      }
      if (occasion == 'active' &&
          (top['style'] == 'sport' || bottom['style'] == 'sport')) {
        score += 3;
      }
      combinations.add((top: top, bottom: bottom, score: score));
    }
  }
  combinations.sort((a, b) => b.score.compareTo(a.score));
  final choice = combinations[variant % combinations.length];
  final result = [choice.bottom, choice.top];
  for (final category in [
    'shoes',
    'outerwear',
    'hat',
    'bag',
    'gloves',
    'accessory',
  ]) {
    final options = items.where((v) => v['category'] == category).toList();
    if (options.isNotEmpty) result.add(options[variant % options.length]);
  }
  return result;
}

({bool fits, double angle, double clearance, List<double> face}) fitBox(
  Item item,
) {
  final width = finite(item['width'], min: 0.1, max: 10000),
      depth = finite(item['depth'], min: 0.1, max: 10000),
      height = finite(item['height'], min: 0.1, max: 10000);
  final doorWidth = finite(item['doorWidth'], min: 0.1, max: 10000),
      doorHeight = finite(item['doorHeight'], min: 0.1, max: 10000);
  var best = -double.infinity;
  var angle = 0.0;
  var face = [width, height];
  for (final sides in [
    [width, height],
    [depth, height],
    [width, depth],
  ]) {
    for (var degree = 0; degree <= 900; degree++) {
      final theta = degree / 10 * math.pi / 180;
      final projectedW =
          sides[0] * math.cos(theta) + sides[1] * math.sin(theta);
      final projectedH =
          sides[0] * math.sin(theta) + sides[1] * math.cos(theta);
      final clearance = math.min(
        doorWidth - projectedW,
        doorHeight - projectedH,
      );
      if (clearance > best) {
        best = clearance;
        angle = degree / 10;
        face = sides;
      }
    }
  }
  return (fits: best >= 0, angle: angle, clearance: best, face: face);
}

List<Item> scaledIngredients(Item recipe, int servings) {
  need(servings >= 1 && servings <= 48, 'Choose 1 to 48 servings.');
  final factor = servings / finite(recipe['servings'], min: 1, max: 48);
  return children(recipe, 'ingredients')
      .map(
        (v) => {
          ...v,
          'amount': finite(v['amount'], min: 0.001, max: 100000) * factor,
        },
      )
      .toList();
}

List<({String id, int allocation, int remaining})> allocatePayday(
  List<Item> goals,
  int available,
) {
  need(available >= 0, 'Use a positive available amount.');
  var rest = available;
  return goals.map((goal) {
    final needed = math.max(
      0,
      cents(goal['target']) - cents(goal['saved'] ?? 0),
    );
    final amount = math.min(rest, needed);
    rest -= amount;
    return (
      id: goal['id'] as String,
      allocation: amount,
      remaining: needed - amount,
    );
  }).toList();
}

/// Preserve separate dated batches, while repeated scans of the same food do
/// not create duplicates or overwrite the user's dates and notes.
bool sameFood(Item a, Item b) {
  String name(Item item) => (item['name'] as String? ?? '')
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ');
  return a['used'] != true &&
      b['used'] != true &&
      name(a) == name(b) &&
      a['location'] == b['location'] &&
      a['labelDate'] == b['labelDate'];
}
